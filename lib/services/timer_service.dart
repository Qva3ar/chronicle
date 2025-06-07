import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../db_manager.dart';
import '../models/goal.model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../record.service.dart';

const String CONTINUE_ACTION_ID = 'CONTINUE_SESSION_ACTION';

// Top-level callback function for alarm manager - must be outside of any class
@pragma('vm:entry-point')
Future<void> sessionCompleteCallback(int alarmId) async {
  // Ensure Flutter bindings are initialized for background isolates.
  WidgetsFlutterBinding.ensureInitialized();

  print('🔔 BACKGROUND CALLBACK: Session completion alarm fired for goal ID: $alarmId');
  try {
    // Initialize services in background context
    final db = DatabaseHelper.instance;
    final recordService = RecordService();
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize notifications in background
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await notificationsPlugin.initialize(initSettings);

    // Get the goal from database (alarmId is the goalId)
    final goalAtAlarmTime = await db.getGoal(alarmId);
    if (goalAtAlarmTime == null) {
      print('❌ BACKGROUND: Goal not found with ID: $alarmId');
      return;
    }

    // Check if the goal has already been marked as completed
    if (goalAtAlarmTime.completedAt != null) {
      print('ℹ️ BACKGROUND: Goal ${goalAtAlarmTime.title} already completed. Skipping.');
      return;
    }

    print('📊 BACKGROUND: Processing session completion for: ${goalAtAlarmTime.title}');

    // This is the duration for which this session was scheduled and has now completed.
    final int sessionDurationForThisAlarm =
        goalAtAlarmTime.title.contains('Test Goal') ? 10 : (goalAtAlarmTime.sessionMinutes * 60);

    // Calculate new time spent and check for goal completion
    final newTimeSpentAfterThisSession =
        goalAtAlarmTime.timeSpentSeconds + sessionDurationForThisAlarm;
    final isGoalNowActuallyComplete = newTimeSpentAfterThisSession >= goalAtAlarmTime.totalSeconds;

    if (isGoalNowActuallyComplete) {
      print('🎉 BACKGROUND: This session completes the goal!');
      final updatedGoal = goalAtAlarmTime.copyWith(
        timeSpentSeconds: goalAtAlarmTime.totalSeconds, // Complete exactly to goal's total
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
        completedAt: DateTime.now().millisecondsSinceEpoch, // Mark as completed
      );
      await db.updateGoal(updatedGoal);
      print(
          '✅ BACKGROUND: Goal completed. Total time: ${_formatTimeStatic(updatedGoal.totalSeconds)}');

      // Create a record for the completed goal
      final record = {
        DatabaseColumns.recordTitle: 'Goal Completed: ${updatedGoal.title}',
        DatabaseColumns.recordText:
            'Finished a goal session, completing the goal. Total time: ${_formatTimeStatic(updatedGoal.totalSeconds)}',
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'goal',
        DatabaseColumns.recordGoalId: updatedGoal.id,
      };
      await recordService.createRecord(record, []);
      print('📝 BACKGROUND: Record created for completed goal.');

      // Show goal completion notifications
      await _showBackgroundGoalCompleteNotification(notificationsPlugin, updatedGoal);
      // Also show a session completion, indicating the session that finished it
      await _showBackgroundCompletionNotification(
          notificationsPlugin, updatedGoal, sessionDurationForThisAlarm);
    } else {
      print('📝 BACKGROUND: Session completed, goal continues.');
      final updatedGoal = goalAtAlarmTime.copyWith(
        timeSpentSeconds: newTimeSpentAfterThisSession, // Save the new total time spent
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
      );
      await db.updateGoal(updatedGoal);
      print(
          '✅ BACKGROUND: Goal updated. Time spent now: ${_formatTimeStatic(updatedGoal.timeSpentSeconds)}');

      // Show session completion notification
      await _showBackgroundCompletionNotification(
          notificationsPlugin, updatedGoal, sessionDurationForThisAlarm);
    }
  } catch (e) {
    print('❌ BACKGROUND ERROR: $e');
  }
}

// Helper functions for background callback
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
  // Use 10 seconds for test goals
  if (goal.title.contains('Test Goal')) {
    return 10; // 10 seconds for testing
  }
  return goal.sessionMinutes * 60; // Normal duration
}

@pragma('vm:entry-point')
Future<void> _showBackgroundCompletionNotification(
    FlutterLocalNotificationsPlugin plugin, Goal goal, int sessionDuration) async {
  try {
    print(
        '💡 BG NOTIF: Attempting to show session completion notification for ${goal.title} at ${DateTime.now()}');
    final bool isGoalNowComplete = goal.timeSpentSeconds >= goal.totalSeconds;
    List<AndroidNotificationAction> actions = [];
    if (!isGoalNowComplete) {
      actions.add(const AndroidNotificationAction(CONTINUE_ACTION_ID, 'Continue'));
    }

    final androidDetails = AndroidNotificationDetails(
      'session_complete_channel',
      'Session Completed',
      channelDescription: 'Notifications when a session is completed',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      autoCancel:
          true, // Auto cancel when tapped, action buttons remain until action taken or dismissed
      actions: actions.isNotEmpty ? actions : null, // Add actions here
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

    await plugin.show(
      2,
      'Session Completed! 🎉',
      '${goal.title} - ${_formatTimeStatic(sessionDuration)} session finished. Great work!',
      details,
      payload: 'session_complete_${goal.id}',
    );

    print('✅ BACKGROUND: Session completion notification sent');
  } catch (e) {
    print('❌ BACKGROUND: Failed to show completion notification: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _showBackgroundGoalCompleteNotification(
    FlutterLocalNotificationsPlugin plugin, Goal goal) async {
  try {
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

    print('✅ BACKGROUND: Goal completion notification sent');
  } catch (e) {
    print('❌ BACKGROUND: Failed to show goal completion notification: $e');
  }
}

@pragma('vm:entry-point')
// NEW: Show a running notification from background context
Future<void> _showBackgroundRunningNotification(
    FlutterLocalNotificationsPlugin plugin, Goal goal) async {
  try {
    print('💡 BG NOTIF: Attempting to show BACKGROUND RUNNING notification for ${goal.title}');

    const androidDetails = AndroidNotificationDetails(
      'timer_channel', // Same channel as the foreground running notification
      'Timer Notifications',
      channelDescription: 'Notifications for goal timer sessions',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationTitle = '🎯 ${goal.title} (Running)';
    // Since we don't have live sessionTimeElapsed or goalTimeRemaining here without TimerService state,
    // we show the overall progress from the goal object itself.
    final notificationBody =
        '⏱️ Progress: ${_formatTimeStatic(goal.timeSpentSeconds)} / ${_formatTimeStatic(goal.totalSeconds)}';

    await plugin.show(
      1, // Use the same ID as the main running notification
      notificationTitle,
      notificationBody,
      details,
      payload: 'running_goal_${goal.id}', // Optional: payload for if user taps this
    );

    print('✅ BACKGROUND: Running notification shown for ${goal.title}');
  } catch (e) {
    print('❌ BACKGROUND: Failed to show running notification: $e');
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

    // Initialize notifications (needed to cancel one)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await notificationsPlugin.initialize(initSettings);

    // Initialize Alarm Manager (needed to schedule new alarm)
    await AndroidAlarmManager.initialize();

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

      // Reactivate goal and set the session resumed timestamp
      final int resumeTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final updatedGoal = goal.copyWith(
        isActive: true,
        sessionResumedTimestampSeconds: resumeTimestamp, // Set the resume timestamp
      );
      await db.updateGoal(updatedGoal);
      print('✅ BACKGROUND ACTION: Goal "${updatedGoal.title}" reactivated at $resumeTimestamp.');

      // Show running notification from background
      await _showBackgroundRunningNotification(notificationsPlugin, updatedGoal);

      // Schedule new session alarm
      final nextSessionDuration = _getStaticSessionDurationForGoal(updatedGoal);
      final alarmTime = DateTime.now().add(Duration(seconds: nextSessionDuration));

      print(
          '⏰ BACKGROUND ACTION: Scheduling next session alarm for: ${alarmTime.toString()} in ${nextSessionDuration}s');
      try {
        await AndroidAlarmManager.oneShotAt(
          alarmTime,
          updatedGoal.id!,
          sessionCompleteCallback,
          alarmClock: true,
          wakeup: true,
          rescheduleOnReboot: false,
        );
        print('✅ BACKGROUND ACTION: Next session alarm scheduled successfully.');
      } catch (e) {
        print('❌ BACKGROUND ACTION: FAILED to schedule next session alarm: $e');
      }

      // Cancel the "Session Completed" notification (ID 2) that was acted upon
      await notificationsPlugin.cancel(2);
      print('✅ BACKGROUND ACTION: Cleared session completion notification.');
    } else {
      print('⚠️ BACKGROUND ACTION: Unknown payload for CONTINUE_ACTION_ID: ${response.payload}');
    }
  } else {
    print('ℹ️ BACKGROUND ACTION: No actionId or payload not relevant.');
  }
}

@pragma('vm:entry-point')
class TimerService extends ChangeNotifier {
  static final TimerService instance = TimerService._init();
  TimerService._init() {
    _initializeNotifications();
    _initializeAlarmManager();
  }

  Timer? _updateTimer; // Only for UI updates, not for actual timing
  Goal? _activeGoal;
  int _sessionStartTime = 0; // Session start timestamp in seconds
  int _goalStartTime = 0; // Goal session start timestamp in seconds
  int _baselineTimeSpent = 0; // Time spent when session started (to avoid double counting)
  bool _isRunning = false;

  final DatabaseHelper _db = DatabaseHelper.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final RecordService _recordService = RecordService();

  // Getters
  Goal? get activeGoal => _activeGoal;
  bool get isRunning => _isRunning;

  // Calculate session elapsed time based on timestamps
  int get sessionTimeElapsed {
    if (!_isRunning || _sessionStartTime == 0) return 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Convert to seconds
    final elapsed = currentTime - _sessionStartTime;

    // Debug logging every 30 seconds to track timing issues
    if (elapsed % 30 == 0 && elapsed > 0) {
      print('🕐 TIMING DEBUG: Start: $_sessionStartTime, Current: $currentTime, Elapsed: $elapsed');
    }

    return elapsed;
  }

  // 🎯 NEW: Total time elapsed including baseline (what user should see)
  int get totalTimeElapsed {
    if (_activeGoal == null) return 0;
    return _baselineTimeSpent + sessionTimeElapsed;
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

  // Get the effective session duration (10 seconds for test goals)
  int _getSessionDuration() {
    if (_activeGoal == null) return 0;
    // Use 10 seconds for test goals
    if (_activeGoal!.title.contains('Test Goal')) {
      return 10; // 10 seconds for testing
    }
    return _activeGoal!.sessionMinutes * 60; // Normal duration
  }

  Future<void> initialize() async {
    // Check if there was an active goal that might have been completed while app was closed
    await _refreshStateFromDatabase();
  }

  Future<void> _initializeAlarmManager() async {
    try {
      await AndroidAlarmManager.initialize();
      print('✅ Alarm Manager initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Alarm Manager: $e');
    }
  }

  Future<void> startSession(Goal goal) async {
    // Always get the latest state of the goal from the database before starting a session.
    // This prevents race conditions where the UI might hold a stale goal object.
    final latestGoal = await _db.getGoal(goal.id!);
    if (latestGoal == null) {
      print('❌ Cannot start session, goal with ID ${goal.id} not found in DB.');
      return;
    }

    // Stop current session if any
    await stopSession();

    // Clear any old completion notifications to prevent confusion
    await _clearOldNotifications();

    _activeGoal = latestGoal;
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Store in seconds
    _sessionStartTime = currentTime;
    _goalStartTime = currentTime;
    _baselineTimeSpent = latestGoal.timeSpentSeconds; // Capture baseline to avoid double counting
    _isRunning = true;

    // Update goal as active in database and clear any sessionResumedTimestamp
    final updatedGoal = latestGoal.copyWith(
      isActive: true,
      sessionResumedTimestampSeconds: null, // Clear it
      clearSessionResumedTimestamp: true, // Explicitly clear
    );
    await _db.updateGoal(updatedGoal);
    _activeGoal = updatedGoal;

    // Schedule background alarm for session completion
    final sessionDuration = _getSessionDuration();
    final alarmTime = DateTime.now().add(Duration(seconds: sessionDuration));

    // 🎯 NEW: Check if goal will be completed before session ends
    final goalRemainingTime = latestGoal.totalSeconds - latestGoal.timeSpentSeconds;
    final willCompleteEarly = goalRemainingTime < sessionDuration;

    if (willCompleteEarly) {
      print('⚠️ SMART SCHEDULING: Goal will complete early!');
      print('   Goal remaining: ${formatTime(goalRemainingTime)}');
      print('   Session duration: ${formatTime(sessionDuration)}');
      print('   Scheduling alarm for goal completion instead of full session');

      // Schedule alarm for when goal will be completed, not full session
      final goalCompleteTime = DateTime.now().add(Duration(seconds: goalRemainingTime));

      print('⏰ Scheduling GOAL COMPLETION alarm for: ${goalCompleteTime.toString()}');
      print('⏰ Goal ID: ${latestGoal.id}, will complete in: ${formatTime(goalRemainingTime)}');

      try {
        await AndroidAlarmManager.oneShotAt(
          goalCompleteTime,
          latestGoal.id!, // Use goal ID as alarm ID
          sessionCompleteCallback, // Use same callback but it will complete the goal
          alarmClock: true,
          wakeup: true,
          rescheduleOnReboot: false,
        );
        print('✅ Goal completion alarm scheduled successfully');
      } catch (e) {
        print('❌ FAILED to schedule goal completion alarm: $e');
      }
    } else {
      print('⏰ Scheduling background alarm for: ${alarmTime.toString()}');
      print('⏰ Session duration: ${formatTime(sessionDuration)}');
      print('⏰ Goal ID: ${latestGoal.id}, Alarm ID will be: ${latestGoal.id}');

      try {
        await AndroidAlarmManager.oneShotAt(
          alarmTime,
          latestGoal.id!, // Use goal ID as alarm ID
          sessionCompleteCallback, // Use top-level function
          alarmClock: true, // This ensures it works even in doze mode
          wakeup: true, // Wake up device if needed
          rescheduleOnReboot: false, // Don't persist across reboots
        );
        print('✅ Background alarm scheduled successfully');
      } catch (e) {
        print('❌ FAILED to schedule background alarm: $e');
      }
    }

    // Start UI update timer (for display only)
    _startUpdateTimer();

    // Show notification
    await _showRunningNotification();

    notifyListeners();
    print('Session started for: ${latestGoal.title} at timestamp: $currentTime');
    print('Baseline time spent: ${formatTime(_baselineTimeSpent)}');
  }

  Future<void> stopSession() async {
    if (_activeGoal == null) return;

    final goalTitle = _activeGoal!.title;
    final currentSessionTime = sessionTimeElapsed;
    print('Manually stopping session for: $goalTitle');
    print('Saving partial session time: ${formatTime(currentSessionTime)}');

    _isRunning = false;
    _updateTimer?.cancel();

    // Cancel the background alarm
    if (_activeGoal?.id != null) {
      try {
        await AndroidAlarmManager.cancel(_activeGoal!.id!);
        print('🚫 Background alarm cancelled for goal ID: ${_activeGoal!.id}');
      } catch (e) {
        print('❌ Failed to cancel background alarm: $e');
      }
    }

    // ALWAYS save current progress before stopping - even partial sessions count!
    if (_sessionStartTime > 0 && currentSessionTime > 0) {
      print('Preserving ${formatTime(currentSessionTime)} of session time...');

      // Calculate and save the total time including this partial session
      final totalTimeSpent = _baselineTimeSpent + currentSessionTime;

      final updatedGoal = _activeGoal!.copyWith(
        timeSpentSeconds: totalTimeSpent,
        isActive: false,
        sessionResumedTimestampSeconds: null, // Clear it
        clearSessionResumedTimestamp: true,
      );

      await _db.updateGoal(updatedGoal);
      _activeGoal = updatedGoal;

      print('✅ Partial session time saved: ${formatTime(currentSessionTime)}');
      print('✅ Total time is now: ${formatTime(totalTimeSpent)}');
    } else {
      // Just mark as inactive if no time elapsed
      final updatedGoal = _activeGoal!.copyWith(
        isActive: false,
        sessionResumedTimestampSeconds: null, // Clear it
        clearSessionResumedTimestamp: true,
      );
      await _db.updateGoal(updatedGoal);
      _activeGoal = updatedGoal;
    }

    // Hide notification
    await _hideNotification();

    _activeGoal = null;
    _sessionStartTime = 0;
    _goalStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print('Session stopped for: $goalTitle - All time preserved, timer is now inactive');
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();

    // This timer is now ONLY for UI updates, background completion is handled by alarm
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final sessionElapsed = sessionTimeElapsed;
      final sessionDuration = _getSessionDuration();

      // Check if the goal is still active in database (background callback might have completed it)
      if (_activeGoal != null) {
        final currentGoalInDb = await _db.getGoal(_activeGoal!.id!);
        if (currentGoalInDb == null || !currentGoalInDb.isActive) {
          print('🔄 UI TIMER: Background completion detected - stopping UI timer');
          await _handleBackgroundCompletion();
          return;
        }

        // Debug: Check if goal data changed unexpectedly
        if (currentGoalInDb.timeSpentSeconds != _activeGoal!.timeSpentSeconds) {
          print(
              '🔄 TIMER DEBUG: Goal time changed in DB: ${formatTime(_activeGoal!.timeSpentSeconds)} -> ${formatTime(currentGoalInDb.timeSpentSeconds)}');
          _activeGoal = currentGoalInDb;
        }

        // 🎯 NEW: Check if goal has been completed during this session
        final currentTotalTime = totalTimeElapsed; // Use new getter
        final goalTotalSeconds = _activeGoal!.totalSeconds;

        if (currentTotalTime >= goalTotalSeconds) {
          print('🎉 GOAL COMPLETED! Stopping session early.');
          print('   Current total time: ${formatTime(currentTotalTime)}');
          print('   Goal target: ${formatTime(goalTotalSeconds)}');
          await _handleGoalCompletion();
          return;
        }
      }

      // Just update UI and notifications - alarm handles the actual completion
      print(
          'UI Update: Session time: ${formatTime(sessionElapsed)}/${formatTime(sessionDuration)}');

      // Update notifications periodically
      if (sessionElapsed % 60 == 0 && sessionElapsed > 0) {
        await _showRunningNotification();
      }

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

    // Cancel the scheduled session alarm since we're completing early
    try {
      await AndroidAlarmManager.cancel(_activeGoal!.id!);
      print('🚫 Cancelled session alarm due to goal completion');
    } catch (e) {
      print('❌ Failed to cancel session alarm: $e');
    }

    // Save final progress with exact goal completion
    final exactGoalTime = _activeGoal!.totalSeconds;
    final sessionTimeToComplete = exactGoalTime - _baselineTimeSpent;

    final completedGoal = _activeGoal!.copyWith(
      timeSpentSeconds: exactGoalTime, // Set to exact goal completion
      isActive: false,
      sessionResumedTimestampSeconds: null, // Clear it
      clearSessionResumedTimestamp: true,
      completedAt: DateTime.now().millisecondsSinceEpoch, // Mark as completed
    );

    await _db.updateGoal(completedGoal);

    // Create a record for the completed goal
    final record = {
      DatabaseColumns.recordTitle: 'Goal Completed: ${completedGoal.title}',
      DatabaseColumns.recordText:
          'Finished a goal session of ${formatTime(sessionTimeToComplete)}, completing the goal.',
      DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
      DatabaseColumns.recordType: 'goal',
      DatabaseColumns.recordGoalId: completedGoal.id
    };
    await _recordService.createRecord(record, []);
    print('📝 Record created for completed goal.');

    print('✅ Goal completed exactly: ${formatTime(exactGoalTime)}');
    print('✅ Session time to complete: ${formatTime(sessionTimeToComplete)}');

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
    _goalStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print('✅ Session stopped due to goal completion');
  }

  // 🎯 NEW: Special session completion notification for goal completion
  Future<void> _showSessionCompletionNotificationForGoalComplete(int sessionTime) async {
    if (_activeGoal == null) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'session_complete_channel',
        'Session Completed',
        channelDescription: 'Notifications when a session is completed',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
      );

      const details = NotificationDetails(
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

  // Handle when background callback has completed the session
  Future<void> _handleBackgroundCompletion() async {
    print('🎉 BG COMPLETION UI: Detected background completion via UI timer.');

    _isRunning = false;
    _updateTimer?.cancel();
    await _hideNotification();

    // Refresh our local state from the database, which was updated by the background callback.
    // Store the ID before potentially nullifying _activeGoal
    final currentActiveGoalId = _activeGoal?.id;

    if (currentActiveGoalId != null) {
      final updatedGoalFromDb = await _db.getGoal(currentActiveGoalId);
      if (updatedGoalFromDb != null) {
        _activeGoal = updatedGoalFromDb;
        print(
            '✅ BG COMPLETION UI: Goal state refreshed from DB: "${_activeGoal!.title}", Time: ${formatTime(_activeGoal!.timeSpentSeconds)}, Active: ${_activeGoal!.isActive}');
      } else {
        print(
            '⚠️ BG COMPLETION UI: Goal $currentActiveGoalId not found in DB for refresh. Clearing local _activeGoal.');
        _activeGoal = null;
      }
    } else {
      print('ℹ️ BG COMPLETION UI: No local _activeGoal ID was set. Clearing local _activeGoal.');
      _activeGoal = null; // Ensure it's cleared if there wasn't one locally
    }

    // Clear session-specific running state variables
    _sessionStartTime = 0;
    _goalStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print(
        '✅ BG COMPLETION UI: UI timer stopped & state refreshed. Session completion primarily handled by background.');
  }

  // Save current session progress to database
  Future<void> _saveProgressToDatabase() async {
    if (_activeGoal == null || _sessionStartTime == 0) return;

    try {
      final currentSessionTime = sessionTimeElapsed;

      // Calculate total time: baseline when session started + current session time
      final totalTimeSpent = _baselineTimeSpent + currentSessionTime;

      final updatedGoal = _activeGoal!.copyWith(timeSpentSeconds: totalTimeSpent);
      await _db.updateGoal(updatedGoal);

      _activeGoal = updatedGoal;

      print(
          'Progress saved: ${formatTime(currentSessionTime)} session time, total: ${formatTime(totalTimeSpent)} (baseline: ${formatTime(_baselineTimeSpent)})');
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  // Public method for saving progress (called by app lifecycle)
  Future<void> saveProgress() async {
    await _saveProgressToDatabase();
  }

  // Notification methods
  Future<void> _showRunningNotification() async {
    if (_activeGoal == null) {
      print('❌ Cannot show running notification - no active goal');
      return;
    }

    print('🔔 NOTIFICATION: Updating running notification');
    print('   - Goal: ${_activeGoal!.title}');
    print(
        '   - Session time: ${formatTime(sessionTimeElapsed)}/${formatTime(_getSessionDuration())}');
    print('   - Goal remaining: ${formatTime(goalTimeRemaining)}');

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'timer_channel', // Use the same channel we created
        'Timer Notifications',
        channelDescription: 'Notifications for goal timer sessions',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: false, // Don't alert for ongoing notifications
        presentBadge: true,
        presentSound: false,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      final notificationTitle = '🎯 ${_activeGoal!.title}';
      final notificationBody =
          '⏱️ Elapsed: ${formatTime(totalTimeElapsed)} | Session: ${formatTime(sessionTimeElapsed)} | Goal: ${formatTime(goalTimeRemaining)} left';

      await _notificationsPlugin.show(
        1,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );

      print('✅ NOTIFICATION: Running notification updated successfully');
    } catch (e) {
      print('❌ NOTIFICATION ERROR: Failed to show running notification: $e');
    }
  }

  Future<void> _updateNotification() async {
    if (_activeGoal == null || !_isRunning) return;
    await _showRunningNotification();
  }

  Future<void> _hideNotification() async {
    print('🚫 NOTIFICATION: Hiding running notification (ID: 1)');
    try {
      await _notificationsPlugin.cancel(1);
      print('✅ NOTIFICATION: Running notification hidden successfully');
    } catch (e) {
      print('❌ NOTIFICATION ERROR: Failed to hide notification: $e');
    }
  }

  Future<void> _showSessionNotification() async {
    if (_activeGoal == null) return;
    await _showRunningNotification();
  }

  Future<void> _showGoalCompleteNotification() async {
    if (_activeGoal == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'goal_complete',
      'Goal Complete',
      channelDescription: 'Notifications for completed goals',
      importance: Importance.max,
      priority: Priority.max,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
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

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification clicks
          print('Notification clicked: ${response.payload}');
          if (response.payload?.startsWith('session_complete_') == true) {
            // Handle session complete notification click
            // You can navigate to the goal details or start a new session
          }
        },
        onDidReceiveBackgroundNotificationResponse:
            backgroundNotificationActionHandler, // REGISTER THE HANDLER
      );
      print('Notification plugin initialized: $initialized');

      // Create notification channels for Android
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // Channel for ongoing timer notifications
          const timerChannel = AndroidNotificationChannel(
            'timer_channel',
            'Timer Notifications',
            description: 'Notifications for goal timer sessions',
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
          );
          await androidPlugin.createNotificationChannel(timerChannel);

          // Channel for session completion notifications
          const completionChannel = AndroidNotificationChannel(
            'session_complete_channel',
            'Session Completed',
            description: 'Notifications when a session is completed',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
          );
          await androidPlugin.createNotificationChannel(completionChannel);

          // Channel for goal completion
          const goalCompleteChannel = AndroidNotificationChannel(
            'goal_complete',
            'Goal Complete',
            description: 'Notifications for completed goals',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
          );
          await androidPlugin.createNotificationChannel(goalCompleteChannel);

          print('All notification channels created');
        }
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  // Refresh timer state from database (call when app resumes)
  Future<void> _refreshStateFromDatabase() async {
    try {
      final activeGoalFromDb = await _db.getActiveGoal();

      if (activeGoalFromDb == null) {
        // No active goals in database - clear our state if something was running
        if (_isRunning) {
          print('🔄 REFRESH: No active goal found in database, stopping local timer.');
          _isRunning = false;
          _updateTimer?.cancel();
          await _hideNotification();
          _activeGoal = null; // Clear our local reference
          _sessionStartTime = 0;
          _goalStartTime = 0;
          _baselineTimeSpent = 0;
          notifyListeners();
        } else {
          // Ensure local state is clean if nothing was running and no active goal in DB
          if (_activeGoal != null || _sessionStartTime != 0 || _baselineTimeSpent != 0) {
            _activeGoal = null;
            _sessionStartTime = 0;
            _goalStartTime = 0;
            _baselineTimeSpent = 0;
            // notifyListeners(); // Only if state actually changed and UI needs update
          }
        }
      } else {
        // An active goal exists in the database.
        if (!_isRunning || _activeGoal?.id != activeGoalFromDb.id) {
          // Case 1: Timer wasn't running locally, OR it's a *different* active goal in DB.
          // This handles:
          //   a) App startup/resume finding an already active goal.
          //   b) "Continue" action making a previously inactive goal active again.
          print(
              '🔄 REFRESH: Starting/Resuming session for "${activeGoalFromDb.title}" from DB (was running: $_isRunning, current local goal ID: ${_activeGoal?.id})');

          _activeGoal = activeGoalFromDb; // Essential: Use the goal from DB
          _baselineTimeSpent = activeGoalFromDb.timeSpentSeconds; // Crucial for accurate timing

          if (activeGoalFromDb.sessionResumedTimestampSeconds != null &&
              activeGoalFromDb.sessionResumedTimestampSeconds! > 0) {
            _sessionStartTime = activeGoalFromDb.sessionResumedTimestampSeconds!;
            print(
                '🔄 REFRESH: Session start time set from resumedTimestamp: ${formatTime(_sessionStartTime)}');
            // Clear the timestamp in the database as it has been consumed
            final goalUpdate = activeGoalFromDb.copyWith(
                sessionResumedTimestampSeconds: null,
                clearSessionResumedTimestamp:
                    true); // Assumes clearSessionResumedTimestamp clears it
            await _db.updateGoal(goalUpdate);
            _activeGoal = goalUpdate; // Keep our local _activeGoal in sync
          } else {
            _sessionStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            print('🔄 REFRESH: Session start time set to NOW: ${formatTime(_sessionStartTime)}');
          }

          _goalStartTime = _sessionStartTime; // Reset goal start for this new session segment
          _isRunning = true;

          // Clear any old completion notifications as we are starting/resuming a session
          await _clearOldNotifications();

          // Schedule/Re-schedule background alarm for this new session.
          // This is vital if app was terminated or if "Continue" action started a new session.
          final sessionDuration = _getSessionDuration(); // Uses _activeGoal set above

          if (_activeGoal!.id != null && sessionDuration > 0) {
            // FIX: Calculate remaining time for the current session segment
            final sessionElapsed =
                (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStartTime;
            final remainingSessionDuration =
                (sessionDuration - sessionElapsed).clamp(0, sessionDuration);

            // FIX: Calculate goal remaining time based on current progress, not just baseline
            final currentTotalTime = _baselineTimeSpent + sessionElapsed;
            final goalRemainingTime = _activeGoal!.totalSeconds - currentTotalTime;

            final willCompleteEarly =
                goalRemainingTime > 0 && goalRemainingTime < remainingSessionDuration;

            print(
                '🔄 REFRESH: Scheduling alarm. Session rem: ${formatTime(remainingSessionDuration)}, Goal rem: ${formatTime(goalRemainingTime)}');

            if (willCompleteEarly) {
              print(
                  '⚠️ REFRESH SMART SCHEDULING: Goal "${_activeGoal?.title}" will complete early!');
              final goalCompleteTime = DateTime.now().add(Duration(seconds: goalRemainingTime));
              try {
                await AndroidAlarmManager.oneShotAt(
                    goalCompleteTime, _activeGoal!.id!, sessionCompleteCallback,
                    alarmClock: true, wakeup: true, rescheduleOnReboot: false);
                print('✅ REFRESH: Goal completion alarm (early) scheduled for ${goalCompleteTime}');
              } catch (e) {
                print('❌ REFRESH: FAILED to schedule early goal completion alarm: $e');
              }
            } else if (goalRemainingTime > 0) {
              // Only schedule if goal is not already complete
              final alarmTime = DateTime.now().add(Duration(seconds: remainingSessionDuration));
              try {
                await AndroidAlarmManager.oneShotAt(
                    alarmTime, _activeGoal!.id!, sessionCompleteCallback,
                    alarmClock: true, wakeup: true, rescheduleOnReboot: false);
                print('✅ REFRESH: Session alarm scheduled for ${alarmTime}');
              } catch (e) {
                print('❌ REFRESH: FAILED to schedule session alarm: $e');
              }
            } else {
              print(
                  'ℹ️ REFRESH: Goal "${_activeGoal?.title}" already complete or invalid remaining time. No alarm scheduled.');
            }
          } else {
            print(
                'ℹ️ REFRESH: Not scheduling alarm (Goal ID: ${_activeGoal!.id}, Session Duration: $sessionDuration)');
          }

          _startUpdateTimer(); // Start UI updates
          await _showRunningNotification(); // Show running state
          notifyListeners();
        } else if (_isRunning && _activeGoal?.id == activeGoalFromDb.id) {
          // Case 2: Timer *was* running locally for the *same* goal.
          // The goal in DB is active. Sync our local _activeGoal instance for any other data changes.
          // The timer, baseline, and alarm should theoretically be in a correct state already.
          print(
              '🔄 REFRESH: Active goal "${activeGoalFromDb.title}" already running locally. Syncing data.');
          _activeGoal = activeGoalFromDb; // Sync any minor data changes (e.g. title if editable)

          // Ensure UI timer is running, especially if app was backgrounded and it stopped.
          _startUpdateTimer();
          notifyListeners(); // Update UI if any goal data changed
        }
      }
    } catch (e) {
      print('❌ REFRESH ERROR: Failed to refresh state from database: $e');
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
