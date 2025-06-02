import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/goal.model.dart';
import 'database_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// Top-level callback function for alarm manager - must be outside of any class
@pragma('vm:entry-point')
Future<void> sessionCompleteCallback(int alarmId) async {
  print('🔔 BACKGROUND CALLBACK: Session completion alarm fired for goal ID: $alarmId');
  try {
    // Initialize services in background context
    final db = DatabaseHelper.instance;
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
    final goal = await db.getGoal(alarmId);
    if (goal == null) {
      print('❌ BACKGROUND: Goal not found with ID: $alarmId');
      return;
    }

    print('📊 BACKGROUND: Processing session completion for: ${goal.title}');

    // Calculate session duration for notification display
    final sessionDuration = goal.title.contains('Test Goal') ? 10 : (goal.sessionMinutes * 60);

    // 🎯 NEW: Check if this is goal completion vs session completion
    final goalRemainingTime = goal.totalSeconds - goal.timeSpentSeconds;
    final isGoalCompletion = goalRemainingTime <= sessionDuration;

    if (isGoalCompletion) {
      print('🎉 BACKGROUND: This is GOAL COMPLETION, not just session completion');

      // Complete the goal exactly
      final updatedGoal = goal.copyWith(
        timeSpentSeconds: goal.totalSeconds, // Set to exact goal completion
        isActive: false,
      );
      await db.updateGoal(updatedGoal);

      print('✅ BACKGROUND: Goal completed exactly at ${_formatTimeStatic(goal.totalSeconds)}');

      // Show goal completion notifications
      await _showBackgroundGoalCompleteNotification(notificationsPlugin, updatedGoal);
      await _showBackgroundCompletionNotification(
          notificationsPlugin, updatedGoal, goalRemainingTime);
    } else {
      print('📝 BACKGROUND: This is session completion, goal continues');

      // IMPORTANT: Only mark as inactive, don't add time (UI timer already saved final time)
      final updatedGoal = goal.copyWith(isActive: false);
      await db.updateGoal(updatedGoal);
      print('✅ BACKGROUND: Goal marked as inactive (time already saved by UI timer)');

      // Show completion notification
      await _showBackgroundCompletionNotification(
          notificationsPlugin, updatedGoal, sessionDuration);

      // Check if goal is complete after this session
      final remaining = updatedGoal.totalSeconds - updatedGoal.timeSpentSeconds;
      if (remaining <= 0) {
        await _showBackgroundGoalCompleteNotification(notificationsPlugin, updatedGoal);
      }
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
Future<void> _showBackgroundCompletionNotification(
    FlutterLocalNotificationsPlugin plugin, Goal goal, int sessionDuration) async {
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
    // Stop current session if any
    await stopSession();

    // Clear any old completion notifications to prevent confusion
    await _clearOldNotifications();

    _activeGoal = goal;
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Store in seconds
    _sessionStartTime = currentTime;
    _goalStartTime = currentTime;
    _baselineTimeSpent = goal.timeSpentSeconds; // Capture baseline to avoid double counting
    _isRunning = true;

    // Update goal as active in database
    final updatedGoal = goal.copyWith(isActive: true);
    await _db.updateGoal(updatedGoal);
    _activeGoal = updatedGoal;

    // Schedule background alarm for session completion
    final sessionDuration = _getSessionDuration();
    final alarmTime = DateTime.now().add(Duration(seconds: sessionDuration));

    // 🎯 NEW: Check if goal will be completed before session ends
    final goalRemainingTime = goal.totalSeconds - goal.timeSpentSeconds;
    final willCompleteEarly = goalRemainingTime < sessionDuration;

    if (willCompleteEarly) {
      print('⚠️ SMART SCHEDULING: Goal will complete early!');
      print('   Goal remaining: ${formatTime(goalRemainingTime)}');
      print('   Session duration: ${formatTime(sessionDuration)}');
      print('   Scheduling alarm for goal completion instead of full session');

      // Schedule alarm for when goal will be completed, not full session
      final goalCompleteTime = DateTime.now().add(Duration(seconds: goalRemainingTime));

      print('⏰ Scheduling GOAL COMPLETION alarm for: ${goalCompleteTime.toString()}');
      print('⏰ Goal ID: ${goal.id}, will complete in: ${formatTime(goalRemainingTime)}');

      try {
        await AndroidAlarmManager.oneShotAt(
          goalCompleteTime,
          goal.id!, // Use goal ID as alarm ID
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
      print('⏰ Goal ID: ${goal.id}, Alarm ID will be: ${goal.id}');

      try {
        await AndroidAlarmManager.oneShotAt(
          alarmTime,
          goal.id!, // Use goal ID as alarm ID
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
    print('Session started for: ${goal.title} at timestamp: $currentTime');
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
      );

      await _db.updateGoal(updatedGoal);
      _activeGoal = updatedGoal;

      print('✅ Partial session time saved: ${formatTime(currentSessionTime)}');
      print('✅ Total time is now: ${formatTime(totalTimeSpent)}');
    } else {
      // Just mark as inactive if no time elapsed
      final updatedGoal = _activeGoal!.copyWith(isActive: false);
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
    );

    await _db.updateGoal(completedGoal);

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
    print('🎉 Background session completion detected');

    // IMPORTANT: Save final session time before stopping
    if (_activeGoal != null && _sessionStartTime > 0) {
      final finalSessionTime = sessionTimeElapsed;
      final totalTimeSpent = _baselineTimeSpent + finalSessionTime;

      final updatedGoal = _activeGoal!.copyWith(timeSpentSeconds: totalTimeSpent);
      await _db.updateGoal(updatedGoal);

      print('✅ Final session time saved: ${formatTime(finalSessionTime)}');
      print('✅ Total time now: ${formatTime(totalTimeSpent)}');
    }

    _isRunning = false;
    _updateTimer?.cancel();

    // Hide the running notification
    await _hideNotification();

    // Refresh our state from database
    if (_activeGoal?.id != null) {
      final updatedGoal = await _db.getGoal(_activeGoal!.id!);
      if (updatedGoal != null) {
        _activeGoal = updatedGoal;
        print('✅ Goal state refreshed: ${formatTime(updatedGoal.timeSpentSeconds)} total time');
      }
    }

    // Clear session state
    _activeGoal = null;
    _sessionStartTime = 0;
    _goalStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print('✅ UI timer stopped - session completed by background callback');
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
      final activeGoal = await _db.getActiveGoal();

      if (activeGoal == null) {
        // No active goals in database - clear our state
        if (_isRunning) {
          print('🔄 REFRESH: No active goal found in database, clearing timer state');
          _isRunning = false;
          _updateTimer?.cancel();
          await _hideNotification();
          _activeGoal = null;
          _sessionStartTime = 0;
          _goalStartTime = 0;
          _baselineTimeSpent = 0;
          notifyListeners();
        }
      } else {
        // There is an active goal - sync our state WITHOUT causing double counting
        if (_activeGoal?.id != activeGoal.id) {
          print('🔄 REFRESH: Syncing with active goal from database: ${activeGoal.title}');
          _activeGoal = activeGoal;

          // 🎯 CRITICAL: Set baseline to current database time to prevent double counting
          _baselineTimeSpent = activeGoal.timeSpentSeconds;
          print('🔄 REFRESH: Set baseline to current DB time: ${formatTime(_baselineTimeSpent)}');

          notifyListeners();
        } else if (_activeGoal != null) {
          // Same goal, but sync the database state without affecting our timer calculation
          print('🔄 REFRESH: Same goal active, keeping timer state consistent');
          print('   Database time: ${formatTime(activeGoal.timeSpentSeconds)}');
          print('   Our baseline: ${formatTime(_baselineTimeSpent)}');
          print('   Session elapsed: ${formatTime(sessionTimeElapsed)}');
          print('   Total calculated: ${formatTime(totalTimeElapsed)}');

          // Update our goal reference but keep our timing baseline
          _activeGoal = activeGoal;
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
