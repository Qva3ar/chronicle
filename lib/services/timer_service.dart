import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../db_manager.dart';
import '../models/goal.model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../record.service.dart';
import '../main.dart';
import '../screens/goals_screen.dart';

const String CONTINUE_ACTION_ID = 'CONTINUE_SESSION_ACTION';

// Top-level callback function for alarm manager - must be outside of any class
@pragma('vm:entry-point')
Future<void> sessionCompleteCallback(int alarmId) async {
  // Ensure Flutter bindings are initialized for background isolates.
  WidgetsFlutterBinding.ensureInitialized();

  final completionTime = DateTime.now();
  print('🔔 BACKGROUND CALLBACK: Session completion alarm fired for goal ID: $alarmId at $completionTime');
  
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

    // 🎯 ENHANCED: Get the goal with better error handling
    final goalAtAlarmTime = await db.getGoal(alarmId);
    if (goalAtAlarmTime == null) {
      print('❌ BACKGROUND: Goal not found with ID: $alarmId - may have been deleted');
      return;
    }

    // 🎯 ENHANCED: More comprehensive completion check
    if (goalAtAlarmTime.completedAt != null) {
      print('ℹ️ BACKGROUND: Goal "${goalAtAlarmTime.title}" already completed at ${DateTime.fromMillisecondsSinceEpoch(goalAtAlarmTime.completedAt!)}. Skipping.');
      return;
    }
    
    // Check if goal is already inactive (might have been stopped by user)
    if (!goalAtAlarmTime.isActive) {
      print('ℹ️ BACKGROUND: Goal "${goalAtAlarmTime.title}" is no longer active. User may have stopped it.');
      return;
    }

    print('📊 BACKGROUND: Processing session completion for: "${goalAtAlarmTime.title}"');
    print('   - Current time spent: ${_formatTimeStatic(goalAtAlarmTime.timeSpentSeconds)}/${_formatTimeStatic(goalAtAlarmTime.totalSeconds)}');
    print('   - Session resumed timestamp: ${goalAtAlarmTime.sessionResumedTimestampSeconds}');

    // 🎯 FIX: For resumed sessions, timeSpentSeconds is the baseline (preserved by foreground)
    // For normal sessions, timeSpentSeconds is also the baseline
    // This works because foreground no longer updates timeSpentSeconds during resumed sessions
    final int sessionDurationForThisAlarm = _getStaticSessionDurationForGoal(goalAtAlarmTime);
    final int baselineBeforeThisSession = goalAtAlarmTime.timeSpentSeconds;

    if (goalAtAlarmTime.sessionResumedTimestampSeconds != null && goalAtAlarmTime.sessionResumedTimestampSeconds! > 0) {
      print('   - ✅ RESUMED SESSION: Using timeSpentSeconds as baseline (preserved from Continue action)');
      print('   - Baseline: ${_formatTimeStatic(baselineBeforeThisSession)}');
    } else {
      print('   - Normal background session continuation');
      print('   - Baseline: ${_formatTimeStatic(baselineBeforeThisSession)}');
    }

    print('   - Session duration: ${_formatTimeStatic(sessionDurationForThisAlarm)}');

    // 🎯 ENHANCED: Calculate new time from baseline to avoid double-counting
    final newTimeSpentAfterThisSession = baselineBeforeThisSession + sessionDurationForThisAlarm;
    final isGoalNowActuallyComplete = newTimeSpentAfterThisSession >= goalAtAlarmTime.totalSeconds;

    print('   - Time after session: ${_formatTimeStatic(newTimeSpentAfterThisSession)}');
    print('   - Will complete goal: $isGoalNowActuallyComplete');

    if (isGoalNowActuallyComplete) {
      print('🎉 BACKGROUND: This session completes the goal!');

      // Use exact completion time, not more than the goal requires
      final exactCompletionTime = goalAtAlarmTime.totalSeconds;
      final actualSessionTimeUsed = exactCompletionTime - goalAtAlarmTime.timeSpentSeconds;

      final updatedGoal = goalAtAlarmTime.copyWith(
        timeSpentSeconds: exactCompletionTime, // Complete exactly to goal's total
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
        completedAt: completionTime.millisecondsSinceEpoch, // Use precise completion time
      );

      await db.updateGoal(updatedGoal);
      print('✅ BACKGROUND: Goal completed exactly at: ${_formatTimeStatic(exactCompletionTime)}');
      print('   - Actual session time used: ${_formatTimeStatic(actualSessionTimeUsed)}');

      // Create a record for the completed goal
      final record = {
        DatabaseColumns.recordTitle: 'Goal Completed: ${updatedGoal.title}',
        DatabaseColumns.recordText: 'Goal completed after ${_formatTimeStatic(exactCompletionTime)} of focused work!',
        DatabaseColumns.recordCreatedAt: completionTime.millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'goal',
        DatabaseColumns.recordGoalId: updatedGoal.id,
      };
      await recordService.createRecord(record, []);
      print('📝 BACKGROUND: Record created for completed goal.');

      // Cancel the running notification before showing completion notifications
      await notificationsPlugin.cancel(1);
      print('🚫 BACKGROUND: Cancelled running notification (ID: 1)');

      // Show goal completion notifications
      await _showBackgroundGoalCompleteNotification(notificationsPlugin, updatedGoal);
      await _showBackgroundCompletionNotification(
          notificationsPlugin, updatedGoal, actualSessionTimeUsed);
    } else {
      print('📝 BACKGROUND: Session completed, goal continues.');
      final updatedGoal = goalAtAlarmTime.copyWith(
        timeSpentSeconds: newTimeSpentAfterThisSession,
        isActive: false, // Mark as inactive after session
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
      );
      await db.updateGoal(updatedGoal);
      print('✅ BACKGROUND: Goal updated. Progress: ${_formatTimeStatic(updatedGoal.timeSpentSeconds)}/${_formatTimeStatic(updatedGoal.totalSeconds)}');

      // Cancel the running notification before showing completion notification
      await notificationsPlugin.cancel(1);
      print('🚫 BACKGROUND: Cancelled running notification (ID: 1)');

      // Show session completion notification
      await _showBackgroundCompletionNotification(
          notificationsPlugin, updatedGoal, sessionDurationForThisAlarm);
    }
    
    print('✅ BACKGROUND CALLBACK: Completed successfully for goal "${goalAtAlarmTime.title}"');
  } catch (e, stackTrace) {
    print('❌ BACKGROUND ERROR: $e');
    print('❌ BACKGROUND STACK: $stackTrace');
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
// NEW: Show a running notification from background context with unified design
Future<void> _showBackgroundRunningNotification(
    FlutterLocalNotificationsPlugin plugin, Goal goal) async {
  try {
    print('💡 BG NOTIF: Attempting to show unified running notification for ${goal.title}');

    // Calculate session progress for the progress bar
    // When continued from background, we need to calculate session elapsed time
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int sessionStartTime = goal.sessionResumedTimestampSeconds ?? currentTime;
    final int sessionElapsed = (currentTime - sessionStartTime).clamp(0, 86400);
    final int sessionDuration = _getStaticSessionDurationForGoal(goal);

    // Calculate progress percentage (0-100) for the current session segment
    final int progressPercentage = sessionDuration > 0
        ? ((sessionElapsed / sessionDuration) * 100).round().clamp(0, 100)
        : 0;

    // Use unified notification format with progress bar
    // HIGH PRIORITY: Make it noticeable when user resumes session
    final androidDetails = AndroidNotificationDetails(
      'timer_channel', // Same channel as the foreground running notification
      'Timer Notifications',
      channelDescription: 'Notifications for goal timer sessions',
      importance: Importance.high, // Changed from defaultImportance to high
      priority: Priority.high, // Changed from defaultPriority to high
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      // Add vibration pattern for visibility
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]), // Vibrate-pause-vibrate pattern
      // Add sound for initial notification
      playSound: true,
      // Unified progress bar
      showProgress: true,
      maxProgress: 100,
      progress: progressPercentage,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, // Changed from false to show alert
      presentBadge: true,
      presentSound: true, // Changed from false to play sound
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Unified format: clean title and elapsed time
    final notificationTitle = '🎯 ${goal.title}';
    final notificationBody = '⏱️ ${_formatTimeStatic(goal.timeSpentSeconds)} elapsed';

    await plugin.show(
      1, // Use the same ID as the main running notification
      notificationTitle,
      notificationBody,
      details,
      payload: 'running_goal_${goal.id}',
    );

    print('✅ BACKGROUND: Unified running notification shown for ${goal.title} (progress: $progressPercentage%)');
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

      final alarmTime = DateTime.now().add(Duration(seconds: timeUntilCompletion));
      print('⏰ BACKGROUND ACTION: Scheduling alarm for: ${alarmTime.toString()} (${willCompleteEarly ? "goal completion" : "session end"})');

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
      print('⚠️ TIMING WARNING: Current time ($currentTime) is before session start ($_sessionStartTime)');
      return 0;
    }
    
    final elapsed = currentTime - _sessionStartTime;
    
    // Validate elapsed time is reasonable (not negative or extremely large)
    if (elapsed < 0) {
      print('⚠️ TIMING ERROR: Negative elapsed time: $elapsed');
      return 0;
    }
    
    if (elapsed > 86400) { // More than 24 hours
      print('⚠️ TIMING WARNING: Extremely long session: ${formatTime(elapsed)}');
    }

    // Debug logging every 30 seconds with more context
    if (elapsed % 30 == 0 && elapsed > 0) {
      print('🕐 TIMING DEBUG: Goal "${_activeGoal?.title}" - Start: $_sessionStartTime, Current: $currentTime, Elapsed: ${formatTime(elapsed)}');
    }

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
      print('⚠️ TOTAL TIME: Clamped from ${formatTime(total)} to ${formatTime(clampedTotal)} (goal target)');
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
    
    // Special handling for test goals
    if (_activeGoal!.title.contains('Test Goal')) {
      return 10; // 10 seconds for testing
    }
    
    // Validate session duration is reasonable
    final sessionMinutes = _activeGoal!.sessionMinutes;
    if (sessionMinutes <= 0) {
      print('⚠️ SESSION DURATION: Invalid session minutes: $sessionMinutes, using default 25');
      return 25 * 60; // Default to 25 minutes
    }
    
    if (sessionMinutes > 240) { // More than 4 hours
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
      
      // Check for any orphaned alarms from previous app runs
      await _cleanupOrphanedAlarms();
      
      // Restore any active sessions that were running when app was terminated
      await _restoreActiveSession();
      
      // Refresh state from database for any remaining active goals
      await _refreshStateFromDatabase();
      
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
        if (!goal.isActive || goal.completedAt != null || goal.timeSpentSeconds >= goal.totalSeconds) {
          try {
            await AndroidAlarmManager.cancel(goal.id!);
            print('🧩 CLEANUP: Cancelled orphaned alarm for "${goal.title}" (active: ${goal.isActive}, completed: ${goal.completedAt != null})');
          } catch (e) {
            // It's okay if the alarm doesn't exist
          }
        }
      }
      
      print('✅ CLEANUP: Orphaned alarm cleanup completed');
    } catch (e) {
      print('❌ CLEANUP: Failed to cleanup orphaned alarms: $e');
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
      print('   - Time spent: ${formatTime(activeGoal.timeSpentSeconds)}/${formatTime(activeGoal.totalSeconds)}');
      print('   - Completed at: ${activeGoal.completedAt}');
      print('   - Resume timestamp: ${activeGoal.sessionResumedTimestampSeconds}');
      
      // Check if goal was completed while app was closed
      if (activeGoal.completedAt != null || activeGoal.timeSpentSeconds >= activeGoal.totalSeconds) {
        print('🎉 RESTORE: Goal was completed while app was closed');
        
        // Mark as inactive and clean up
        final cleanedGoal = activeGoal.copyWith(
          isActive: false,
          sessionResumedTimestampSeconds: null,
          clearSessionResumedTimestamp: true,
        );
        await _db.updateGoal(cleanedGoal);
        
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
    
    if (sessionElapsed > 86400) { // More than 24 hours
      print('⚠️ RECOVER: Session was interrupted more than 24 hours ago, cannot recover reliably');
      await _cleanupGoalState(activeGoal);
      return;
    }
    
    // Calculate session duration that was originally planned
    final sessionDuration = _getStaticSessionDurationForGoal(activeGoal);
    
    if (sessionElapsed >= sessionDuration) {
      // Session should have completed while app was closed
      print('🎉 RECOVER: Session completed while app was closed (${formatTime(sessionElapsed)} >= ${formatTime(sessionDuration)})');
      await _completeInterruptedSession(activeGoal, sessionDuration);
    } else {
      // Session was still running when app was closed
      print('🔄 RECOVER: Session was still running when app closed (${formatTime(sessionElapsed)} < ${formatTime(sessionDuration)})');
      
      // Save the elapsed time and mark as inactive
      final newTimeSpent = activeGoal.timeSpentSeconds + sessionElapsed;
      final goalTarget = activeGoal.totalSeconds;
      final clampedTimeSpent = newTimeSpent > goalTarget ? goalTarget : newTimeSpent;
      
      final updatedGoal = activeGoal.copyWith(
        timeSpentSeconds: clampedTimeSpent,
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
        completedAt: clampedTimeSpent >= goalTarget ? DateTime.now().millisecondsSinceEpoch : null,
      );
      
      await _db.updateGoal(updatedGoal);
      print('✅ RECOVER: Partial session time saved: ${formatTime(sessionElapsed)}, total now: ${formatTime(clampedTimeSpent)}');
      
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
      
      // Create completion record
      final record = {
        DatabaseColumns.recordTitle: 'Goal Completed: ${updatedGoal.title}',
        DatabaseColumns.recordText: 'Goal completed while app was in background after ${formatTime(finalTimeSpent)} of focused work!',
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'goal',
        DatabaseColumns.recordGoalId: updatedGoal.id,
      };
      
      final recordService = RecordService();
      await recordService.createRecord(record, []);
      
      await _showGoalCompleteNotification();
      print('✅ RECOVER COMPLETE: Goal completion processed');
    } else {
      print('✅ RECOVER COMPLETE: Session completed, goal continues with ${formatTime(finalTimeSpent)} total');
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
    print('🧩 CLEANUP: Cleaned up unrecoverable goal state for "${goal.title}"');
  }

  Future<void> _initializeAlarmManager() async {
    try {
      await AndroidAlarmManager.initialize();
      print('✅ Alarm Manager initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Alarm Manager: $e');
    }
  }

  // 🎯 ENHANCED: Start session with improved precision and validation
  Future<void> startSession(Goal goal) async {
    print('🚀 START SESSION: Initiating session for "${goal.title}"');
    
    // Get the latest state and validate
    final latestGoal = await _db.getGoal(goal.id!);
    if (latestGoal == null) {
      print('❌ START SESSION: Goal with ID ${goal.id} not found in DB.');
      return;
    }
    
    // Validate goal is not already completed
    if (latestGoal.completedAt != null || latestGoal.timeSpentSeconds >= latestGoal.totalSeconds) {
      print('⚠️ START SESSION: Goal "${latestGoal.title}" is already completed');
      return;
    }

    // Stop current session if any
    await stopSession();
    await _clearOldNotifications();

    // 🎯 ENHANCED: Initialize session with precise timing
    _activeGoal = latestGoal;
    final preciseStartTime = DateTime.now();
    _sessionStartTime = preciseStartTime.millisecondsSinceEpoch ~/ 1000;
    _baselineTimeSpent = latestGoal.timeSpentSeconds;
    _isRunning = true;
    
    print('🚀 START SESSION: Session initialized');
    print('   - Start time: ${preciseStartTime.toIso8601String()}');
    print('   - Baseline: ${formatTime(_baselineTimeSpent)}');
    print('   - Goal target: ${formatTime(latestGoal.totalSeconds)}');
    print('   - Remaining: ${formatTime(latestGoal.totalSeconds - latestGoal.timeSpentSeconds)}');

    // Update goal as active in database
    final updatedGoal = latestGoal.copyWith(
      isActive: true,
      sessionResumedTimestampSeconds: null,
      clearSessionResumedTimestamp: true,
    );
    await _db.updateGoal(updatedGoal);
    _activeGoal = updatedGoal;

    // 🎯 ENHANCED: Smart scheduling with precision
    await _scheduleSessionAlarm();
    
    // Start UI update timer and show notification
    _startUpdateTimer();
    await _showRunningNotification();
    notifyListeners();
    
    print('✅ START SESSION: Session started successfully for "${latestGoal.title}"');
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

    // Cancel the background alarm
    if (goalId != null) {
      try {
        await AndroidAlarmManager.cancel(goalId);
        print('🚫 STOP SESSION: Background alarm cancelled for goal ID: $goalId');
      } catch (e) {
        print('❌ STOP SESSION: Failed to cancel background alarm: $e');
      }
    }

    // 🎯 ENHANCED: Save progress with validation and precision
    if (_sessionStartTime > 0 && currentSessionTime >= 0) {
      // Validate session time is reasonable
      final validSessionTime = currentSessionTime.clamp(0, 86400); // Max 24 hours
      if (validSessionTime != currentSessionTime) {
        print('⚠️ STOP SESSION: Clamped session time from ${formatTime(currentSessionTime)} to ${formatTime(validSessionTime)}');
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

      final updatedGoal = _activeGoal!.copyWith(
        timeSpentSeconds: clampedTotal,
        isActive: false,
        sessionResumedTimestampSeconds: null,
        clearSessionResumedTimestamp: true,
      );

      await _db.updateGoal(updatedGoal);
      _activeGoal = updatedGoal;

      print('✅ STOP SESSION: Progress saved - ${formatTime(validSessionTime)} session, ${formatTime(clampedTotal)} total');
      
      // Check if this stop completed the goal
      if (clampedTotal >= goalTarget) {
        print('🎉 STOP SESSION: Goal completed by manual stop!');
        // Note: Could trigger completion notification here if desired
      }
    } else {
      print('💾 STOP SESSION: No time to save (start: $_sessionStartTime, elapsed: $currentSessionTime)');
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
    notifyListeners();
    
    print('✅ STOP SESSION: Session stopped for "$goalTitle" - All progress preserved');
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();

    // This timer is now ONLY for UI updates, background completion is handled by alarm
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final sessionElapsed = sessionTimeElapsed;
      final sessionDuration = _getSessionDuration();

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

        // 🎯 ENHANCED: Detect if time spent was updated by background
        if (currentGoalInDb.timeSpentSeconds != _activeGoal!.timeSpentSeconds) {
          final oldTime = _activeGoal!.timeSpentSeconds;
          final newTime = currentGoalInDb.timeSpentSeconds;
          print('🔄 TIMER SYNC: Goal time updated by background: ${formatTime(oldTime)} -> ${formatTime(newTime)}');
          
          // Update our local state but recalculate baseline to maintain consistency
          _activeGoal = currentGoalInDb;
          _baselineTimeSpent = newTime; // Adjust baseline since background updated progress
          
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
      }

      // Just update UI and notifications - alarm handles the actual completion
      if (sessionElapsed % 10 == 0) { // Reduce log frequency
        print('UI Update: Session time: ${formatTime(sessionElapsed)}/${formatTime(sessionDuration)}');
      }

      // Update notifications periodically (every 30 seconds instead of 60)
      if (sessionElapsed % 30 == 0 && sessionElapsed > 0) {
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
      DatabaseColumns.recordText: 'Goal is completed: ${completedGoal.title}',
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

  // 🎯 ENHANCED: Handle when background callback has completed the session with better synchronization
  Future<void> _handleBackgroundCompletion() async {
    print('🎉 BG COMPLETION UI: Detected background completion via UI timer.');

    // Cancel the background alarm since we're handling completion now
    if (_activeGoal?.id != null) {
      try {
        await AndroidAlarmManager.cancel(_activeGoal!.id!);
        print('🚫 BG COMPLETION: Cancelled remaining alarm for goal ${_activeGoal!.id}');
      } catch (e) {
        print('❌ BG COMPLETION: Failed to cancel alarm: $e');
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
        print('   - Time spent: ${formatTime(_activeGoal!.timeSpentSeconds)}/${formatTime(_activeGoal!.totalSeconds)}');
        print('   - Active: ${_activeGoal!.isActive}');
        print('   - Completed at: ${_activeGoal!.completedAt}');
        
        // Trigger immediate notification if goal was completed
        if (_activeGoal!.completedAt != null && _activeGoal!.timeSpentSeconds >= _activeGoal!.totalSeconds) {
          print('🎉 BG COMPLETION: Goal was completed by background! Showing notification...');
          // Note: Background already showed notifications, but ensure UI reflects completion
        }
      } else {
        print('⚠️ BG COMPLETION UI: Goal $currentActiveGoalId not found in DB. Goal may have been deleted.');
        _activeGoal = null;
      }
    } else {
      print('ℹ️ BG COMPLETION UI: No active goal ID to refresh.');
      _activeGoal = null;
    }

    // Clear session-specific running state variables
    _sessionStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print('✅ BG COMPLETION UI: State synchronized. Previous session for "$previousTitle" handled by background.');
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

      if (currentSessionTime > 86400) { // More than 24 hours
        print('⚠️ SAVE PROGRESS: Extremely long session time: ${formatTime(currentSessionTime)} - capping at 24 hours');
        // Cap at reasonable maximum
        final cappedSessionTime = 86400;
        final totalTimeSpent = _baselineTimeSpent + cappedSessionTime;
        final updatedGoal = _activeGoal!.copyWith(
          timeSpentSeconds: totalTimeSpent,
          sessionResumedTimestampSeconds: _isRunning && _sessionStartTime > 0 ? _sessionStartTime : null,
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
        print('⚠️ SAVE PROGRESS: Clamped total time from ${formatTime(totalTimeSpent)} to ${formatTime(clampedTotal)}');
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

        print('💾 SAVE PROGRESS (RESUMED SESSION): Local total: ${formatTime(clampedTotal)}, DB baseline preserved: ${formatTime(_baselineTimeSpent)}');
        print('   - Database timeSpentSeconds NOT updated (alarm will update when session completes)');
      } else {
        // Normal save for non-resumed sessions
        final updatedGoal = _activeGoal!.copyWith(
          timeSpentSeconds: clampedTotal,
          sessionResumedTimestampSeconds: _isRunning && _sessionStartTime > 0 ? _sessionStartTime : null,
        );
        await _db.updateGoal(updatedGoal);
        _activeGoal = updatedGoal;

        print('💾 SAVE PROGRESS: Session time: ${formatTime(currentSessionTime)}, Total: ${formatTime(clampedTotal)}, Baseline: ${formatTime(_baselineTimeSpent)}');
        if (_isRunning && _sessionStartTime > 0) {
          print('   - Preserved sessionResumedTimestampSeconds: $_sessionStartTime for background coordination');
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

  /// Creates unified notification details with progress bar for active goal sessions
  /// Returns [NotificationDetails] with consistent formatting and visual progress indicator
  NotificationDetails _createUnifiedNotificationDetails({
    required int sessionElapsedSeconds,
    required int sessionDurationSeconds,
    required int totalElapsedSeconds,
  }) {
    // Calculate session progress percentage (0-100)
    final int progressPercentage = sessionDurationSeconds > 0
        ? ((sessionElapsedSeconds / sessionDurationSeconds) * 100).round().clamp(0, 100)
        : 0;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Timer Notifications',
      channelDescription: 'Notifications for goal timer sessions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      // Progress bar configuration
      showProgress: true,
      maxProgress: 100,
      progress: progressPercentage,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Future<void> _showRunningNotification() async {
    if (_activeGoal == null) {
      print('❌ Cannot show running notification - no active goal');
      return;
    }

    print('🔔 NOTIFICATION: Updating running notification');
    print('   - Goal: ${_activeGoal!.title}');
    print(
        '   - Session time: ${formatTime(sessionTimeElapsed)}/${formatTime(_getSessionDuration())}');
    print('   - Total elapsed: ${formatTime(totalTimeElapsed)}');

    try {
      final notificationTitle = '🎯 ${_activeGoal!.title}';
      final notificationBody = '⏱️ ${formatTime(totalTimeElapsed)} elapsed';

      final platformChannelSpecifics = _createUnifiedNotificationDetails(
        sessionElapsedSeconds: sessionTimeElapsed,
        sessionDurationSeconds: _getSessionDuration(),
        totalElapsedSeconds: totalTimeElapsed,
      );

      await _notificationsPlugin.show(
        1,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );

      print('✅ NOTIFICATION: Running notification updated successfully (${sessionTimeElapsed}/${_getSessionDuration()}s - ${((sessionTimeElapsed / _getSessionDuration()) * 100).round()}%)');
    } catch (e) {
      print('❌ NOTIFICATION ERROR: Failed to show running notification: $e');
    }
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
          // Channel for ongoing timer notifications
          const timerChannel = AndroidNotificationChannel(
            'timer_channel',
            'Timer Notifications',
            description: 'Notifications for goal timer sessions',
            importance: Importance.defaultImportance,
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
        print('   - Goal progress: ${formatTime(activeGoalFromDb.timeSpentSeconds)}/${formatTime(activeGoalFromDb.totalSeconds)}');
        print('   - Is active: ${activeGoalFromDb.isActive}');
        print('   - Completed at: ${activeGoalFromDb.completedAt}');
        print('   - Resume timestamp: ${activeGoalFromDb.sessionResumedTimestampSeconds}');
        
        // Check if goal is actually complete
        if (activeGoalFromDb.completedAt != null || activeGoalFromDb.timeSpentSeconds >= activeGoalFromDb.totalSeconds) {
          print('🎉 REFRESH: Goal is already completed, cleaning up');
          await _cleanupSession('Goal already completed');
          return;
        }

        // An active goal exists in the database
        if (!_isRunning || _activeGoal?.id != activeGoalFromDb.id) {
          print('🔄 REFRESH: Starting/Resuming session (was running: $_isRunning, current goal: ${_activeGoal?.id})');
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
    
    // Cancel any pending alarms
    if (_activeGoal?.id != null) {
      try {
        await AndroidAlarmManager.cancel(_activeGoal!.id!);
      } catch (e) {
        print('⚠️ CLEANUP: Failed to cancel alarm: $e');
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
    if (activeGoal.sessionResumedTimestampSeconds != null && activeGoal.sessionResumedTimestampSeconds! > 0) {
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
    _activeGoal = activeGoal;
    
    // If time spent changed externally, adjust baseline
    if (activeGoal.timeSpentSeconds != oldTimeSpent) {
      print('🔄 SYNC: Time spent changed externally: ${formatTime(oldTimeSpent)} -> ${formatTime(activeGoal.timeSpentSeconds)}');
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
    final goalRemainingTime = (_activeGoal!.totalSeconds - currentTotalTime).clamp(0, _activeGoal!.totalSeconds);
    
    print('🔄 SCHEDULE: Session remaining: ${formatTime(remainingSessionDuration)}, Goal remaining: ${formatTime(goalRemainingTime)}');
    
    // Smart scheduling: complete when goal is done or session ends
    final willCompleteEarly = goalRemainingTime > 0 && goalRemainingTime < remainingSessionDuration;
    final timeUntilCompletion = willCompleteEarly ? goalRemainingTime : remainingSessionDuration;
    
    if (timeUntilCompletion <= 0) {
      print('ℹ️ SCHEDULE: Nothing to schedule (time: $timeUntilCompletion)');
      return;
    }
    
    final alarmTime = DateTime.now().add(Duration(seconds: timeUntilCompletion));
    print('⏰ SCHEDULE: Alarm for ${alarmTime} (${willCompleteEarly ? "goal completion" : "session end"})');
    
    try {
      await AndroidAlarmManager.oneShotAt(
        alarmTime,
        _activeGoal!.id!,
        sessionCompleteCallback,
        alarmClock: true,
        wakeup: true,
        rescheduleOnReboot: false,
      );
      print('✅ SCHEDULE: Alarm scheduled successfully');
    } catch (e) {
      print('❌ SCHEDULE: Failed to schedule alarm: $e');
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
