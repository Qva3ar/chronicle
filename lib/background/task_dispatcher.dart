import 'dart:developer';
import 'dart:io' show Platform;
import 'package:workmanager/workmanager.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/services/daily_reset_service.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:chrono/ai/insight_engine.dart';
import 'package:chrono/ai/context_builder.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:chrono/utils/timezone_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:chrono/services/timer_service.dart'
    show backgroundNotificationActionHandler, ROUTINE_DONE_ACTION_ID, kAlertVibrationPattern;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:chrono/services/goals_widget_updater.dart';

/// Unified background task dispatcher for WorkManager
/// Handles all background tasks: session completion, daily reset, insights, and routine notifications
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final startTime = DateTime.now();

    try {
      // Initialize timezone for all background tasks using the device's real
      // IANA identifier so scheduled notifications fire at the correct wall time.
      await TimezoneHelper.ensureInitialized();

      bool success = false;

      switch (task) {
        case TaskNames.sessionCompletion:
          success = await _handleSessionCompletion(inputData);
          break;
        case TaskNames.dailyReset:
        // Legacy unique name: on iOS the dispatcher receives the task's
        // uniqueName (not the Android taskName), and old installs may still
        // have a pending task registered under the short 'daily_reset' name.
        case 'daily_reset':
          success = await _handleDailyReset(inputData);
          break;
        case TaskNames.dailyResetCheck:
          success = await _handleDailyResetCheck(inputData);
          break;
        case TaskNames.insightGeneration:
          success = await _handleInsightGeneration(inputData);
          break;
        case TaskNames.routineNotification:
          success = await _handleRoutineNotification(inputData);
          break;
        case TaskNames.checkinNotification:
          success = await _handleCheckinNotification(inputData);
          break;
        default:
          log('[TaskDispatcher] Unknown task: $task');
          success = false;
      }

      return Future.value(success);
    } catch (e, stackTrace) {
      log('[TaskDispatcher] Error in task $task: $e\nStack trace: $stackTrace');
      return Future.value(false);
    }
  });
}

/// Task names for background tasks
class TaskNames {
  static const String sessionCompletion = 'com.chrono.session_completion';
  static const String dailyReset = 'com.chrono.daily_reset';
  static const String dailyResetCheck = 'com.chrono.daily_reset_check';
  static const String insightGeneration = 'com.chrono.insight_generation';
  static const String routineNotification = 'com.chrono.routine_notification';
  static const String checkinNotification = 'com.chrono.checkin_notification';
}

/// Handle goal session completion
Future<bool> _handleSessionCompletion(Map<String, dynamic>? inputData) async {
  try {
    if (inputData == null) {
      log('[SessionCompletion] No input data provided');
      return false;
    }

    final goalId = inputData['goalId'] as int?;
    final sessionStartTime = inputData['sessionStartTime'] as int?;
    final sessionDuration = inputData['sessionDuration'] as int?;

    if (goalId == null || sessionStartTime == null || sessionDuration == null) {
      log('[SessionCompletion] Missing required parameters');
      return false;
    }

    final db = DatabaseHelper.instance;
    final goal = await db.getGoal(goalId);

    if (goal == null) {
      log('[SessionCompletion] Goal not found with ID: $goalId');
      return false;
    }

    // Check if goal is already completed or inactive
    if (goal.completedAt != null) {
      return true;
    }

    if (!goal.isActive) {
      return true;
    }

    // Calculate new time spent
    final newTimeSpent = goal.timeSpentSeconds + sessionDuration;
    final isGoalComplete = newTimeSpent >= goal.totalSeconds;
    final exactTime = isGoalComplete ? goal.totalSeconds : newTimeSpent;

    // Update the goal
    final updatedGoal = goal.copyWith(
      timeSpentSeconds: exactTime,
      isActive: false,
      sessionResumedTimestampSeconds: null,
      clearSessionResumedTimestamp: true,
      completedAt: isGoalComplete ? DateTime.now().millisecondsSinceEpoch : null,
    );

    await db.updateGoal(updatedGoal);

    // Refresh the goals home widget so the chronometer stops ticking once the
    // session has ended in the background (otherwise the widget keeps running
    // off the now-cleared session timestamp).
    try {
      await GoalsWidgetUpdater(db).update();
    } catch (e) {
      print('[SessionCompletion] ⚠️ Failed to update goals widget: $e');
    }

    // Update daily progress record (for both completed and in-progress goals)
    if (updatedGoal.currentDayRecordId != null) {
      try {
        final existingRecord = await db.getRecordById(updatedGoal.currentDayRecordId!);

        if (existingRecord != null) {
          // 🎯 CHECK: Verify if record was already updated by foreground (TimerService)
          final existingText = existingRecord['text'] as String? ?? '';

          // Check if already finalized (completed or day_ended)
          final isAlreadyFinalized = existingText.contains('status: completed') ||
              existingText.contains('status: day_ended');

          // 🎯 FIX: Removed aggressive "existingTimeMatch" check
          // We only skip if the record is explicitly finalized (completed or day ended)
          // It is better to perform a redundant update than to miss one

          if (isAlreadyFinalized && !isGoalComplete) {
            print('[SessionCompletion] ✅ Record already finalized - skipping update');
          } else {
            // Get tags for this record and filter out Chrono tag
            final database = await db.database;
            final tags = await database.rawQuery('''
              SELECT rt.tagId, t.${DatabaseColumns.tagName} as tagName
              FROM ${DatabaseTables.recordTag} rt
              JOIN ${DatabaseTables.category} t ON rt.tagId = t.${DatabaseColumns.id}
              WHERE rt.recordId = ?
            ''', [updatedGoal.currentDayRecordId]);

            final tagIds = tags
                .where((tag) => tag['tagName'] != 'Chrono')
                .map((tag) => tag['tagId'] as int)
                .toList();

            // Update record with current status
            final timeMinutes = (exactTime / 60).round();
            final status = isGoalComplete ? 'Completed' : 'In Progress';
            final statusKey = isGoalComplete ? 'completed' : 'active';

            final updatedRecordData = {
              DatabaseColumns.id: existingRecord['id'],
              DatabaseColumns.recordTitle: existingRecord['title'] ?? 'Goal Work Session',
              DatabaseColumns.recordText: '''🎯 Goal Work Session
⏱ Time spent: $timeMinutes min
📊 Status: $status

---
goal_id: ${updatedGoal.id}
time_minutes: $timeMinutes
status: $statusKey''',
              DatabaseColumns.recordCreatedAt: existingRecord['createdAt'],
              DatabaseColumns.recordType: existingRecord['recordType'],
              DatabaseColumns.recordGoalId: updatedGoal.id,
            };

            await db.updateRecord(updatedRecordData, tagIds);
            print(
                '[SessionCompletion] 📝 Updated daily progress record (background): $timeMinutes min, status: $statusKey');
          }
        }
      } catch (e) {
        print('[SessionCompletion] ⚠️ Failed to update daily progress record: $e');
      }
    }

    // Show notifications
    await _showSessionCompletionNotifications(updatedGoal, sessionDuration, isGoalComplete);

    try {
      await ProductivityService.instance.createOrUpdateDailyRecord();
    } catch (e) {
      print('[SessionCompletion] ⚠️ Failed to update productivity: $e');
    }

    return true;
  } catch (e, stackTrace) {
    print('[SessionCompletion] ❌ Error: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}

/// Handle daily reset
Future<bool> _handleDailyReset(Map<String, dynamic>? inputData) async {
  try {
    print('[DailyReset] 🌅 Starting WorkManager daily reset at ${DateTime.now()}');

    // Use the shared daily reset service which handles all reset logic,
    // is guarded by the last-reset-date check (idempotent) and stores the
    // last reset date in SharedPreferences.
    await DailyResetService.instance.performDailyResetAndStoreDate();

    print('[DailyReset] ✅ Daily reset completed successfully');

    return true;
  } catch (e, stackTrace) {
    print('[DailyReset] ❌ Error: $e');
    print('Stack trace: $stackTrace');
    return false;
  } finally {
    // ALWAYS schedule the next midnight task, even when this run failed —
    // otherwise the self-rescheduling chain breaks and no reset fires on the
    // following midnights until the app is opened again.
    try {
      await BackgroundTaskManager.scheduleDailyReset();
    } catch (e) {
      print('[DailyReset] ❌ Failed to schedule next reset: $e');
    }
  }
}

/// Handle periodic daily-reset safety check.
///
/// Fires every few hours and runs the date-guarded reset. Almost always a
/// no-op (the date key already matches today); it only performs the reset
/// when the midnight one-off task was killed by Doze / aggressive OEM
/// battery managers and the app hasn't been opened since.
Future<bool> _handleDailyResetCheck(Map<String, dynamic>? inputData) async {
  try {
    final performed = await DailyResetService.instance.runDailyResetIfNeeded();
    if (performed) {
      print('[DailyResetCheck] ✅ Missed midnight reset performed by periodic check');
      // The midnight one-off apparently didn't fire — make sure the chain is
      // re-armed for the next midnight.
      await BackgroundTaskManager.scheduleDailyReset();
    }
    return true;
  } catch (e, stackTrace) {
    print('[DailyResetCheck] ❌ Error: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}

/// Handle insight generation
Future<bool> _handleInsightGeneration(Map<String, dynamic>? inputData) async {
  try {
    print('[InsightGeneration] 🔄 Starting insight generation');

    final db = await DatabaseHelper.instance.database;

    // Store execution timestamp
    await db.update(
      DatabaseTables.appSettings,
      {DatabaseColumns.settingLastBackgroundRunAt: DateTime.now().millisecondsSinceEpoch},
      where: '${DatabaseColumns.id} = 1',
    );

    // Load settings
    final settings = await ContextBuilder.instance.loadSettings();

    if (!settings.insightEnabled) {
      print('[InsightGeneration] ⚠️ Insights disabled, skipping execution');
      return true;
    }

    print('[InsightGeneration] ✅ Settings loaded - generating insight...');

    // Generate and store insight
    final result = await InsightEngine.instance.generateAndStoreInsight();

    if (result != null && result['should_notify'] == true) {
      print('[InsightGeneration] 📢 Insight generated, sending notification...');

      try {
        final notif = NotificationService();
        await notif.initialize(calledFromBackgroundTask: true);
        await notif.showInsightNotification(
          title: (result['title'] ?? 'Chrono') as String,
          body: (result['body'] ?? '') as String,
        );
        print('[InsightGeneration] ✅ Notification sent successfully');
      } catch (e) {
        print('[InsightGeneration] ⚠️ Failed to send notification: $e');
      }

      // Update home screen widget with new insight
      try {
        print('[InsightGeneration] 🔄 Updating home screen widget...');
        await HomeWidget.saveWidgetData<bool>('has_insight', true);
        await HomeWidget.saveWidgetData<String>(
            'insight_title', result['title'] as String? ?? 'Insight');
        await HomeWidget.saveWidgetData<String>('insight_body', result['body'] as String? ?? '');
        await HomeWidget.saveWidgetData<String>('insight_tags', result['tags'] as String? ?? '[]');
        await HomeWidget.saveWidgetData<String>('app_name', 'Chrono');
        await HomeWidget.saveWidgetData<String>('placeholder_text', 'No insights yet');
        // Update all three Android widget sizes
        await HomeWidget.updateWidget(
          name: 'ChronoSmallWidgetProvider',
          iOSName: 'ChronoWidget',
        );
        await HomeWidget.updateWidget(
          name: 'ChronoMediumWidgetProvider',
          iOSName: 'ChronoWidget',
        );
        await HomeWidget.updateWidget(
          name: 'ChronoLargeWidgetProvider',
          iOSName: 'ChronoWidget',
        );
        print('[InsightGeneration] ✅ Widget updated successfully');
      } catch (e) {
        print('[InsightGeneration] ⚠️ Failed to update widget: $e');
      }
    } else {
      print('[InsightGeneration] ℹ️ No insight generated or notification not requested');
    }

    return true;
  } catch (e, stackTrace) {
    print('[InsightGeneration] ❌ Error: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}

/// Handle routine notification
Future<bool> _handleRoutineNotification(Map<String, dynamic>? inputData) async {
  try {
    if (inputData == null) {
      print('[RoutineNotification] ❌ No input data provided');
      return false;
    }

    final routineId = inputData['routineId'] as int?;
    final routineName = inputData['routineName'] as String?;
    final currentRetry = inputData['currentRetry'] as int? ?? 0;
    final numberOfRetries = inputData['numberOfRetries'] as int? ?? 0;

    if (routineId == null || routineName == null) {
      print('[RoutineNotification] ❌ Missing required parameters');
      return false;
    }

    print(
        '[RoutineNotification] 🔔 Processing routine notification for: "$routineName" (ID: $routineId)');
    print('   - Current retry: $currentRetry/$numberOfRetries');

    // Check if routine is already marked as done
    final prefs = await SharedPreferences.getInstance();
    final isDone = prefs.getBool('routine_${routineId}_done') ?? false;

    if (isDone) {
      print('[RoutineNotification] ✅ Routine already marked done. Skipping notification.');
      return true;
    }

    // Show notification
    await _showRoutineNotification(routineId, routineName, currentRetry, numberOfRetries);

    print('[RoutineNotification] ✅ Routine notification shown successfully');
    return true;
  } catch (e, stackTrace) {
    print('[RoutineNotification] ❌ Error: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}

/// Handle checkin notification
Future<bool> _handleCheckinNotification(Map<String, dynamic>? inputData) async {
  try {
    if (inputData == null) {
      print('[CheckinNotification] ❌ No input data provided');
      return false;
    }

    final checkinType = inputData['checkinType'] as String?;
    final notificationId = inputData['notificationId'] as int?;

    if (checkinType == null || notificationId == null) {
      print('[CheckinNotification] ❌ Missing required parameters');
      return false;
    }

    print('[CheckinNotification] 🔔 Processing checkin notification for: $checkinType');

    // Show notification
    await _showCheckinNotification(checkinType, notificationId);

    print('[CheckinNotification] ✅ Checkin notification shown successfully');
    return true;
  } catch (e, stackTrace) {
    print('[CheckinNotification] ❌ Error: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}

/// Show checkin notification
Future<void> _showCheckinNotification(String checkinType, int notificationId) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();

    // Initialize notifications in background context
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await plugin.initialize(initSettings);

    final title = checkinType == 'morning' ? 'Утренний чекин' : 'Вечерний чекин';
    final body = checkinType == 'morning'
        ? 'Доброе утро! Время для утреннего чекина'
        : 'Добрый вечер! Время для вечернего чекина';

    const androidDetails = AndroidNotificationDetails(
      'checkin_channel',
      'Daily Checkin Notifications',
      channelDescription: 'Notifications for morning and evening checkins',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await plugin.show(
      notificationId,
      title,
      body,
      details,
      payload: 'checkin_$checkinType',
    );

    print('[CheckinNotification] ✅ Notification shown (ID: $notificationId, type: $checkinType)');
  } catch (e) {
    print('[CheckinNotification] ⚠️ Failed to show notification: $e');
  }
}

/// Show routine notification
Future<void> _showRoutineNotification(
  int routineId,
  String routineName,
  int currentRetry,
  int numberOfRetries,
) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    final iosSettings = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'routine_category',
          actions: [
            DarwinNotificationAction.plain(
              ROUTINE_DONE_ACTION_ID,
              'Done ✓',
            ),
          ],
        ),
      ],
    );
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await plugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationActionHandler,
    );

    // Use the same notification ID for main and retries so that
    // retries replace the previous notification instead of stacking.
    // WorkManager may batch tasks with close delays, causing both to fire simultaneously.
    final notificationId = 1000 + routineId;

    final title = currentRetry == 0
        ? 'Time for: $routineName'
        : 'Reminder: $routineName';

    final body = currentRetry == 0
        ? 'Tap to mark as done'
        : 'Reminder ${currentRetry}/$numberOfRetries';

    final androidDetails = AndroidNotificationDetails(
      'routine_channel_v2',
      'Routine Notifications',
      channelDescription: 'Notifications for daily routines',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: kAlertVibrationPattern,
      actions: [
        AndroidNotificationAction(
          ROUTINE_DONE_ACTION_ID,
          'Done ✓',
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'routine_category',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await plugin.show(
      notificationId,
      title,
      body,
      details,
      payload: 'routine_$routineId',
    );

    print('[RoutineNotification] ✅ Notification shown (ID: $notificationId)');
  } catch (e) {
    print('[RoutineNotification] ⚠️ Failed to show notification: $e');
  }
}

/// Show session completion notifications
Future<void> _showSessionCompletionNotifications(
  Goal goal,
  int sessionDuration,
  bool isGoalComplete,
) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();

    // Initialize notifications in background context with action handler
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await plugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationActionHandler,
    );

    // Cancel the running notification first
    await plugin.cancel(1);
    print('[SessionCompletion] 🚫 Cancelled running notification (ID: 1)');

    if (isGoalComplete) {
      // Show goal completion notification
      final androidDetails = AndroidNotificationDetails(
        'goal_complete_v2',
        'Goal Complete',
        channelDescription: 'Notifications for completed goals',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: kAlertVibrationPattern,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await plugin.show(
        4,
        '🎉 Goal Completed!',
        '${goal.title} - Congratulations!',
        details,
      );
      print('[SessionCompletion] ✅ Goal completion notification sent');
    }

    // Show session completion notification
    // Add "Continue" button only if goal is not complete
    List<AndroidNotificationAction> actions = [];
    if (!isGoalComplete) {
      actions.add(const AndroidNotificationAction(
        'CONTINUE_SESSION_ACTION',
        'Continue',
      ));
    }

    final androidDetails = AndroidNotificationDetails(
      'session_complete_channel_v2',
      'Session Completed',
      channelDescription: 'Notifications when a session is completed',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: kAlertVibrationPattern,
      autoCancel: true,
      actions: actions.isNotEmpty ? actions : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = isGoalComplete ? 'Session Complete - Goal Achieved! 🎉' : 'Session Completed! 🎉';
    final body = '${goal.title} - ${_formatTime(sessionDuration)} session finished. Great work!';

    await plugin.show(
      2,
      title,
      body,
      details,
      payload: 'session_complete_${goal.id}',
    );

    print('[SessionCompletion] ✅ Session completion notification sent');
  } catch (e) {
    print('[SessionCompletion] ⚠️ Failed to show notifications: $e');
  }
}

/// Format seconds to HH:MM:SS
String _formatTime(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// Manager class for scheduling background tasks
class BackgroundTaskManager {
  /// Initialize WorkManager with unified dispatcher
  static Future<void> initialize() async {
    try {
      print('[BackgroundTaskManager] Initializing WorkManager...');

      await Workmanager().initialize(
        backgroundTaskDispatcher,
      );

      print('[BackgroundTaskManager] ✅ WorkManager initialized');

      // Clean up old insight task registration from deprecated insight_worker.dart
      try {
        await Workmanager().cancelByUniqueName('insight_periodic_task');
        print('[BackgroundTaskManager] 🧹 Cleaned up old insight task registration');
      } catch (e) {
        print('[BackgroundTaskManager] ℹ️ No old insight task to clean up: $e');
      }

      // Clean up the daily reset task registered under the legacy short
      // unique name ('daily_reset'); it is now registered under
      // TaskNames.dailyReset so the name matches the iOS BGTask identifier.
      try {
        await Workmanager().cancelByUniqueName('daily_reset');
        print('[BackgroundTaskManager] 🧹 Cleaned up legacy daily_reset registration');
      } catch (e) {
        print('[BackgroundTaskManager] ℹ️ No legacy daily_reset task to clean up: $e');
      }
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to initialize WorkManager: $e');
    }
  }

  /// Schedule session completion task
  static Future<void> scheduleSessionCompletion({
    required int goalId,
    required int sessionStartTime,
    required int sessionDuration,
    required DateTime completionTime,
  }) async {
    try {
      final taskId = 'session_$goalId';
      final delay = completionTime.difference(DateTime.now());

      if (delay.isNegative) {
        print('[BackgroundTaskManager] ⚠️ Completion time is in the past, scheduling immediately');
      }

      await Workmanager().registerOneOffTask(
        taskId,
        TaskNames.sessionCompletion,
        initialDelay: delay.isNegative ? Duration.zero : delay,
        inputData: {
          'goalId': goalId,
          'sessionStartTime': sessionStartTime,
          'sessionDuration': sessionDuration,
        },
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
        // 🎯 FIX: Default one-off policy in workmanager is KEEP, which means a
        // stale pending session_<goalId> task (e.g. left over after the app was
        // killed mid-session) would be kept and this fresh, correctly-timed task
        // silently ignored. The stale task could then fire seconds after the user
        // re-activates the goal, flip isActive=false and stop the session. REPLACE
        // guarantees the new schedule overwrites any leftover task.
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      print('[BackgroundTaskManager] ✅ Session completion scheduled for $completionTime');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule session completion: $e');
    }
  }

  /// Cancel session completion task
  static Future<void> cancelSessionCompletion(int goalId) async {
    try {
      final taskId = 'session_$goalId';
      await Workmanager().cancelByUniqueName(taskId);
      print('[BackgroundTaskManager] ✅ Cancelled session completion for goal $goalId');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to cancel session completion: $e');
    }
  }

  /// Schedule daily reset task
  /// Schedules reset at midnight (start of new day)
  static Future<void> scheduleDailyReset() async {
    try {
      // Test mode disabled - resets at midnight
      const bool testMode = false;
      const Duration testInterval = Duration(hours: 2);

      if (testMode) {
        // TEST MODE: Schedule reset in 2 hours
        final now = DateTime.now();
        final nextReset = now.add(testInterval);

        await Workmanager().registerOneOffTask(
          TaskNames.dailyReset,
          TaskNames.dailyReset,
          initialDelay: testInterval,
          constraints: Constraints(
            networkType: NetworkType.notRequired,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );

        print(
            '[BackgroundTaskManager] 🧪 TEST MODE: Reset scheduled for ${_formatDateTime(nextReset)} (in ${testInterval.inHours} hours)');
      } else {
        // PRODUCTION MODE: Schedule at midnight
        final now = tz.TZDateTime.now(tz.local);

        // Calculate next midnight
        tz.TZDateTime nextMidnight = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + 1,
          0,
          0,
          0,
        );

        if (nextMidnight.isBefore(now) || nextMidnight.isAtSameMomentAs(now)) {
          nextMidnight = nextMidnight.add(const Duration(days: 1));
        }

        final delay = nextMidnight.difference(now);

        // uniqueName == taskName (com.chrono.daily_reset) on purpose: on iOS
        // the uniqueName IS the BGTaskScheduler identifier, so it must match
        // BGTaskSchedulerPermittedIdentifiers in Info.plist AND the value the
        // dispatcher switch receives (iOS passes uniqueName, not taskName).
        if (Platform.isIOS) {
          // iOS: one-off tasks run immediately via beginBackgroundTask and
          // ignore initialDelay, so a "midnight one-off" is impossible.
          // A BGProcessingTask with earliestBeginDate = next midnight is the
          // only deferred option. It is best-effort (iOS decides the actual
          // run time); guaranteed correctness comes from the catch-up paths
          // (startup / resume / foreground midnight timer).
          await Workmanager().registerProcessingTask(
            TaskNames.dailyReset,
            TaskNames.dailyReset,
            initialDelay: delay,
          );
        } else {
          // Android: REPLACE guarantees a stale pending task never blocks a
          // fresh, correctly-timed one (default policy is KEEP, which
          // silently drops the new registration).
          await Workmanager().registerOneOffTask(
            TaskNames.dailyReset,
            TaskNames.dailyReset,
            initialDelay: delay,
            constraints: Constraints(
              networkType: NetworkType.notRequired,
            ),
            existingWorkPolicy: ExistingWorkPolicy.replace,
          );
        }

        print(
            '[BackgroundTaskManager] ✅ Daily reset scheduled for $nextMidnight (timezone: ${tz.local.name})');
      }
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule daily reset: $e');
    }
  }

  /// Schedule the periodic daily-reset safety check.
  ///
  /// Runs every 6 hours and executes the date-guarded reset check
  /// ([DailyResetService.runDailyResetIfNeeded]). Almost always a no-op;
  /// it exists to catch the case where the midnight one-off task was killed
  /// by Doze / OEM battery managers and the app hasn't been opened since,
  /// so home-screen widgets and notifications still get a fresh day.
  ///
  /// On iOS this maps to a BGAppRefreshTask (best-effort, timing decided by
  /// the system); the identifier is registered in AppDelegate.swift and
  /// listed in Info.plist.
  static Future<void> scheduleDailyResetCheck() async {
    try {
      await Workmanager().registerPeriodicTask(
        TaskNames.dailyResetCheck,
        TaskNames.dailyResetCheck,
        frequency: const Duration(hours: 6),
        initialDelay: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
        // KEEP (default) is correct here: the periodic task has no
        // schedule-dependent payload, so an existing registration is fine
        // and re-registering on every launch shouldn't reset its cycle.
      );

      print('[BackgroundTaskManager] ✅ Daily reset safety check scheduled (every 6h)');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule daily reset check: $e');
    }
  }

  /// Format DateTime for logging (helper for test mode)
  static String _formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  /// Cancel insight generation tasks
  static Future<void> cancelInsightGeneration() async {
    try {
      await Workmanager().cancelByUniqueName('insight_periodic');
      print('[BackgroundTaskManager] ✅ Insight generation tasks cancelled');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to cancel insight generation: $e');
    }
  }

  /// Schedule periodic insight generation
  static Future<void> scheduleInsightGeneration({
    required bool enabled,
    required int intervalMinutes,
  }) async {
    try {
      // Cancel existing task first
      await Workmanager().cancelByUniqueName('insight_periodic');

      if (!enabled) {
        print('[BackgroundTaskManager] ℹ️ Insight generation disabled');
        return;
      }

      final actualInterval = intervalMinutes < 15 ? 15 : intervalMinutes;

      await Workmanager().registerPeriodicTask(
        'insight_periodic',
        TaskNames.insightGeneration,
        frequency: Duration(minutes: actualInterval),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        initialDelay: Duration(minutes: actualInterval),
      );

      print(
          '[BackgroundTaskManager] ✅ Insight generation scheduled (interval: $actualInterval min)');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule insight generation: $e');
    }
  }

  /// Schedule routine notification task
  static Future<void> scheduleRoutineNotification({
    required int routineId,
    required String routineName,
    required DateTime scheduledTime,
    int currentRetry = 0,
    int numberOfRetries = 0,
  }) async {
    try {
      final taskId =
          currentRetry == 0 ? 'routine_$routineId' : 'routine_${routineId}_retry_$currentRetry';

      final delay = scheduledTime.difference(DateTime.now());

      if (delay.isNegative) {
        print('[BackgroundTaskManager] ⚠️ Routine notification time is in the past, skipping');
        return;
      }

      await Workmanager().registerOneOffTask(
        taskId,
        TaskNames.routineNotification,
        initialDelay: delay,
        inputData: {
          'routineId': routineId,
          'routineName': routineName,
          'currentRetry': currentRetry,
          'numberOfRetries': numberOfRetries,
        },
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );

      print(
          '[BackgroundTaskManager] ✅ Routine notification scheduled for $scheduledTime (retry: $currentRetry/$numberOfRetries)');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule routine notification: $e');
    }
  }

  /// Cancel routine notification task
  static Future<void> cancelRoutineNotification(int routineId, {int maxRetries = 200}) async {
    try {
      // Cancel main notification
      await Workmanager().cancelByUniqueName('routine_$routineId');

      // Cancel all retry notifications
      for (int i = 1; i <= maxRetries; i++) {
        await Workmanager().cancelByUniqueName('routine_${routineId}_retry_$i');
      }

      print('[BackgroundTaskManager] ✅ Cancelled routine notification for routine $routineId');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to cancel routine notification: $e');
    }
  }

  /// Schedule checkin notification task
  static Future<void> scheduleCheckinNotification({
    required String checkinType,
    required int notificationId,
    required DateTime scheduledTime,
  }) async {
    try {
      final taskId = 'checkin_$checkinType';

      final delay = scheduledTime.difference(DateTime.now());

      if (delay.isNegative) {
        print('[BackgroundTaskManager] ⚠️ Checkin notification time is in the past, skipping');
        return;
      }

      await Workmanager().registerOneOffTask(
        taskId,
        TaskNames.checkinNotification,
        initialDelay: delay,
        inputData: {
          'checkinType': checkinType,
          'notificationId': notificationId,
        },
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );

      print(
          '[BackgroundTaskManager] ✅ Checkin notification scheduled for $scheduledTime (type: $checkinType)');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule checkin notification: $e');
    }
  }

  /// Cancel checkin notification task
  static Future<void> cancelCheckinNotification(String checkinType) async {
    try {
      await Workmanager().cancelByUniqueName('checkin_$checkinType');
      print('[BackgroundTaskManager] ✅ Cancelled checkin notification for $checkinType');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to cancel checkin notification: $e');
    }
  }

  /// Cancel all background tasks
  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
      print('[BackgroundTaskManager] ✅ All background tasks cancelled');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to cancel all tasks: $e');
    }
  }
}
