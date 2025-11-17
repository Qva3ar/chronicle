import 'package:workmanager/workmanager.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/record.service.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/ai/insight_engine.dart';
import 'package:chrono/ai/context_builder.dart';
import 'package:chrono/ai/summarizer.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:chrono/services/timer_service.dart' show backgroundNotificationActionHandler;
import 'package:shared_preferences/shared_preferences.dart';

/// Unified background task dispatcher for WorkManager
/// Handles all background tasks: session completion, daily reset, insights, and routine notifications
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('[TaskDispatcher] 🔄 Background task started: $task');
    final startTime = DateTime.now();

    try {
      // Initialize timezone for all background tasks
      tz_data.initializeTimeZones();
      try {
        final String localTimezoneName = DateTime.now().timeZoneName;
        String tzLocation = 'Europe/Moscow';
        if (localTimezoneName.contains('MSK')) {
          tzLocation = 'Europe/Moscow';
        } else if (localTimezoneName.contains('GMT') || localTimezoneName.contains('UTC')) {
          tzLocation = 'UTC';
        }
        tz.setLocalLocation(tz.getLocation(tzLocation));
      } catch (e) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      bool success = false;

      switch (task) {
        case TaskNames.sessionCompletion:
          success = await _handleSessionCompletion(inputData);
          break;
        case TaskNames.dailyReset:
          success = await _handleDailyReset(inputData);
          break;
        case TaskNames.insightGeneration:
          success = await _handleInsightGeneration(inputData);
          break;
        case TaskNames.routineNotification:
          success = await _handleRoutineNotification(inputData);
          break;
        default:
          print('[TaskDispatcher] ❌ Unknown task: $task');
          success = false;
      }

      final duration = DateTime.now().difference(startTime);
      print('[TaskDispatcher] ${success ? "✅" : "❌"} Task $task completed in ${duration.inSeconds}s');

      return Future.value(success);
    } catch (e, stackTrace) {
      print('[TaskDispatcher] ❌ Error in task $task: $e');
      print('Stack trace: $stackTrace');
      return Future.value(false);
    }
  });
}

/// Task names for background tasks
class TaskNames {
  static const String sessionCompletion = 'com.chrono.session_completion';
  static const String dailyReset = 'com.chrono.daily_reset';
  static const String insightGeneration = 'com.chrono.insight_generation';
  static const String routineNotification = 'com.chrono.routine_notification';
}

/// Handle goal session completion
Future<bool> _handleSessionCompletion(Map<String, dynamic>? inputData) async {
  try {
    if (inputData == null) {
      print('[SessionCompletion] ❌ No input data provided');
      return false;
    }

    final goalId = inputData['goalId'] as int?;
    final sessionStartTime = inputData['sessionStartTime'] as int?;
    final sessionDuration = inputData['sessionDuration'] as int?;

    if (goalId == null || sessionStartTime == null || sessionDuration == null) {
      print('[SessionCompletion] ❌ Missing required parameters');
      return false;
    }

    print('[SessionCompletion] 🔔 Processing session completion for goal ID: $goalId');
    print('   - Session start: ${DateTime.fromMillisecondsSinceEpoch(sessionStartTime * 1000)}');
    print('   - Session duration: ${_formatTime(sessionDuration)}');

    final db = DatabaseHelper.instance;
    final goal = await db.getGoal(goalId);

    if (goal == null) {
      print('[SessionCompletion] ❌ Goal not found with ID: $goalId');
      return false;
    }

    // Check if goal is already completed or inactive
    if (goal.completedAt != null) {
      print('[SessionCompletion] ℹ️ Goal "${goal.title}" already completed. Skipping.');
      return true;
    }

    if (!goal.isActive) {
      print('[SessionCompletion] ℹ️ Goal "${goal.title}" is no longer active. User may have stopped it.');
      return true;
    }

    print('[SessionCompletion] 📊 Processing session completion for: "${goal.title}"');
    print('   - Current time spent: ${_formatTime(goal.timeSpentSeconds)}/${_formatTime(goal.totalSeconds)}');

    // Calculate new time spent
    final newTimeSpent = goal.timeSpentSeconds + sessionDuration;
    final isGoalComplete = newTimeSpent >= goal.totalSeconds;
    final exactTime = isGoalComplete ? goal.totalSeconds : newTimeSpent;

    print('   - Session duration: ${_formatTime(sessionDuration)}');
    print('   - New time spent: ${_formatTime(exactTime)}');
    print('   - Will complete goal: $isGoalComplete');

    // Update the goal
    final updatedGoal = goal.copyWith(
      timeSpentSeconds: exactTime,
      isActive: false,
      sessionResumedTimestampSeconds: null,
      clearSessionResumedTimestamp: true,
      completedAt: isGoalComplete ? DateTime.now().millisecondsSinceEpoch : null,
    );

    await db.updateGoal(updatedGoal);
    print('[SessionCompletion] ✅ Goal updated successfully');

    // Create record if goal is completed
    if (isGoalComplete) {
      final recordService = RecordService();
      final record = {
        DatabaseColumns.recordTitle: 'Goal Completed: ${updatedGoal.title}',
        DatabaseColumns.recordText:
            'Goal completed after ${_formatTime(exactTime)} of focused work!',
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'goal',
        DatabaseColumns.recordGoalId: updatedGoal.id,
      };
      await recordService.createRecord(record, []);
      print('[SessionCompletion] 📝 Record created for completed goal.');
    }

    // Show notifications
    await _showSessionCompletionNotifications(updatedGoal, sessionDuration, isGoalComplete);

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
    print('[DailyReset] 🌅 Starting daily reset at ${DateTime.now()}');

    final db = DatabaseHelper.instance;
    final goalService = GoalService(db);

    // Reset routines and goals
    await db.resetRoutinesDoneStatus();
    await goalService.resetAllGoals();

    // Reschedule routine notifications for the new day
    final notificationService = NotificationService();
    await notificationService.checkAndRescheduleRoutines(fromBackgroundTask: true);

    print('[DailyReset] ✅ Daily reset completed successfully');

    // Schedule next reset
    await BackgroundTaskManager.scheduleDailyReset();

    // Run optional summarization rollup
    try {
      await Summarizer.instance.runDailySummary();
    } catch (e) {
      print('[DailyReset] ⚠️ Summary generation failed: $e');
    }

    return true;
  } catch (e, stackTrace) {
    print('[DailyReset] ❌ Error: $e');
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

    print('[RoutineNotification] 🔔 Processing routine notification for: "$routineName" (ID: $routineId)');
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

/// Show routine notification
Future<void> _showRoutineNotification(
  int routineId,
  String routineName,
  int currentRetry,
  int numberOfRetries,
) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();

    // Initialize notifications in background context
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await plugin.initialize(initSettings);

    // Determine notification ID and content
    final notificationId = currentRetry == 0
        ? 1000 + routineId // Main notification ID
        : 2000 + (routineId * 5) + currentRetry; // Retry notification ID

    final title = currentRetry == 0
        ? 'Routine Reminder'
        : 'Reminder: $routineName';

    final body = currentRetry == 0
        ? 'Time for: $routineName'
        : 'It\'s time for your routine: $routineName (Retry ${currentRetry}/$numberOfRetries)';

    const androidDetails = AndroidNotificationDetails(
      'routine_channel',
      'Routine Notifications',
      channelDescription: 'Notifications for daily routines',
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
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      const androidDetails = AndroidNotificationDetails(
        'goal_complete',
        'Goal Complete',
        channelDescription: 'Notifications for completed goals',
        importance: Importance.max,
        priority: Priority.max,
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
      'session_complete_channel',
      'Session Completed',
      channelDescription: 'Notifications when a session is completed',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      actions: actions.isNotEmpty ? actions : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = isGoalComplete
        ? 'Session Complete - Goal Achieved! 🎉'
        : 'Session Completed! 🎉';
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
  static Future<void> scheduleDailyReset() async {
    try {
      final now = tz.TZDateTime.now(tz.local);

      // Calculate next midnight
      tz.TZDateTime nextMidnight = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        0, 0, 0,
      );

      if (nextMidnight.isBefore(now) || nextMidnight.isAtSameMomentAs(now)) {
        nextMidnight = nextMidnight.add(const Duration(days: 1));
      }

      final delay = nextMidnight.difference(now);

      await Workmanager().registerOneOffTask(
        'daily_reset',
        TaskNames.dailyReset,
        initialDelay: delay,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );

      print('[BackgroundTaskManager] ✅ Daily reset scheduled for $nextMidnight (timezone: ${tz.local.name})');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule daily reset: $e');
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

      print('[BackgroundTaskManager] ✅ Insight generation scheduled (interval: $actualInterval min)');
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
      final taskId = currentRetry == 0
          ? 'routine_$routineId'
          : 'routine_${routineId}_retry_$currentRetry';

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

      print('[BackgroundTaskManager] ✅ Routine notification scheduled for $scheduledTime (retry: $currentRetry/$numberOfRetries)');
    } catch (e) {
      print('[BackgroundTaskManager] ❌ Failed to schedule routine notification: $e');
    }
  }

  /// Cancel routine notification task
  static Future<void> cancelRoutineNotification(int routineId, {int maxRetries = 5}) async {
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
