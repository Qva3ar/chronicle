import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../db_manager.dart';
import '../models/goal.model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chrono/background/task_dispatcher.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../record.service.dart';
import '../main.dart';
import '../models/routine.model.dart';
import '../screens/goals_screen.dart';
import 'daily_reset_service.dart';
import 'live_activity_service.dart';
import 'notification_service.dart';
import 'routine_widget_service.dart';
import 'goals_widget_updater.dart';
import 'productivity_service.dart';

const String CONTINUE_ACTION_ID = 'CONTINUE_SESSION_ACTION';
const String ROUTINE_DONE_ACTION_ID = 'ROUTINE_DONE_ACTION';

/// Strong vibration pattern for alert notifications (session/goal/routine).
/// Android channel settings are frozen after first creation, so the pattern
/// only takes effect through the *_v2 channels created in
/// TimerService.initializeNotifications / NotificationService.initialize.
/// Format: [delay, vibrate, pause, vibrate, ...] in milliseconds.
final Int64List kAlertVibrationPattern =
    Int64List.fromList(<int>[0, 400, 250, 400, 250, 600]);

// Helper functions for background notification actions
@pragma('vm:entry-point')
String _formatTimeStatic(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;

  // Always show hh:mm:ss format
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

@pragma('vm:entry-point')
// Helper function to determine session duration, callable from background contexts
int _getStaticSessionDurationForGoal(Goal goal) {
  return goal.sessionMinutes * 60; // Normal duration
}

// Unified Android notification details for the ongoing session notification.
// The OS renders a live chronometer counting up from [sessionStartTimeSeconds]
// (`usesChronometer` + `when`), so the notification stays accurate even when
// the app is backgrounded or killed - no periodic repaints needed.
@pragma('vm:entry-point')
AndroidNotificationDetails _buildRunningAndroidDetails(int sessionStartTimeSeconds) {
  return AndroidNotificationDetails(
    'timer_channel_v2',
    'Timer Notifications',
    channelDescription: 'Ongoing notification for the active goal session',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    icon: '@mipmap/launcher_icon',
    showWhen: true,
    when: sessionStartTimeSeconds * 1000,
    usesChronometer: true,
    category: AndroidNotificationCategory.stopwatch,
  );
}

@pragma('vm:entry-point')
// Body line with the goal-level (not session) numbers. These only change
// between sessions, so static text is fine here.
String _buildRunningNotificationBody(Goal goal, int baselineTimeSpentSeconds) {
  final int remaining =
      (goal.totalSeconds - baselineTimeSpentSeconds).clamp(0, goal.totalSeconds);
  return 'Total ${_formatTimeStatic(baselineTimeSpentSeconds)} of ${_formatTimeStatic(goal.totalSeconds)} · ${_formatTimeStatic(remaining)} left';
}

@pragma('vm:entry-point')
// Show the running notification from a background isolate (the "Continue"
// notification action). Android-only: iOS uses a Live Activity instead, which
// cannot be (re)started from this isolate and is handled on next app launch.
Future<void> _showBackgroundRunningNotification(
    FlutterLocalNotificationsPlugin plugin, Goal goal) async {
  if (!Platform.isAndroid) return;
  try {
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int sessionStartTime = goal.sessionResumedTimestampSeconds ?? currentTime;

    final details = NotificationDetails(
      android: _buildRunningAndroidDetails(sessionStartTime),
    );

    await plugin.show(
      1, // Same ID as the main running notification
      '🎯 ${goal.title}',
      _buildRunningNotificationBody(goal, goal.timeSpentSeconds),
      details,
      payload: 'running_goal_${goal.id}',
    );

    print('✅ BACKGROUND: Chronometer running notification shown for ${goal.title}');
  } catch (e) {
    print('❌ BACKGROUND: Failed to show running notification: $e');
  }
}

@pragma('vm:entry-point')
// Ensure the background isolate has a valid local timezone before scheduling
// exact alarms. The notification-action isolate is spawned fresh, so timezone
// data may not be initialized here.
void _ensureTimezoneInitialized() {
  try {
    tz.TZDateTime.now(tz.local);
  } catch (_) {
    try {
      tz_data.initializeTimeZones();
      final String localTimezoneName = DateTime.now().timeZoneName;
      String tzLocation = 'Europe/Moscow';
      if (localTimezoneName.contains('GMT') || localTimezoneName.contains('UTC')) {
        tzLocation = 'UTC';
      }
      tz.setLocalLocation(tz.getLocation(tzLocation));
    } catch (e) {
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
  }
}

@pragma('vm:entry-point')
// Backup exact local notification for a session/goal completion, scheduled from
// a background isolate (e.g. the "Continue" notification action). This mirrors
// TimerService._scheduleLocalNotification so that sessions resumed while the app
// is in the background still get a reliable alarm-backed completion notification
// instead of relying solely on WorkManager (which has no precise-timing guarantee).
Future<void> _scheduleBackgroundCompletionNotification(
  FlutterLocalNotificationsPlugin plugin,
  Goal goal,
  DateTime completionTime,
  bool isGoalCompletion,
  int sessionDuration,
) async {
  try {
    _ensureTimezoneInitialized();

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(completionTime, tz.local);

    final title =
        isGoalCompletion ? 'Session Complete - Goal Achieved! 🎉' : 'Session Completed! 🎉';
    final body = isGoalCompletion
        ? '${goal.title} - ${_formatTimeStatic(sessionDuration)} session completed your goal!'
        : '${goal.title} - ${_formatTimeStatic(sessionDuration)} session finished. Great work!';

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
      actions: !isGoalCompletion
          ? [
              const AndroidNotificationAction(
                CONTINUE_ACTION_ID,
                'Continue',
              ),
            ]
          : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload =
        isGoalCompletion ? 'goal_complete_${goal.id}' : 'session_complete_${goal.id}';

    try {
      await plugin.zonedSchedule(
        2,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      print('✅ BACKGROUND ACTION: Backup exact notification scheduled for $scheduledDate');
    } catch (exactError) {
      print(
          '⚠️ BACKGROUND ACTION: Exact backup schedule failed ($exactError). Falling back to inexact.');
      await plugin.zonedSchedule(
        2,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      print('✅ BACKGROUND ACTION: Inexact backup notification scheduled for $scheduledDate');
    }
  } catch (e) {
    print('❌ BACKGROUND ACTION: Failed to schedule backup exact notification: $e');
  }
}

@pragma('vm:entry-point')
// NEW: Top-level function to handle notification actions when app is in background
Future<void> backgroundNotificationActionHandler(NotificationResponse response) async {
  // Ensure Flutter bindings are initialized for background isolates.
  WidgetsFlutterBinding.ensureInitialized();

  print(
      '🔔 BACKGROUND ACTION HANDLER: Received response: ${response.payload}, action: ${response.actionId}');

  if (response.actionId == CONTINUE_ACTION_ID && response.payload != null) {
    final db = DatabaseHelper.instance;
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize notifications (needed to cancel/schedule). Register the
    // background action handler so the "Continue" action on any notification
    // we (re)schedule here keeps working when tapped from the background.
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationActionHandler,
    );

    final payloadParts = response.payload!.split('_');
    if (payloadParts.length >= 3 && payloadParts[0] == 'session' && payloadParts[1] == 'complete') {
      final goalId = int.tryParse(payloadParts[2]);
      if (goalId == null) {
        print('❌ BACKGROUND ACTION: Invalid goalId in payload: ${response.payload}');
        return;
      }

      print('🔄 BACKGROUND ACTION: Processing "Continue" for goal ID: $goalId');
      final goal = await db.getGoal(goalId);

      if (goal == null) {
        print('❌ BACKGROUND ACTION: Goal not found with ID: $goalId');
        return;
      }

      // Double check if goal is already complete
      if (goal.timeSpentSeconds >= goal.totalSeconds) {
        print('ℹ️ BACKGROUND ACTION: Goal ${goal.title} is already complete. No action taken.');
        await notificationsPlugin.cancel(2); // Cancel the notification
        return;
      }

      // 🎯 FIX: Credit the session that just finished BEFORE resuming.
      // The "Continue" notification is fired by an exact local alarm
      // (_scheduleLocalNotification) that does NOT touch the database, while the
      // DB is only updated by the WorkManager _handleSessionCompletion task,
      // which Android routinely delays (Doze/batching). If the user taps
      // "Continue" before WorkManager runs, the goal is still isActive with a
      // non-null sessionResumedTimestampSeconds, meaning timeSpentSeconds still
      // holds the OLD baseline. Reactivating without crediting - combined with
      // scheduleSessionCompletion's ExistingWorkPolicy.replace deleting the
      // still-pending completion task below - would permanently discard the
      // finished session's time (a 15-min session vanishes on every resume).
      int creditedTimeSpent = goal.timeSpentSeconds;
      if (goal.isActive && goal.sessionResumedTimestampSeconds != null) {
        final int nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final int prevSessionElapsed = nowSec - goal.sessionResumedTimestampSeconds!;
        final int prevSessionDuration = _getStaticSessionDurationForGoal(goal);
        if (prevSessionElapsed > 0) {
          final int credit =
              prevSessionElapsed > prevSessionDuration ? prevSessionDuration : prevSessionElapsed;
          final int rawTotal = goal.timeSpentSeconds + credit;
          creditedTimeSpent = rawTotal > goal.totalSeconds ? goal.totalSeconds : rawTotal;
          print(
              '✅ BACKGROUND ACTION: WorkManager had not finalized the finished session yet - '
              'crediting ${_formatTimeStatic(credit)} (total now ${_formatTimeStatic(creditedTimeSpent)}).');
        }
      }

      // If crediting the finished session already completes the goal, finalize
      // instead of starting another session.
      if (creditedTimeSpent >= goal.totalSeconds) {
        final finalizedGoal = goal.copyWith(
          timeSpentSeconds: goal.totalSeconds,
          isActive: false,
          sessionResumedTimestampSeconds: null,
          clearSessionResumedTimestamp: true,
          completedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await db.updateGoal(finalizedGoal);
        await GoalsWidgetUpdater(db).update();
        await notificationsPlugin.cancel(2);
        print('🎉 BACKGROUND ACTION: Goal "${goal.title}" completed after crediting finished session.');
        return;
      }

      // Reactivate goal, persist the credited baseline, and set the session
      // resumed timestamp for the new session.
      final int resumeTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final updatedGoal = goal.copyWith(
        isActive: true,
        timeSpentSeconds: creditedTimeSpent, // Preserve the just-finished session's time
        sessionResumedTimestampSeconds: resumeTimestamp, // Set the resume timestamp
      );
      await db.updateGoal(updatedGoal);
      print('✅ BACKGROUND ACTION: Goal "${updatedGoal.title}" reactivated at $resumeTimestamp '
          '(baseline ${_formatTimeStatic(creditedTimeSpent)}).');

      // Refresh the goals widget so its chronometer restarts with the session.
      await GoalsWidgetUpdater(db).update();

      // Show running notification from background
      await _showBackgroundRunningNotification(notificationsPlugin, updatedGoal);

      // Schedule new session alarm with smart completion detection
      final nextSessionDuration = _getStaticSessionDurationForGoal(updatedGoal);
      final goalRemainingTime = updatedGoal.totalSeconds - updatedGoal.timeSpentSeconds;

      // Smart scheduling: complete when goal is done or session ends
      final willCompleteEarly = goalRemainingTime > 0 && goalRemainingTime < nextSessionDuration;
      final timeUntilCompletion = willCompleteEarly ? goalRemainingTime : nextSessionDuration;

      print('⏰ BACKGROUND ACTION: Smart scheduling');
      print('   - Session duration: ${_formatTimeStatic(nextSessionDuration)}');
      print('   - Goal remaining: ${_formatTimeStatic(goalRemainingTime)}');
      print('   - Will complete early: $willCompleteEarly');
      print('   - Time until completion: ${_formatTimeStatic(timeUntilCompletion)}');

      if (timeUntilCompletion <= 0) {
        print('⚠️ BACKGROUND ACTION: Goal already complete or no time remaining!');
        await notificationsPlugin.cancel(2);
        return;
      }

      final completionTime = DateTime.now().add(Duration(seconds: timeUntilCompletion));
      print(
          '⏰ BACKGROUND ACTION: Scheduling task for: ${completionTime.toString()} (${willCompleteEarly ? "goal completion" : "session end"})');

      try {
        await BackgroundTaskManager.scheduleSessionCompletion(
          goalId: updatedGoal.id!,
          sessionStartTime: resumeTimestamp,
          sessionDuration: timeUntilCompletion,
          completionTime: completionTime,
        );
        print('✅ BACKGROUND ACTION: Next session task scheduled successfully.');
      } catch (e) {
        print('❌ BACKGROUND ACTION: FAILED to schedule next session task: $e');
      }

      // Cancel the "Session Completed" notification (ID 2) that was acted upon.
      // Do this BEFORE scheduling the backup below, otherwise this cancel would
      // also clear the freshly scheduled exact alarm (same notification ID 2).
      await notificationsPlugin.cancel(2);
      print('✅ BACKGROUND ACTION: Cleared session completion notification.');

      // 🎯 FIX: Schedule a backup exact local notification as well. WorkManager
      // alone does not guarantee precise timing (Doze / battery optimization /
      // OEM killers), which caused occasional missed session-completion
      // notifications after resuming via "Continue" while in the background.
      await _scheduleBackgroundCompletionNotification(
        notificationsPlugin,
        updatedGoal,
        completionTime,
        willCompleteEarly,
        nextSessionDuration,
      );
    } else {
      print('⚠️ BACKGROUND ACTION: Unknown payload for CONTINUE_ACTION_ID: ${response.payload}');
    }
  } else if (response.actionId == ROUTINE_DONE_ACTION_ID && response.payload != null) {
    await _handleBackgroundRoutineDone(response.payload!);
  } else {
    print('ℹ️ BACKGROUND ACTION: No actionId or payload not relevant.');
  }
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundRoutineDone(String payload) async {
  try {
    final parts = payload.split('_');
    if (parts.length < 2 || parts[0] != 'routine') {
      print('❌ ROUTINE DONE ACTION: Invalid payload: $payload');
      return;
    }

    final routineId = int.tryParse(parts[1]);
    if (routineId == null) {
      print('❌ ROUTINE DONE ACTION: Invalid routineId in payload: $payload');
      return;
    }

    print('🔔 ROUTINE DONE ACTION: Processing for routine ID: $routineId');

    final db = DatabaseHelper.instance;

    final routinesData = await db.getAllRoutines();
    final routines = routinesData.map((r) => Routine.fromMap(r)).toList();
    final routine = routines.where((r) => r.id == routineId).firstOrNull;

    if (routine == null) {
      print('❌ ROUTINE DONE ACTION: Routine not found with ID: $routineId');
      return;
    }

    if (routine.isDone) {
      print('ℹ️ ROUTINE DONE ACTION: Routine already done, skipping');
      return;
    }

    await db.toggleRoutineDone(routineId, true);

    // Create record only if there isn't one for today (one note per routine per day)
    final alreadyHasRecord = await db.hasRoutineRecordForToday(routineId);
    if (!alreadyHasRecord) {
      final record = {
        DatabaseColumns.recordText: jsonEncode({
          'routine_id': routine.id,
          'routine_name': routine.name,
          'status': 'completed',
        }),
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'routine',
        DatabaseColumns.recordRoutineId: routine.id,
      };
      await db.insertRecord(record, []);
    }

    final notificationService = NotificationService();
    await notificationService.initialize(calledFromBackgroundTask: true);
    await notificationService.markRoutineDone(routineId);

    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await plugin.initialize(initSettings);
    await plugin.cancel(1000 + routineId);

    try {
      final routineWidgetService = RoutineWidgetService(db);
      await routineWidgetService.updateWidget();
    } catch (e) {
      print('⚠️ ROUTINE DONE ACTION: Failed to update widget: $e');
    }

    try {
      await ProductivityService.instance.createOrUpdateDailyRecord();
    } catch (e) {
      print('⚠️ ROUTINE DONE ACTION: Failed to update productivity: $e');
    }

    print('✅ ROUTINE DONE ACTION: Routine "${routine.name}" marked as done');
  } catch (e, stackTrace) {
    print('❌ ROUTINE DONE ACTION: Error: $e');
    print('Stack trace: $stackTrace');
  }
}

@pragma('vm:entry-point')
class TimerService extends ChangeNotifier {
  static final TimerService instance = TimerService._init();
  TimerService._init() {
    _initializeNotifications();
  }

  Timer? _updateTimer; // Only for UI updates, not for actual timing
  Goal? _activeGoal;
  int _sessionStartTime = 0; // Session start timestamp in seconds
  int _baselineTimeSpent = 0; // Time spent when session started (to avoid double counting)
  bool _isRunning = false;

  final DatabaseHelper _db = DatabaseHelper.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final RecordService _recordService = RecordService();

  // Getters
  Goal? get activeGoal => _activeGoal;
  bool get isRunning => _isRunning;

  // 🎯 ENHANCED: Calculate session elapsed time with better precision and validation
  int get sessionTimeElapsed {
    if (!_isRunning || _sessionStartTime == 0) return 0;

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Convert to seconds

    // Validate that current time is reasonable (not in the past)
    if (currentTime < _sessionStartTime) {
      print(
          '⚠️ TIMING WARNING: Current time ($currentTime) is before session start ($_sessionStartTime)');
      return 0;
    }

    final elapsed = currentTime - _sessionStartTime;

    // Validate elapsed time is reasonable (not negative or extremely large)
    if (elapsed < 0) {
      print('⚠️ TIMING ERROR: Negative elapsed time: $elapsed');
      return 0;
    }

    if (elapsed > 86400) {
      // More than 24 hours
      print('⚠️ TIMING WARNING: Extremely long session: ${formatTime(elapsed)}');
    }

    // Debug logging moved to _startUpdateTimer to avoid duplicate logs

    return elapsed;
  }

  // 🎯 ENHANCED: Total time elapsed including baseline with validation
  int get totalTimeElapsed {
    if (_activeGoal == null) return 0;

    final sessionTime = sessionTimeElapsed;
    final total = _baselineTimeSpent + sessionTime;

    // Clamp total to not exceed goal target
    final goalTarget = _activeGoal!.totalSeconds;
    final clampedTotal = total > goalTarget ? goalTarget : total;

    if (total > goalTarget) {
      print(
          '⚠️ TOTAL TIME: Clamped from ${formatTime(total)} to ${formatTime(clampedTotal)} (goal target)');
    }

    return clampedTotal;
  }

  // Remaining time in total goal (not just current session)
  int get goalTimeRemaining {
    if (_activeGoal == null) return 0;
    final totalGoalSeconds = _activeGoal!.totalSeconds;
    final currentTimeSpent = totalTimeElapsed; // Use totalTimeElapsed instead
    return (totalGoalSeconds - currentTimeSpent).clamp(0, totalGoalSeconds);
  }

  // Session remaining time for session completion check
  int get sessionTimeRemaining {
    if (_activeGoal == null) return 0;
    // Use 10 seconds for test goals, normal duration for others
    final sessionDuration = _getSessionDuration();
    return (sessionDuration - sessionTimeElapsed).clamp(0, sessionDuration);
  }

  // Progress percentage for current session (0.0 to 1.0)
  double get sessionProgress {
    if (_activeGoal == null) return 0.0;
    final sessionDuration = _getSessionDuration();
    return (sessionTimeElapsed / sessionDuration).clamp(0.0, 1.0);
  }

  // 🎯 ENHANCED: Get session duration with validation
  int _getSessionDuration() {
    if (_activeGoal == null) return 0;

    // Validate session duration is reasonable
    final sessionMinutes = _activeGoal!.sessionMinutes;
    if (sessionMinutes <= 0) {
      print('⚠️ SESSION DURATION: Invalid session minutes: $sessionMinutes, using default 25');
      return 25 * 60; // Default to 25 minutes
    }

    if (sessionMinutes > 240) {
      // More than 4 hours
      print('⚠️ SESSION DURATION: Very long session: $sessionMinutes minutes, capping at 240');
      return 240 * 60; // Cap at 4 hours
    }

    return sessionMinutes * 60;
  }

  // 🎯 ENHANCED: Initialize with comprehensive state recovery and validation
  Future<void> initialize() async {
    print('🚀 TIMER SERVICE: Initializing...');

    try {
      // Validate database is accessible
      await _db.database;
      print('✅ TIMER SERVICE: Database connection verified');

      // iOS: clear any Live Activity left over from a previous run. If a
      // session is still genuinely active, _resumeSessionFromDatabase below
      // recreates the activity with fresh timestamps.
      await LiveActivityService.instance.endSessionActivity();

      // Check for any orphaned alarms from previous app runs
      await _cleanupOrphanedAlarms();

      // Restore any active sessions that were running when app was terminated
      await _restoreActiveSession();

      // Refresh state from database for any remaining active goals
      await _refreshStateFromDatabase();

      // 🎯 NEW: Reconcile any discrepancies between goals and records
      await _reconcileGoalRecords();

      print('✅ TIMER SERVICE: Initialization completed successfully');
    } catch (e, stackTrace) {
      print('❌ TIMER SERVICE: Initialization failed: $e');
      print('❌ TIMER SERVICE STACK: $stackTrace');

      // On initialization failure, ensure clean state
      _resetSessionState();
    }
  }

  // 🎯 NEW: Clean up any orphaned alarms from previous app runs
  Future<void> _cleanupOrphanedAlarms() async {
    try {
      print('🧩 CLEANUP: Checking for orphaned alarms...');

      // Get all goals from database
      final allGoals = await _db.getAllGoals();

      for (final goal in allGoals) {
        // Cancel alarms for any goal that shouldn't have them
        if (!goal.isActive ||
            goal.completedAt != null ||
            goal.archivedAt != null ||
            goal.timeSpentSeconds >= goal.totalSeconds) {
          try {
            await BackgroundTaskManager.cancelSessionCompletion(goal.id!);
            print(
                '🧩 CLEANUP: Cancelled orphaned task for "${goal.title}" (active: ${goal.isActive}, completed: ${goal.completedAt != null})');
          } catch (e) {
            // It's okay if the task doesn't exist
          }
        }
      }

      print('✅ CLEANUP: Orphaned alarm cleanup completed');
    } catch (e) {
      print('❌ CLEANUP: Failed to cleanup orphaned alarms: $e');
    }
  }

  // 🎯 NEW: Reconcile discrepancies between goals and their progress records
  Future<void> _reconcileGoalRecords() async {
    try {
      print('🔍 RECONCILE: Checking for goal-record discrepancies...');
      final allGoals = await _db.getAllGoals();
      int updatedCount = 0;

      for (final goal in allGoals) {
        if (goal.isActive || goal.currentDayRecordId == null) continue;

        final record = await _db.getRecordById(goal.currentDayRecordId!);
        if (record == null) continue;

        final text = record[DatabaseColumns.recordText] as String;
        int recordMinutes = 0;
        String status = 'active';

        try {
          final jsonData = jsonDecode(text);
          recordMinutes = jsonData['time_minutes'] ?? 0;
          status = jsonData['status'] ?? 'active';
        } catch (e) {
          // Fallback to text parsing
          final match = RegExp(r'time_minutes: (\d+)').firstMatch(text);
          if (match == null) continue;
          recordMinutes = int.parse(match.group(1)!);
          
          if (text.contains('status: completed')) status = 'completed';
          else if (text.contains('status: day_ended')) status = 'day_ended';
          else status = 'active';
        }

        final goalMinutes = (goal.timeSpentSeconds / 60).round();

        if ((recordMinutes - goalMinutes).abs() > 1) {
          print(
              '⚠️ RECONCILE: Discrepancy found for "${goal.title}": Goal $goalMinutes min vs Record $recordMinutes min');

          bool isRecordFinalized = status == 'completed' || status == 'day_ended';
          bool isGoalCompleted = goal.timeSpentSeconds >= goal.totalSeconds;

          if (isRecordFinalized && !isGoalCompleted && goalMinutes <= recordMinutes) {
            continue; // Trust finalized record if goal isn't completed and has less/equal time
          }

          await _updateGoalProgressRecord(goal, goal.timeSpentSeconds);
          updatedCount++;
        } else {
          // 🎯 FIX: Check for status discrepancy even if time matches
          // If goal is completed but record says "active", we must update
          bool isRecordActive = status == 'active';
          bool isGoalCompleted = goal.timeSpentSeconds >= goal.totalSeconds;

          if (isGoalCompleted && isRecordActive) {
            print(
                '⚠️ RECONCILE: Status discrepancy found for "${goal.title}" (Goal: Completed, Record: Active)');
            await _updateGoalProgressRecord(goal, goal.timeSpentSeconds);
            updatedCount++;
          }
        }
      }
      if (updatedCount > 0) print('✅ RECONCILE: Updated $updatedCount records');
    } catch (e) {
      print('❌ RECONCILE: Error: $e');
    }
  }

  // 🎯 NEW: Restore active session that was running when app was terminated
  Future<void> _restoreActiveSession() async {
    try {
      print('🔄 RESTORE: Checking for active session to restore...');

      final activeGoal = await _db.getActiveGoal();
      if (activeGoal == null) {
        print('ℹ️ RESTORE: No active goal found');
        return;
      }

      print('🔄 RESTORE: Found active goal "${activeGoal.title}"');
      print(
          '   - Time spent: ${formatTime(activeGoal.timeSpentSeconds)}/${formatTime(activeGoal.totalSeconds)}');
      print('   - Completed at: ${activeGoal.completedAt}');
      print('   - Resume timestamp: ${activeGoal.sessionResumedTimestampSeconds}');

      // Check if goal was completed while app was closed
      if (activeGoal.completedAt != null ||
          activeGoal.timeSpentSeconds >= activeGoal.totalSeconds) {
        print('🎉 RESTORE: Goal was completed while app was closed');

        // Mark as inactive and clean up
        final cleanedGoal = activeGoal.copyWith(
          isActive: false,
          sessionResumedTimestampSeconds: null,
          clearSessionResumedTimestamp: true,
        );
        await _db.updateGoal(cleanedGoal);

        // 🎯 FIX: Ensure progress record is updated to completed status
        if (activeGoal.currentDayRecordId != null) {
          print('📝 RESTORE: Updating record for completed goal');
          await _updateGoalProgressRecord(activeGoal, activeGoal.timeSpentSeconds);
        }

        // Show completion notification if not already shown
        if (activeGoal.completedAt != null) {
          await _showGoalCompleteNotification();
        }
        return;
      }

      // Check if session was interrupted and needs recovery
      if (activeGoal.sessionResumedTimestampSeconds != null) {
        await _recoverInterruptedSession(activeGoal);
      } else {
        print('ℹ️ RESTORE: Goal is active but no session to recover');
        // Just mark as inactive since there's no session timing to recover
        final cleanedGoal = activeGoal.copyWith(
          isActive: false,
          sessionResumedTimestampSeconds: null,
          clearSessionResumedTimestamp: true,
        );
        await _db.updateGoal(cleanedGoal);
      }
    } catch (e, stackTrace) {
      print('❌ RESTORE: Failed to restore active session: $e');
      print('❌ RESTORE STACK: $stackTrace');
    }
  }

  // 🎯 NEW: Recover interrupted session with time validation
  Future<void> _recoverInterruptedSession(Goal activeGoal) async {
    final resumeTimestamp = activeGoal.sessionResumedTimestampSeconds!;
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sessionElapsed = currentTime - resumeTimestamp;

    print('🔄 RECOVER: Recovering interrupted session');
    print('   - Resume timestamp: $resumeTimestamp');
    print('   - Current time: $currentTime');
    print('   - Elapsed time: ${formatTime(sessionElapsed)}');

    // Validate elapsed time is reasonable
    if (sessionElapsed < 0) {
      print('❌ RECOVER: Invalid negative elapsed time, cannot recover');
      await _cleanupGoalState(activeGoal);
      return;
    }

    if (sessionElapsed > 86400) {
      // More than 24 hours
      print('⚠️ RECOVER: Session was interrupted more than 24 hours ago, cannot recover reliably');
      await _cleanupGoalState(activeGoal);
      return;
    }

    // Calculate session duration that was originally planned
    final sessionDuration = _getStaticSessionDurationForGoal(activeGoal);

    if (sessionElapsed >= sessionDuration) {
      // Session should have completed while app was closed
      print(
          '🎉 RECOVER: Session completed while app was closed (${formatTime(sessionElapsed)} >= ${formatTime(sessionDuration)})');
      await _completeInterruptedSession(activeGoal, sessionDuration);
    } else {
      // Session was still running when app was closed
      print(
          '🔄 RECOVER: Session was still running when app closed (${formatTime(sessionElapsed)} < ${formatTime(sessionDuration)})');

      // 🎯 FIX: Cancel the leftover WorkManager session task. Otherwise it stays
      // pending and, due to ExistingWorkPolicy, could fire shortly after the user
      // re-activates this goal and immediately stop the new session.
      if (activeGoal.id != null) {
        try {
          await BackgroundTaskManager.cancelSessionCompletion(activeGoal.id!);
        } catch (e) {
          print('⚠️ RECOVER: Failed to cancel stale session task: $e');
        }
      }

      // Save the elapsed time and mark as inactive
      final newTimeSpent = activeGoal.timeSpentSeconds + sessionElapsed;
      final goalTarget = activeGoal.totalSeconds;
      final clampedTimeSpent = newTimeSpent > goalTarget ? goalTarget : newTimeSpent;

      // 🎯 UPDATE: Update progress record with recovered time
      if (activeGoal.currentDayRecordId != null) {
        await _updateGoalProgressRecord(activeGoal, clampedTimeSpent);
      }

      final updatedGoal = activeGoal.copyWith(
        timeSpentSeconds: clampedTimeSpent,
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
        completedAt: clampedTimeSpent >= goalTarget ? DateTime.now().millisecondsSinceEpoch : null,
      );

      await _db.updateGoal(updatedGoal);
      print(
          '✅ RECOVER: Partial session time saved: ${formatTime(sessionElapsed)}, total now: ${formatTime(clampedTimeSpent)}');

      if (clampedTimeSpent >= goalTarget) {
        print('🎉 RECOVER: Goal completed during recovery!');
        await _showGoalCompleteNotification();
      }
    }
  }

  // 🎯 NEW: Complete session that finished while app was closed
  Future<void> _completeInterruptedSession(Goal activeGoal, int sessionDuration) async {
    final newTimeSpent = activeGoal.timeSpentSeconds + sessionDuration;
    final goalTarget = activeGoal.totalSeconds;
    final isGoalComplete = newTimeSpent >= goalTarget;

    final finalTimeSpent = isGoalComplete ? goalTarget : newTimeSpent;

    // 🎯 NEW: Update progress record with recovered time
    if (activeGoal.currentDayRecordId != null) {
      await _updateGoalProgressRecord(activeGoal, finalTimeSpent);
    } else if (isGoalComplete) {
      // Fallback: create completion record if no progress record exists
      final recordData = {
        'goal_id': activeGoal.id,
        'time_minutes': (finalTimeSpent / 60).round(),
        'status': 'completed',
      };
      final record = {
        DatabaseColumns.recordTitle: activeGoal.title,
        DatabaseColumns.recordText: jsonEncode(recordData),
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'goal',
        DatabaseColumns.recordGoalId: activeGoal.id,
      };

      final recordService = RecordService();
      await recordService.createRecord(record, []);
    }

    final updatedGoal = activeGoal.copyWith(
      timeSpentSeconds: finalTimeSpent,
      isActive: false,
      sessionResumedTimestampSeconds: null,
      clearSessionResumedTimestamp: true,
      completedAt: isGoalComplete ? DateTime.now().millisecondsSinceEpoch : null,
    );

    await _db.updateGoal(updatedGoal);

    if (isGoalComplete) {
      print('🎉 RECOVER COMPLETE: Goal completed while app was closed!');
      await _showGoalCompleteNotification();
      print('✅ RECOVER COMPLETE: Goal completion processed');
    } else {
      print(
          '✅ RECOVER COMPLETE: Session completed, goal continues with ${formatTime(finalTimeSpent)} total');
    }
  }

  // 🎯 NEW: Clean up goal state that cannot be recovered
  Future<void> _cleanupGoalState(Goal goal) async {
    final cleanedGoal = goal.copyWith(
      isActive: false,
      sessionResumedTimestampSeconds: null,
      clearSessionResumedTimestamp: true,
    );
    await _db.updateGoal(cleanedGoal);

    // 🎯 FIX: Also cancel any pending session task so it can't fire later and
    // interfere with a future session for this goal.
    if (goal.id != null) {
      try {
        await BackgroundTaskManager.cancelSessionCompletion(goal.id!);
      } catch (e) {
        print('⚠️ CLEANUP: Failed to cancel stale session task: $e');
      }
    }

    print('🧩 CLEANUP: Cleaned up unrecoverable goal state for "${goal.title}"');
  }

  // WorkManager initialization removed - now handled in main.dart via BackgroundTaskManager.initialize()

  // 🎯 ENHANCED: Start session with improved precision and validation
  Future<void> startSession(Goal goal) async {
    print('🚀 START SESSION: Initiating session for "${goal.title}"');

    // 🎯 FIX: On the first app open of a new day the daily-reset catch-up runs
    // asynchronously and can land a few seconds AFTER the user hits start,
    // wiping is_active/time_spent of the just-started session. Wait for it
    // here: if the reset already ran today this is a cheap prefs read; if it
    // is in flight we join the shared future. This also guarantees the
    // baseline read below is post-reset (0), not yesterday's leftover time.
    try {
      await DailyResetService.instance.runDailyResetIfNeeded();
    } catch (e) {
      print('⚠️ START SESSION: Daily reset catch-up failed (continuing): $e');
    }

    // Get the latest state and validate
    final latestGoal = await _db.getGoal(goal.id!);
    if (latestGoal == null) {
      print('❌ START SESSION: Goal with ID ${goal.id} not found in DB.');
      return;
    }

    // Validate goal is not already completed
    if (latestGoal.archivedAt != null) {
      print('⚠️ START SESSION: Goal "${latestGoal.title}" is archived');
      return;
    }

    if (latestGoal.completedAt != null ||
        latestGoal.timeSpentSeconds >= latestGoal.totalSeconds) {
      print('⚠️ START SESSION: Goal "${latestGoal.title}" is already completed');
      return;
    }

    // Stop current session if any
    await stopSession();

    // 🎯 FIX: stopSession() early-returns when there is no in-memory active goal
    // (e.g. right after app launch). A stale WorkManager session task for THIS
    // goal could still be pending from a previous run and would otherwise fire a
    // few seconds after we start, flipping isActive=false and stopping the new
    // session. Explicitly cancel it before (re)scheduling a fresh one.
    try {
      await BackgroundTaskManager.cancelSessionCompletion(goal.id!);
    } catch (e) {
      print('⚠️ START SESSION: Failed to cancel any stale session task: $e');
    }

    await _clearOldNotifications();

    var sessionGoal = await _db.getGoal(goal.id!);
    if (sessionGoal == null) {
      print('❌ START SESSION: Goal not found after stop.');
      return;
    }

    // 🎯 ENHANCED: Initialize session with precise timing
    _activeGoal = sessionGoal;
    final preciseStartTime = DateTime.now();
    _sessionStartTime = preciseStartTime.millisecondsSinceEpoch ~/ 1000;
    _isRunning = true;

    print('🚀 START SESSION: Session initialized');
    print('   - Start time: ${preciseStartTime.toIso8601String()}');

    // 🎯 NEW: Create or get record for today's work session
    int? recordId = sessionGoal.currentDayRecordId;

    if (recordId != null) {
      final existingRecord = await _db.getRecordById(recordId);
      if (existingRecord == null) {
        print('📝 START SESSION: Record $recordId was deleted, creating new one');
        recordId = null;
      } else {
        print('📝 START SESSION: Using existing progress record ID: $recordId');
      }
    }

    if (recordId == null && sessionGoal.id != null) {
      final todayId = await _db.getGoalProgressRecordIdForLocalDay(sessionGoal.id!);
      if (todayId != null) {
        final existingRecord = await _db.getRecordById(todayId);
        if (existingRecord != null) {
          recordId = todayId;
          print('📝 START SESSION: Reusing today\'s goal record ID: $recordId');
        }
      }
    }

    if (recordId == null) {
      recordId = await _createGoalProgressRecord(sessionGoal);
      print('📝 START SESSION: Created new progress record with ID: $recordId');
    }

    // After import + reset, goal row may be 0 while today's note still has minutes — align baseline.
    int baselineSeconds = sessionGoal.timeSpentSeconds;
    if (recordId != null) {
      final progressRow = await _db.getRecordById(recordId);
      if (progressRow != null) {
        final text = progressRow[DatabaseColumns.recordText] as String? ?? '';
        final minutesFromRecord = _goalProgressMinutesFromRecordText(text);
        final secondsFromRecord =
            (minutesFromRecord * 60).clamp(0, sessionGoal.totalSeconds);
        if (secondsFromRecord > baselineSeconds) {
          baselineSeconds = secondsFromRecord;
          sessionGoal =
              sessionGoal.copyWith(timeSpentSeconds: secondsFromRecord);
          print(
              '📝 START SESSION: Synced goal time from note (${minutesFromRecord} min)');
        }
      }
    }

    _baselineTimeSpent = baselineSeconds;

    print('   - Baseline: ${formatTime(_baselineTimeSpent)}');
    print('   - Goal target: ${formatTime(sessionGoal.totalSeconds)}');
    print(
        '   - Remaining: ${formatTime(sessionGoal.totalSeconds - baselineSeconds)}');

    final updatedGoal = sessionGoal.copyWith(
      isActive: true,
      sessionResumedTimestampSeconds:
          _sessionStartTime, // 🎯 FIX: Save start time immediately for recovery
      clearSessionResumedTimestamp: false,
      currentDayRecordId: recordId,
    );
    await _db.updateGoal(updatedGoal);
    _activeGoal = updatedGoal;

    // 🎯 ENHANCED: Smart scheduling with precision
    await _scheduleSessionAlarm();

    // Start UI update timer and show notification
    _startUpdateTimer();
    await _showRunningNotification();
    await GoalsWidgetUpdater(_db).update();
    notifyListeners();

    print('✅ START SESSION: Session started successfully for "${sessionGoal.title}"');
  }

  int _goalProgressMinutesFromRecordText(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final tm = decoded['time_minutes'];
        if (tm is int) return tm;
        if (tm is num) return tm.round();
      }
    } catch (_) {}
    final match = RegExp(r'time_minutes:\s*(\d+)').firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!) ?? 0;
    return 0;
  }

  // 🎯 NEW: Create progress record for goal work session
  Future<int?> _createGoalProgressRecord(Goal goal) async {
    try {
      final timeMinutes = (goal.timeSpentSeconds / 60).round();

      final recordData = {
        'goal_id': goal.id,
        'time_minutes': timeMinutes,
        'status': 'active',
      };

      final record = {
        DatabaseColumns.recordTitle: goal.title,
        DatabaseColumns.recordText: jsonEncode(recordData),
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'goal',
        DatabaseColumns.recordGoalId: goal.id,
      };

      final createdRecord = await _recordService.createRecord(record, []);
      if (createdRecord?.id != null) {
        print('✅ Created goal progress record with ID: ${createdRecord!.id}');
        return createdRecord.id;
      } else {
        print('⚠️ Failed to create goal progress record - no ID returned');
        return null;
      }
    } catch (e) {
      print('❌ Failed to create goal progress record: $e');
      return null;
    }
  }

  // 🎯 ENHANCED: Stop session with better progress preservation and validation
  Future<void> stopSession() async {
    if (_activeGoal == null) return;

    final goalTitle = _activeGoal!.title;
    final goalId = _activeGoal!.id;
    final currentSessionTime = sessionTimeElapsed;

    print('🛑 STOP SESSION: Manually stopping session for "$goalTitle"');
    print('   - Session time elapsed: ${formatTime(currentSessionTime)}');
    print('   - Session start time: $_sessionStartTime');

    _isRunning = false;
    _updateTimer?.cancel();

    // Cancel the background task
    if (goalId != null) {
      try {
        await BackgroundTaskManager.cancelSessionCompletion(goalId);
        // Also cancel any scheduled local notification
        await _notificationsPlugin.cancel(2);
        print(
            '🚫 STOP SESSION: Background task and local notification cancelled for goal ID: $goalId');
      } catch (e) {
        print('❌ STOP SESSION: Failed to cancel background task: $e');
      }
    }

    // 🎯 ENHANCED: Save progress with validation and precision
    if (_sessionStartTime > 0 && currentSessionTime >= 0) {
      // Validate session time is reasonable
      final validSessionTime = currentSessionTime.clamp(0, 86400); // Max 24 hours
      if (validSessionTime != currentSessionTime) {
        print(
            '⚠️ STOP SESSION: Clamped session time from ${formatTime(currentSessionTime)} to ${formatTime(validSessionTime)}');
      }

      final totalTimeSpent = _baselineTimeSpent + validSessionTime;
      final goalTarget = _activeGoal!.totalSeconds;

      // Clamp total to not exceed goal (with precision buffer)
      final clampedTotal = totalTimeSpent > goalTarget ? goalTarget : totalTimeSpent;

      print('💾 STOP SESSION: Saving progress');
      print('   - Valid session time: ${formatTime(validSessionTime)}');
      print('   - Baseline: ${formatTime(_baselineTimeSpent)}');
      print('   - Total time: ${formatTime(clampedTotal)}');
      print('   - Goal target: ${formatTime(goalTarget)}');

      // 🎯 NEW: Update progress record with accumulated time
      if (_activeGoal!.currentDayRecordId != null) {
        await _updateGoalProgressRecord(_activeGoal!, clampedTotal);
      }

      final updatedGoal = _activeGoal!.copyWith(
        timeSpentSeconds: clampedTotal,
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
      );

      await _db.updateGoal(updatedGoal);
      _activeGoal = updatedGoal;

      print(
          '✅ STOP SESSION: Progress saved - ${formatTime(validSessionTime)} session, ${formatTime(clampedTotal)} total');

      // Check if this stop completed the goal
      if (clampedTotal >= goalTarget) {
        print('🎉 STOP SESSION: Goal completed by manual stop!');
        // Note: Could trigger completion notification here if desired
      }
    } else {
      print(
          '💾 STOP SESSION: No time to save (start: $_sessionStartTime, elapsed: $currentSessionTime)');
      // Just mark as inactive
      final updatedGoal = _activeGoal!.copyWith(
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
      );
      await _db.updateGoal(updatedGoal);
      _activeGoal = updatedGoal;
    }

    // Clean up UI and state
    await _hideNotification();
    _resetSessionState();
    await GoalsWidgetUpdater(_db).update();
    notifyListeners();

    print('✅ STOP SESSION: Session stopped for "$goalTitle" - All progress preserved');
    await ProductivityService.instance.createOrUpdateDailyRecord();
  }

  // 🎯 NEW: Update progress record with current time spent
  Future<void> _updateGoalProgressRecord(Goal goal, int totalTimeSpent) async {
    try {
      if (goal.currentDayRecordId == null) {
        print('⚠️ Cannot update progress record: no record ID');
        return;
      }

      // Get existing record
      final existingRecord = await _db.getRecordById(goal.currentDayRecordId!);
      if (existingRecord == null) {
        print('⚠️ Progress record ${goal.currentDayRecordId} not found');
        return;
      }

      final timeMinutes = (totalTimeSpent / 60).round();
      final isCompleted = totalTimeSpent >= goal.totalSeconds;

      // Handle existing text format or new JSON format
      final String currentText = existingRecord[DatabaseColumns.recordText] as String;
      Map<String, dynamic> recordData = {};
      
      try {
        recordData = jsonDecode(currentText);
      } catch (e) {
        // Fallback or create new structure
        recordData = {
          'goal_id': goal.id,
        };
      }

      // Update values
      recordData['goal_id'] = goal.id; // Ensure it's correct
      recordData['time_minutes'] = timeMinutes;
      recordData['status'] = isCompleted ? 'completed' : 'active';

      final updatedRecord = {
        DatabaseColumns.id: goal.currentDayRecordId,
        DatabaseColumns.recordText: jsonEncode(recordData),
        DatabaseColumns.recordTitle: existingRecord[DatabaseColumns.recordTitle],
        DatabaseColumns.recordCreatedAt: existingRecord[DatabaseColumns.recordCreatedAt],
        DatabaseColumns.recordType: existingRecord[DatabaseColumns.recordType],
        DatabaseColumns.recordGoalId: existingRecord[DatabaseColumns.recordGoalId],
      };

      // Get existing tags and filter out Chrono tag
      final db = await _db.database;
      final tags = await db.rawQuery('''
        SELECT rt.tagId, t.${DatabaseColumns.tagName} as tagName
        FROM ${DatabaseTables.recordTag} rt
        JOIN ${DatabaseTables.category} t ON rt.tagId = t.${DatabaseColumns.id}
        WHERE rt.recordId = ?
      ''', [goal.currentDayRecordId]);

      final tagIds = tags
          .where((tag) => tag['tagName'] != 'Chrono')
          .map((tag) => tag['tagId'] as int)
          .toList();

      await _db.updateRecord(updatedRecord, tagIds);
      print(
          '✅ Updated progress record ID ${goal.currentDayRecordId} with $timeMinutes minutes (tags: ${tagIds.length})');
    } catch (e) {
      print('❌ Failed to update progress record: $e');
    }
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();

    // This timer is now ONLY for UI updates, background completion is handled by alarm
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final sessionElapsed = sessionTimeElapsed;
      final sessionDuration = _getSessionDuration();

      // Debug logging every 30 seconds (moved here to avoid duplicates from getter)
      if (sessionElapsed % 30 == 0 && sessionElapsed > 0) {
        print(
            '🕐 TIMING DEBUG: Goal "${_activeGoal?.title}" - Session: ${formatTime(sessionElapsed)}/${formatTime(sessionDuration)}');
      }

      // 🎯 CRITICAL: Check if the goal is still active in database (background callback might have completed it)
      if (_activeGoal != null) {
        final currentGoalInDb = await _db.getGoal(_activeGoal!.id!);

        // 🎯 ENHANCED: Detect background completion with better synchronization
        if (currentGoalInDb == null) {
          print('🔄 UI TIMER: Goal deleted from DB - stopping UI timer');
          await _handleBackgroundCompletion();
          return;
        }

        // Background completion detection: goal marked inactive or completed
        if (!currentGoalInDb.isActive || currentGoalInDb.completedAt != null) {
          print('🔄 UI TIMER: Background completion detected - stopping UI timer');
          print('   - Active in DB: ${currentGoalInDb.isActive}');
          print('   - CompletedAt: ${currentGoalInDb.completedAt}');
          await _handleBackgroundCompletion();
          return;
        }

        // 🎯 FIX: Detect a session that was resumed externally (e.g. the "Continue"
        // notification action handled by the background isolate). In that case the
        // DB's sessionResumedTimestampSeconds advances past our in-memory
        // _sessionStartTime. If we don't realign, sessionTimeElapsed keeps counting
        // from the previous (already-finished) session start and the timer inflates
        // (e.g. a 15-min session showing 40+ min). Adopt the new start + baseline.
        final int? dbResumeTs = currentGoalInDb.sessionResumedTimestampSeconds;
        if (dbResumeTs != null && dbResumeTs > _sessionStartTime) {
          print(
              '🔄 TIMER SYNC: External resume detected - realigning session start ${_sessionStartTime} -> $dbResumeTs');
          _sessionStartTime = dbResumeTs;
          _baselineTimeSpent = currentGoalInDb.timeSpentSeconds;
          _activeGoal = currentGoalInDb;
          notifyListeners();
          return; // Recompute cleanly on the next tick with corrected values
        }

        // 🎯 ENHANCED: Detect if time spent was updated by background
        if (currentGoalInDb.timeSpentSeconds != _activeGoal!.timeSpentSeconds) {
          final oldTime = _activeGoal!.timeSpentSeconds;
          final newTime = currentGoalInDb.timeSpentSeconds;
          print(
              '🔄 TIMER SYNC: Goal time updated by background: ${formatTime(oldTime)} -> ${formatTime(newTime)}');

          // Update our local state but recalculate baseline to maintain consistency
          _activeGoal = currentGoalInDb;
          _baselineTimeSpent = newTime; // Adjust baseline since background updated progress

          // 🎯 FIX: Ensure record is updated if background updated the time
          if (_activeGoal!.currentDayRecordId != null) {
            print('🔄 TIMER SYNC: Ensuring record matches background time');
            await _updateGoalProgressRecord(_activeGoal!, newTime);
          }

          // Check if this background update completed the goal
          if (newTime >= currentGoalInDb.totalSeconds) {
            print('🎉 BACKGROUND COMPLETION: Goal completed by background update');
            await _handleBackgroundCompletion();
            return;
          }
        } else {
          // Normal sync - just update the goal object
          _activeGoal = currentGoalInDb;
        }

        // 🎯 ENHANCED: Check if goal has been completed during this session (foreground)
        final currentTotalTime = totalTimeElapsed;
        final goalTotalSeconds = _activeGoal!.totalSeconds;

        if (currentTotalTime >= goalTotalSeconds) {
          print('🎉 FOREGROUND COMPLETION: Goal completed during this session');
          print('   Current total time: ${formatTime(currentTotalTime)}');
          print('   Goal target: ${formatTime(goalTotalSeconds)}');
          await _handleGoalCompletion();
          return;
        }

        // 🎯 NEW: Check if session has completed (WorkManager is unreliable for precise timing)
        if (sessionElapsed >= sessionDuration) {
          print('🎉 FOREGROUND SESSION COMPLETION: Session completed');
          print('   Session time: ${formatTime(sessionElapsed)}/${formatTime(sessionDuration)}');
          await _handleSessionCompletion(sessionElapsed);
          return;
        }
      }

      // Just update UI and notifications
      if (sessionElapsed % 10 == 0) {
        // Reduce log frequency
        print(
            'UI Update: Session time: ${formatTime(sessionElapsed)}/${formatTime(sessionDuration)}');
      }

      // No periodic notification repaint needed: the Android chronometer and
      // the iOS Live Activity timer are rendered live by the OS itself.

      notifyListeners();
    });
  }

  // 🎯 NEW: Handle goal completion during session
  Future<void> _handleGoalCompletion() async {
    print('🎉 Goal completion detected during session');

    if (_activeGoal == null) return;

    // Check if the goal has already been completed in the DB
    final latestGoal = await _db.getGoal(_activeGoal!.id!);
    if (latestGoal?.completedAt != null) {
      print('ℹ️ FOREGROUND: Goal ${latestGoal!.title} already marked as completed. Skipping.');
      // It's possible the UI timer lagged behind the background callback.
      // We should still stop the local timer and clean up.
      _isRunning = false;
      _updateTimer?.cancel();
      await _hideNotification();
      notifyListeners();
      return;
    }

    // Cancel the scheduled session task since we're completing early
    try {
      await BackgroundTaskManager.cancelSessionCompletion(_activeGoal!.id!);
      print('🚫 Cancelled session task due to goal completion');
    } catch (e) {
      print('❌ Failed to cancel session task: $e');
    }

    // Save final progress with exact goal completion
    final exactGoalTime = _activeGoal!.totalSeconds;
    final sessionTimeToComplete = exactGoalTime - _baselineTimeSpent;

    // 🎯 NEW: Update existing progress record to mark as completed
    if (_activeGoal!.currentDayRecordId != null) {
      await _updateGoalProgressRecord(_activeGoal!, exactGoalTime);
    } else {
      // Fallback: create a completion record if no progress record exists
      final recordData = {
        'goal_id': _activeGoal!.id,
        'time_minutes': (exactGoalTime / 60).round(),
        'status': 'completed',
      };
      final record = {
        DatabaseColumns.recordTitle: _activeGoal!.title,
        DatabaseColumns.recordText: jsonEncode(recordData),
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'goal',
        DatabaseColumns.recordGoalId: _activeGoal!.id
      };
      await _recordService.createRecord(record, []);
      print('📝 Fallback: Record created for completed goal.');
    }

    final completedGoal = _activeGoal!.copyWith(
      timeSpentSeconds: exactGoalTime, // Set to exact goal completion
      isActive: false,
      sessionResumedTimestampSeconds: null, // Clear it
      clearSessionResumedTimestamp: true,
      completedAt: DateTime.now().millisecondsSinceEpoch, // Mark as completed
    );

    await _db.updateGoal(completedGoal);

    print('✅ Goal completed exactly: ${formatTime(exactGoalTime)}');
    print('✅ Session time to complete: ${formatTime(sessionTimeToComplete)}');

    // Refresh the goals widget so its chronometer stops on completion.
    await GoalsWidgetUpdater(_db).update();

    // Stop the timer
    _isRunning = false;
    _updateTimer?.cancel();

    // Show goal completion notifications
    await _showGoalCompleteNotification();
    await _showSessionCompletionNotificationForGoalComplete(sessionTimeToComplete);

    // Hide running notification
    await _hideNotification();

    // Clear session state
    _activeGoal = completedGoal;
    _sessionStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print('✅ Session stopped due to goal completion');
    await ProductivityService.instance.createOrUpdateDailyRecord();
  }

  // 🎯 NEW: Special session completion notification for goal completion
  Future<void> _showSessionCompletionNotificationForGoalComplete(int sessionTime) async {
    if (_activeGoal == null) return;

    try {
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

      await _notificationsPlugin.show(
        2,
        'Session Complete - Goal Achieved! 🎉',
        '${_activeGoal!.title} - ${formatTime(sessionTime)} session completed your goal!',
        details,
        payload: 'goal_complete_${_activeGoal!.id}',
      );

      print('✅ Goal completion session notification sent');
    } catch (e) {
      print('❌ Failed to show goal completion session notification: $e');
    }
  }

  // 🎯 NEW: Handle session completion (when session ends but goal is not complete)
  Future<void> _handleSessionCompletion(int sessionElapsed) async {
    print('🎉 Session completion detected');

    if (_activeGoal == null) return;

    // Check if the goal has already been completed or marked inactive in the DB
    final latestGoal = await _db.getGoal(_activeGoal!.id!);
    if (latestGoal == null) {
      print('ℹ️ SESSION COMPLETION: Goal not found. Cleaning up.');
      await _cleanupSession('Goal not found');
      return;
    }

    if (latestGoal.completedAt != null) {
      print('ℹ️ SESSION COMPLETION: Goal already completed. Cleaning up.');
      await _cleanupSession('Goal already completed');
      return;
    }

    if (!latestGoal.isActive) {
      print('ℹ️ SESSION COMPLETION: Goal already inactive. Cleaning up.');
      await _cleanupSession('Goal already inactive');
      return;
    }

    // Cancel the scheduled background task since we're handling completion in foreground
    try {
      await BackgroundTaskManager.cancelSessionCompletion(_activeGoal!.id!);
      print('🚫 Cancelled background task for session completion');
    } catch (e) {
      print('❌ Failed to cancel background task: $e');
    }

    // Calculate and save progress
    final sessionDuration = _getSessionDuration();
    final newTimeSpent = _baselineTimeSpent + sessionDuration;
    final goalTarget = _activeGoal!.totalSeconds;
    final clampedTimeSpent = newTimeSpent > goalTarget ? goalTarget : newTimeSpent;

    print('💾 SESSION COMPLETION: Saving progress');
    print('   - Session duration: ${formatTime(sessionDuration)}');
    print('   - Baseline: ${formatTime(_baselineTimeSpent)}');
    print('   - New time spent: ${formatTime(clampedTimeSpent)}');

    // 🎯 NEW: Update progress record with session time
    if (_activeGoal!.currentDayRecordId != null) {
      await _updateGoalProgressRecord(_activeGoal!, clampedTimeSpent);
    }

    // Update goal in database
    final updatedGoal = _activeGoal!.copyWith(
      timeSpentSeconds: clampedTimeSpent,
      isActive: false,
      sessionResumedTimestampSeconds: null,
      clearSessionResumedTimestamp: true,
    );

    await _db.updateGoal(updatedGoal);
    print('✅ SESSION COMPLETION: Goal updated successfully');

    // Refresh the goals widget so its chronometer stops when the session ends.
    await GoalsWidgetUpdater(_db).update();

    // Stop the timer
    _isRunning = false;
    _updateTimer?.cancel();

    // Show session completion notification with "Continue" button
    await _showSessionCompletionNotification(sessionDuration);

    // Hide running notification
    await _hideNotification();

    // Update local state
    _activeGoal = updatedGoal;
    _sessionStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print('✅ SESSION COMPLETION: Session stopped, goal can be resumed later');
    await ProductivityService.instance.createOrUpdateDailyRecord();
  }

  // 🎯 NEW: Show session completion notification with "Continue" action
  Future<void> _showSessionCompletionNotification(int sessionDuration) async {
    if (_activeGoal == null) return;

    try {
      // Add "Continue" button for resuming session
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
        actions: const [
          AndroidNotificationAction(
            'CONTINUE_SESSION_ACTION',
            'Continue',
          ),
        ],
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

      await _notificationsPlugin.show(
        2,
        'Session Completed! 🎉',
        '${_activeGoal!.title} - ${formatTime(sessionDuration)} session finished. Great work!',
        details,
        payload: 'session_complete_${_activeGoal!.id}',
      );

      print('✅ Session completion notification sent');
    } catch (e) {
      print('❌ Failed to show session completion notification: $e');
    }
  }

  // 🎯 ENHANCED: Handle when background callback has completed the session with better synchronization
  Future<void> _handleBackgroundCompletion() async {
    print('🎉 BG COMPLETION UI: Detected background completion via UI timer.');

    // Cancel the background task since we're handling completion now
    if (_activeGoal?.id != null) {
      try {
        await BackgroundTaskManager.cancelSessionCompletion(_activeGoal!.id!);
        print('🚫 BG COMPLETION: Cancelled remaining task for goal ${_activeGoal!.id}');
      } catch (e) {
        print('❌ BG COMPLETION: Failed to cancel task: $e');
      }
    }

    _isRunning = false;
    _updateTimer?.cancel();
    await _hideNotification();

    // 🎯 ENHANCED: More robust state refresh with validation
    final currentActiveGoalId = _activeGoal?.id;
    final previousTitle = _activeGoal?.title;

    if (currentActiveGoalId != null) {
      final updatedGoalFromDb = await _db.getGoal(currentActiveGoalId);
      if (updatedGoalFromDb != null) {
        _activeGoal = updatedGoalFromDb;
        print('✅ BG COMPLETION UI: Goal state refreshed from DB:');
        print('   - Title: "${_activeGoal!.title}"');
        print(
            '   - Time spent: ${formatTime(_activeGoal!.timeSpentSeconds)}/${formatTime(_activeGoal!.totalSeconds)}');
        print('   - Active: ${_activeGoal!.isActive}');
        print('   - Completed at: ${_activeGoal!.completedAt}');

        // 🎯 FIX: Force update the progress record to ensure it matches the background state
        if (_activeGoal!.currentDayRecordId != null) {
          print('🔄 BG COMPLETION UI: Forcing record update to match goal state');
          await _updateGoalProgressRecord(_activeGoal!, _activeGoal!.timeSpentSeconds);
        }

        // 🎯 FIX: The background isolate normally shows the completion
        // notification (ID 2), but that show is wrapped in a silent try/catch
        // and can fail. Guarantee the user is notified: if no completion
        // notification is currently visible, show it now. Guarded by
        // getActiveNotifications to avoid duplicating the background one.
        final bool isGoalComplete = _activeGoal!.completedAt != null ||
            _activeGoal!.timeSpentSeconds >= _activeGoal!.totalSeconds;
        await _ensureCompletionNotificationShown(_activeGoal!, isGoalComplete);
      } else {
        print(
            '⚠️ BG COMPLETION UI: Goal $currentActiveGoalId not found in DB. Goal may have been deleted.');
        _activeGoal = null;
      }
    } else {
      print('ℹ️ BG COMPLETION UI: No active goal ID to refresh.');
      _activeGoal = null;
    }

    // Clear session-specific running state variables
    _sessionStartTime = 0;
    _baselineTimeSpent = 0;

    // Refresh the goals widget so its chronometer reflects the ended session.
    await GoalsWidgetUpdater(_db).update();

    notifyListeners();
    print(
        '✅ BG COMPLETION UI: State synchronized. Previous session for "$previousTitle" handled by background.');
  }

  // 🎯 NEW: Show the completion notification (ID 2) only if it isn't already
  // visible. Used as a safety net when the background isolate may have updated
  // the DB but failed (silently) to display the completion notification.
  Future<void> _ensureCompletionNotificationShown(Goal goal, bool isGoalComplete) async {
    try {
      // Only do the active-notification check on Android; iOS getActiveNotifications
      // semantics differ and we prefer not to risk duplicates there.
      if (Platform.isAndroid) {
        try {
          final active = await _notificationsPlugin.getActiveNotifications();
          final alreadyShown = active.any((n) => n.id == 2);
          if (alreadyShown) {
            print('ℹ️ BG COMPLETION UI: Completion notification (ID 2) already visible - skipping');
            return;
          }
        } catch (e) {
          // If we cannot determine the active notifications, assume the
          // background isolate already showed it to avoid double-notifying.
          print('⚠️ BG COMPLETION UI: Could not query active notifications ($e) - skipping reshow');
          return;
        }
      } else {
        return;
      }

      print('🔔 BG COMPLETION UI: Completion notification missing - showing safety-net alert');

      final sessionDuration = _getSessionDuration();
      final actions = !isGoalComplete
          ? [const AndroidNotificationAction(CONTINUE_ACTION_ID, 'Continue')]
          : null;

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
        actions: actions,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final title = isGoalComplete ? 'Session Complete - Goal Achieved! 🎉' : 'Session Completed! 🎉';
      final body = isGoalComplete
          ? '${goal.title} - ${formatTime(sessionDuration)} session completed your goal!'
          : '${goal.title} - ${formatTime(sessionDuration)} session finished. Great work!';

      await _notificationsPlugin.show(
        2,
        title,
        body,
        details,
        payload:
            isGoalComplete ? 'goal_complete_${goal.id}' : 'session_complete_${goal.id}',
      );
      print('✅ BG COMPLETION UI: Safety-net completion notification shown');
    } catch (e) {
      print('❌ BG COMPLETION UI: Failed to ensure completion notification: $e');
    }
  }

  // 🎯 ENHANCED: Save current session progress with validation and robustness
  Future<void> _saveProgressToDatabase() async {
    if (_activeGoal == null || _sessionStartTime == 0) return;

    try {
      final currentSessionTime = sessionTimeElapsed;

      // Validate session time is reasonable
      if (currentSessionTime < 0) {
        print('⚠️ SAVE PROGRESS: Invalid negative session time: $currentSessionTime');
        return;
      }

      if (currentSessionTime > 86400) {
        // More than 24 hours
        print(
            '⚠️ SAVE PROGRESS: Extremely long session time: ${formatTime(currentSessionTime)} - capping at 24 hours');
        // Cap at reasonable maximum
        final cappedSessionTime = 86400;
        final totalTimeSpent = _baselineTimeSpent + cappedSessionTime;
        final updatedGoal = _activeGoal!.copyWith(
          timeSpentSeconds: totalTimeSpent,
          sessionResumedTimestampSeconds:
              _isRunning && _sessionStartTime > 0 ? _sessionStartTime : null,
        );
        await _db.updateGoal(updatedGoal);
        _activeGoal = updatedGoal;
        return;
      }

      // Calculate total time with validation
      final totalTimeSpent = _baselineTimeSpent + currentSessionTime;

      // Ensure we don't exceed the goal (with small buffer for precision)
      final goalTarget = _activeGoal!.totalSeconds;
      final clampedTotal = totalTimeSpent > goalTarget ? goalTarget : totalTimeSpent;

      if (totalTimeSpent != clampedTotal) {
        print(
            '⚠️ SAVE PROGRESS: Clamped total time from ${formatTime(totalTimeSpent)} to ${formatTime(clampedTotal)}');
      }

      // 🎯 FIX: For resumed sessions (continued from background), preserve the baseline in the database
      // The alarm will add the full session duration to this baseline when it fires
      // Only update sessionResumedTimestampSeconds to keep the session alive
      final bool isResumedSession = _activeGoal!.sessionResumedTimestampSeconds != null;

      if (isResumedSession) {
        // This is a resumed session - do NOT update timeSpentSeconds in database
        // Keep the baseline value so the alarm can use it correctly
        final updatedGoal = _activeGoal!.copyWith(
          // timeSpentSeconds is NOT updated - keeps the baseline from when session started
          sessionResumedTimestampSeconds: _sessionStartTime,
        );
        await _db.updateGoal(updatedGoal);

        // Update local cache to reflect current progress for UI
        _activeGoal = _activeGoal!.copyWith(
          timeSpentSeconds: clampedTotal,
          sessionResumedTimestampSeconds: _sessionStartTime,
        );

        print(
            '💾 SAVE PROGRESS (RESUMED SESSION): Local total: ${formatTime(clampedTotal)}, DB baseline preserved: ${formatTime(_baselineTimeSpent)}');
        print(
            '   - Database timeSpentSeconds NOT updated (alarm will update when session completes)');
      } else {
        // Normal save for non-resumed sessions
        final updatedGoal = _activeGoal!.copyWith(
          timeSpentSeconds: clampedTotal,
          sessionResumedTimestampSeconds:
              _isRunning && _sessionStartTime > 0 ? _sessionStartTime : null,
        );
        await _db.updateGoal(updatedGoal);
        _activeGoal = updatedGoal;

        print(
            '💾 SAVE PROGRESS: Session time: ${formatTime(currentSessionTime)}, Total: ${formatTime(clampedTotal)}, Baseline: ${formatTime(_baselineTimeSpent)}');
        if (_isRunning && _sessionStartTime > 0) {
          print(
              '   - Preserved sessionResumedTimestampSeconds: $_sessionStartTime for background coordination');
        }
      }

      // Update baseline if we had to clamp (maintains consistency for next calculation)
      if (clampedTotal != totalTimeSpent) {
        _baselineTimeSpent = clampedTotal;
        print('   - Baseline adjusted to: ${formatTime(_baselineTimeSpent)}');
      }
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  // Public method for saving progress (called by app lifecycle)
  Future<void> saveProgress() async {
    await _saveProgressToDatabase();
  }

  // Notification methods

  // Show the ongoing session indicator once per session start/resume.
  // Android: chronometer notification the OS keeps ticking on its own.
  // iOS: Live Activity with a native timer (no updatable notifications there).
  Future<void> _showRunningNotification() async {
    if (_activeGoal == null) {
      print('❌ Cannot show running notification - no active goal');
      return;
    }

    if (Platform.isIOS) {
      final int sessionEndTime = _sessionStartTime + _getSessionDuration();
      await LiveActivityService.instance.startSessionActivity(
        goalTitle: _activeGoal!.title,
        sessionStartTimeSeconds: _sessionStartTime,
        sessionEndTimeSeconds: sessionEndTime,
        totalSpentSeconds: _baselineTimeSpent,
        goalTargetSeconds: _activeGoal!.totalSeconds,
      );
      return;
    }

    try {
      final details = NotificationDetails(
        android: _buildRunningAndroidDetails(_sessionStartTime),
      );

      await _notificationsPlugin.show(
        1,
        '🎯 ${_activeGoal!.title}',
        _buildRunningNotificationBody(_activeGoal!, _baselineTimeSpent),
        details,
        payload: 'running_goal_${_activeGoal!.id}',
      );

      print(
          '✅ NOTIFICATION: Chronometer running notification shown (session start: $_sessionStartTime)');
    } catch (e) {
      print('❌ NOTIFICATION ERROR: Failed to show running notification: $e');
    }
  }

  Future<void> _hideNotification() async {
    print('🚫 NOTIFICATION: Hiding running notification (ID: 1)');
    try {
      if (Platform.isIOS) {
        await LiveActivityService.instance.endSessionActivity();
        return;
      }
      await _notificationsPlugin.cancel(1);
      print('✅ NOTIFICATION: Running notification hidden successfully');
    } catch (e) {
      print('❌ NOTIFICATION ERROR: Failed to hide notification: $e');
    }
  }

  Future<void> _showGoalCompleteNotification() async {
    if (_activeGoal == null) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'goal_complete_v2',
      'Goal Complete',
      channelDescription: 'Notifications for completed goals',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: kAlertVibrationPattern,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      4,
      '🎉 Goal Completed!',
      '${_activeGoal!.title} - Congratulations!',
      platformChannelSpecifics,
    );
  }

  // Format time for display
  String formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    // Always show hh:mm:ss format
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Handle notification tap to navigate to Goals screen
  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) {
      print('Goal notification tapped but no payload provided');
      return;
    }

    print('📱 Goal notification tapped with payload: ${response.payload}');

    try {
      // Use the global navigator key to show bottom sheet
      final context = navigatorKey.currentContext;
      if (context == null) {
        print('⚠️ No navigation context available');
        return;
      }

      print('🚀 Navigating to Goals screen');

      // Show the Goals bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const GoalsScreen(),
      );
    } catch (e, stackTrace) {
      print('❌ Error handling goal notification tap: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    try {
      // Request notification permissions for Android 13+
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        print('Notification permission status: $status');

        if (status.isDenied) {
          print('Notification permission denied');
          return;
        }
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      bool? initialized = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            backgroundNotificationActionHandler, // REGISTER THE HANDLER
      );
      print('Notification plugin initialized: $initialized');

      // Create notification channels for Android
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // Channel for the ongoing chronometer notification. v2: the old
          // 'timer_channel' was already created on user devices and channel
          // settings are frozen after creation, so a new ID guarantees the
          // silent (no sound/vibration) configuration actually applies.
          const timerChannel = AndroidNotificationChannel(
            'timer_channel_v2',
            'Timer Notifications',
            description: 'Ongoing notification for the active goal session',
            importance: Importance.defaultImportance,
            enableVibration: false,
            playSound: false,
          );
          await androidPlugin.createNotificationChannel(timerChannel);
          // Remove the legacy channel so it doesn't linger in system settings.
          try {
            await androidPlugin.deleteNotificationChannel('timer_channel');
          } catch (_) {}

          // Channel for session completion notifications. v2: the old
          // 'session_complete_channel' was created without an explicit
          // vibration pattern, and channel settings are frozen after creation,
          // so the default (weak) vibration stuck. A new ID guarantees the
          // strong pattern actually applies.
          final completionChannel = AndroidNotificationChannel(
            'session_complete_channel_v2',
            'Session Completed',
            description: 'Notifications when a session is completed',
            importance: Importance.max,
            enableVibration: true,
            vibrationPattern: kAlertVibrationPattern,
            playSound: true,
          );
          await androidPlugin.createNotificationChannel(completionChannel);
          try {
            await androidPlugin.deleteNotificationChannel('session_complete_channel');
          } catch (_) {}

          // Channel for goal completion. v2: same reason as above.
          final goalCompleteChannel = AndroidNotificationChannel(
            'goal_complete_v2',
            'Goal Complete',
            description: 'Notifications for completed goals',
            importance: Importance.max,
            enableVibration: true,
            vibrationPattern: kAlertVibrationPattern,
            playSound: true,
          );
          await androidPlugin.createNotificationChannel(goalCompleteChannel);
          try {
            await androidPlugin.deleteNotificationChannel('goal_complete');
          } catch (_) {}

          print('All notification channels created');

          // 🎯 FIX: Ensure exact-alarm permission so scheduled (zonedSchedule)
          // session-completion notifications fire on time. Without it, the
          // exact-alarm backup silently degrades and we rely only on the
          // (imprecise) WorkManager task, causing occasional missed alerts.
          await _ensureExactAlarmPermission(androidPlugin);
        }
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  // 🎯 NEW: Check and request the exact-alarm permission (Android 12+).
  Future<void> _ensureExactAlarmPermission(
      AndroidFlutterLocalNotificationsPlugin androidPlugin) async {
    try {
      final bool? canSchedule = await androidPlugin.canScheduleExactNotifications();
      print('🔔 EXACT ALARM: canScheduleExactNotifications = $canSchedule');

      if (canSchedule == false) {
        print('⚠️ EXACT ALARM: Permission NOT granted - requesting...');
        final bool? granted = await androidPlugin.requestExactAlarmsPermission();
        print('🔔 EXACT ALARM: requestExactAlarmsPermission result = $granted');
        if (granted != true) {
          print(
              '⚠️ EXACT ALARM: Exact alarms still disabled. Scheduled session notifications may be delayed or dropped (relying on WorkManager only).');
        }
      }
    } catch (e) {
      print('❌ EXACT ALARM: Failed to check/request exact alarm permission: $e');
    }
  }

  // 🎯 ENHANCED: Refresh timer state with robust validation and error recovery
  Future<void> _refreshStateFromDatabase() async {
    try {
      print('🔄 REFRESH: Starting state refresh from database');
      final activeGoalFromDb = await _db.getActiveGoal();

      if (activeGoalFromDb == null) {
        // No active goals in database - clean up local state
        if (_isRunning) {
          print('🔄 REFRESH: No active goal found in database, stopping local timer.');
          await _cleanupSession('No active goal in DB');
        } else {
          // Ensure local state is completely clean
          _resetSessionState();
        }
      } else {
        print('🔄 REFRESH: Found active goal "${activeGoalFromDb.title}" in database');
        print(
            '   - Goal progress: ${formatTime(activeGoalFromDb.timeSpentSeconds)}/${formatTime(activeGoalFromDb.totalSeconds)}');
        print('   - Is active: ${activeGoalFromDb.isActive}');
        print('   - Completed at: ${activeGoalFromDb.completedAt}');
        print('   - Resume timestamp: ${activeGoalFromDb.sessionResumedTimestampSeconds}');

        // Check if goal is actually complete
        if (activeGoalFromDb.completedAt != null ||
            activeGoalFromDb.timeSpentSeconds >= activeGoalFromDb.totalSeconds) {
          print('🎉 REFRESH: Goal is already completed, cleaning up');
          await _cleanupSession('Goal already completed');
          return;
        }

        // An active goal exists in the database
        if (!_isRunning || _activeGoal?.id != activeGoalFromDb.id) {
          print(
              '🔄 REFRESH: Starting/Resuming session (was running: $_isRunning, current goal: ${_activeGoal?.id})');
          await _resumeSessionFromDatabase(activeGoalFromDb);
        } else if (_isRunning && _activeGoal?.id == activeGoalFromDb.id) {
          print('🔄 REFRESH: Same goal already running, syncing data');
          await _syncRunningSession(activeGoalFromDb);
        }
      }
    } catch (e, stackTrace) {
      print('❌ REFRESH ERROR: Failed to refresh state: $e');
      print('❌ REFRESH STACK: $stackTrace');
      // On error, stop current session to prevent inconsistent state
      await _cleanupSession('Refresh error: $e');
    }
  }

  // 🎯 NEW: Clean session state helper
  void _resetSessionState() {
    _activeGoal = null;
    _sessionStartTime = 0;
    _baselineTimeSpent = 0;
    _isRunning = false;
  }

  // 🎯 NEW: Clean up session with reason logging
  Future<void> _cleanupSession(String reason) async {
    print('🧩 CLEANUP: Cleaning up session - $reason');

    _isRunning = false;
    _updateTimer?.cancel();
    await _hideNotification();

    // Cancel any pending tasks
    if (_activeGoal?.id != null) {
      try {
        await BackgroundTaskManager.cancelSessionCompletion(_activeGoal!.id!);
      } catch (e) {
        print('⚠️ CLEANUP: Failed to cancel task: $e');
      }
    }

    _resetSessionState();
    notifyListeners();
  }

  // 🎯 NEW: Resume session from database state
  Future<void> _resumeSessionFromDatabase(Goal activeGoal) async {
    _activeGoal = activeGoal;
    _baselineTimeSpent = activeGoal.timeSpentSeconds;

    // Calculate session start time
    if (activeGoal.sessionResumedTimestampSeconds != null &&
        activeGoal.sessionResumedTimestampSeconds! > 0) {
      _sessionStartTime = activeGoal.sessionResumedTimestampSeconds!;
      print('🔄 RESUME: Using resume timestamp: ${_sessionStartTime}');

      // 🎯 FIX: Keep sessionResumedTimestampSeconds set so foreground knows this is a resumed session
      // This flag tells _saveProgressToDatabase to preserve the baseline in the database
      _activeGoal = activeGoal;
    } else {
      _sessionStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      print('🔄 RESUME: Starting new session at: ${_sessionStartTime}');
      _activeGoal = activeGoal;
    }

    _isRunning = true;

    await _clearOldNotifications();
    await _scheduleSessionAlarm();
    _startUpdateTimer();
    await _showRunningNotification();
    notifyListeners();
  }

  // 🎯 NEW: Sync currently running session
  Future<void> _syncRunningSession(Goal activeGoal) async {
    final oldTimeSpent = _activeGoal?.timeSpentSeconds ?? 0;

    // 🎯 FIX: If the session was resumed externally while the app was in the
    // background (e.g. via the "Continue" notification action), the DB's
    // sessionResumedTimestampSeconds points at the NEW session start while our
    // in-memory _sessionStartTime still points at the previous (finished)
    // session. Without realigning, sessionTimeElapsed re-counts the old session
    // and the timer inflates (a 15-min session could show 40+ min after resume).
    final int? dbResumeTs = activeGoal.sessionResumedTimestampSeconds;
    if (dbResumeTs != null && dbResumeTs > _sessionStartTime) {
      print(
          '🔄 SYNC: External resume detected - realigning session start ${_sessionStartTime} -> $dbResumeTs');
      _sessionStartTime = dbResumeTs;
      _baselineTimeSpent = activeGoal.timeSpentSeconds;
      _activeGoal = activeGoal;
      _startUpdateTimer();
      notifyListeners();
      return;
    }

    _activeGoal = activeGoal;

    // If time spent changed externally, adjust baseline
    if (activeGoal.timeSpentSeconds != oldTimeSpent) {
      print(
          '🔄 SYNC: Time spent changed externally: ${formatTime(oldTimeSpent)} -> ${formatTime(activeGoal.timeSpentSeconds)}');
      _baselineTimeSpent = activeGoal.timeSpentSeconds;
    }

    _startUpdateTimer(); // Ensure timer is running
    notifyListeners();
  }

  // 🎯 NEW: Schedule session alarm with smart completion detection
  Future<void> _scheduleSessionAlarm() async {
    if (_activeGoal?.id == null) return;

    final sessionDuration = _getSessionDuration();
    if (sessionDuration <= 0) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sessionElapsed = currentTime - _sessionStartTime;
    final remainingSessionDuration = (sessionDuration - sessionElapsed).clamp(0, sessionDuration);

    final currentTotalTime = _baselineTimeSpent + sessionElapsed;
    final goalRemainingTime =
        (_activeGoal!.totalSeconds - currentTotalTime).clamp(0, _activeGoal!.totalSeconds);

    print(
        '🔄 SCHEDULE: Session remaining: ${formatTime(remainingSessionDuration)}, Goal remaining: ${formatTime(goalRemainingTime)}');

    // Smart scheduling: complete when goal is done or session ends
    final willCompleteEarly = goalRemainingTime > 0 && goalRemainingTime < remainingSessionDuration;
    final timeUntilCompletion = willCompleteEarly ? goalRemainingTime : remainingSessionDuration;

    if (timeUntilCompletion <= 0) {
      print('ℹ️ SCHEDULE: Nothing to schedule (time: $timeUntilCompletion)');
      return;
    }

    final completionTime = DateTime.now().add(Duration(seconds: timeUntilCompletion));
    print(
        '⏰ SCHEDULE: WorkManager task for ${completionTime} (${willCompleteEarly ? "goal completion" : "session end"})');

    try {
      // 1. Schedule background task via WorkManager (handles DB updates)
      await BackgroundTaskManager.scheduleSessionCompletion(
        goalId: _activeGoal!.id!,
        sessionStartTime: _sessionStartTime,
        sessionDuration: timeUntilCompletion,
        completionTime: completionTime,
      );
      print('✅ SCHEDULE: WorkManager task scheduled successfully');

      // 2. Schedule exact local notification
      await _scheduleLocalNotification(
        completionTime: completionTime,
        isGoalCompletion: willCompleteEarly,
        sessionDuration: sessionDuration, // Total session duration for display
      );
    } catch (e) {
      print('❌ SCHEDULE: Failed to schedule tasks: $e');
    }
  }

  // 🎯 NEW: Schedule exact local notification
  Future<void> _scheduleLocalNotification({
    required DateTime completionTime,
    required bool isGoalCompletion,
    required int sessionDuration,
  }) async {
    try {
      // Initialize timezone if needed (safe to call repeatedly)
      // tz.initializeTimeZones() should be called in main, but we ensure tz.local is set
      try {
        tz.TZDateTime.now(tz.local);
      } catch (e) {
        // Fallback initialization if timezone isn't set
        print('⚠️ SCHEDULE: Timezone not initialized, using default');
        // This relies on main.dart having initialized it or NotificationService
      }

      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(completionTime, tz.local);

      final title =
          isGoalCompletion ? 'Session Complete - Goal Achieved! 🎉' : 'Session Completed! 🎉';

      final body = isGoalCompletion
          ? '${_activeGoal!.title} - ${formatTime(sessionDuration)} session completed your goal!'
          : '${_activeGoal!.title} - ${formatTime(sessionDuration)} session finished. Great work!';

      // Use the same ID (2) as the session completion notification
      const int notificationId = 2;

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
        // Add "Continue" action only if goal is not complete
        actions: !isGoalCompletion
            ? [
                const AndroidNotificationAction(
                  'CONTINUE_SESSION_ACTION',
                  'Continue',
                ),
              ]
            : null,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = isGoalCompletion
          ? 'goal_complete_${_activeGoal!.id}'
          : 'session_complete_${_activeGoal!.id}';

      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
        print('✅ SCHEDULE: Exact local notification scheduled for $scheduledDate');
      } catch (exactError) {
        // 🎯 FIX: Don't silently lose the notification when exact alarms are
        // unavailable (e.g. SCHEDULE_EXACT_ALARM revoked). Fall back to an
        // inexact schedule so the user still gets the alert, just slightly late.
        print(
            '⚠️ SCHEDULE: Exact schedule failed ($exactError). Falling back to inexact schedule.');
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        print('✅ SCHEDULE: Inexact local notification scheduled for $scheduledDate (fallback)');
      }
    } catch (e) {
      print('❌ SCHEDULE: Failed to schedule local notification: $e');
    }
  }

  // Public method to refresh state (can be called from app lifecycle)
  Future<void> refreshState() async {
    await _refreshStateFromDatabase();
  }

  // Clear old completion notifications
  Future<void> _clearOldNotifications() async {
    try {
      print('🧹 Clearing old completion notifications');
      // Clear session completion notifications (ID 2)
      await _notificationsPlugin.cancel(2);
      // Clear goal completion notifications (ID 4)
      await _notificationsPlugin.cancel(4);
      print('✅ Old notifications cleared');
    } catch (e) {
      print('❌ Failed to clear old notifications: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
