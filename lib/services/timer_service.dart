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

class TimerService extends ChangeNotifier {
  static final TimerService instance = TimerService._init();
  TimerService._init() {
    _initializeNotifications();
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
    return currentTime - _sessionStartTime;
  }

  // Remaining time in total goal (not just current session)
  int get goalTimeRemaining {
    if (_activeGoal == null) return 0;
    final totalGoalSeconds = _activeGoal!.totalSeconds;
    final currentTimeSpent = _activeGoal!.timeSpentSeconds + sessionTimeElapsed;
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
    await _restoreActiveSession();
  }

  Future<void> startSession(Goal goal) async {
    // Stop current session if any
    await stopSession();

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

    // Save session state for recovery
    await _saveSessionState();

    // Start UI update timer
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
    print('Manually stopping session for: $goalTitle');

    _isRunning = false;
    _updateTimer?.cancel();

    // Save any current progress before stopping
    if (_sessionStartTime > 0) {
      await _saveProgressToDatabase();
    }

    // Update goal as inactive in database
    final updatedGoal = _activeGoal!.copyWith(isActive: false);
    await _db.updateGoal(updatedGoal);

    // Hide notification
    await _hideNotification();

    // Clear session state
    await _clearSessionState();

    _activeGoal = null;
    _sessionStartTime = 0;
    _goalStartTime = 0;
    _baselineTimeSpent = 0;

    notifyListeners();
    print('Session stopped for: $goalTitle - Timer is now inactive');
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();

    // Use faster intervals for test goals
    final bool isTestGoal = _activeGoal?.title.contains('Test Goal') ?? false;
    final int updateInterval = isTestGoal ? 1000 : 1000; // 1 second for all
    final int notificationInterval = isTestGoal ? 5000 : 60000; // 5s for test, 60s for normal
    final int saveInterval = isTestGoal ? 5000 : 30000; // 5s for test, 30s for normal

    _updateTimer = Timer.periodic(Duration(milliseconds: updateInterval), (timer) async {
      final sessionElapsed =
          sessionTimeElapsed; // Use the getter which handles conversion correctly
      final sessionDuration = _getSessionDuration();

      print(
          'Timer Update: Session time: ${formatTime(sessionElapsed)}/${formatTime(sessionDuration)}');

      // Check for session completion
      if (sessionElapsed >= sessionDuration) {
        print('Session completed! Elapsed: ${sessionElapsed}s, Duration: ${sessionDuration}s');
        await _completeSession();
        return;
      }

      // Update notifications periodically
      if (sessionElapsed % (notificationInterval ~/ 1000) == 0 && sessionElapsed > 0) {
        await _showSessionNotification();
      }

      // Save progress periodically
      if (sessionElapsed % (saveInterval ~/ 1000) == 0 && sessionElapsed > 0) {
        await _saveProgressToDatabase();
      }

      notifyListeners();
    });
  }

  Future<void> _completeSession() async {
    if (_activeGoal == null) return;

    print('🎯 SESSION ENDING: Starting completion process for goal: ${_activeGoal!.title}');

    // Save any remaining progress first
    await _saveProgressToDatabase();

    // Get the updated goal data (with latest timeSpentSeconds from database)
    final updatedGoal = await _db.getGoal(_activeGoal!.id!);
    if (updatedGoal != null) {
      _activeGoal = updatedGoal;
    }

    print('📊 SESSION STATS:');
    print('   - Session duration: ${formatTime(_getSessionDuration())}');
    print('   - Current total time spent: ${formatTime(_activeGoal!.timeSpentSeconds)}');

    // DON'T add session duration again - it's already been added during periodic saves
    // Just mark the goal as inactive
    _activeGoal = _activeGoal!.copyWith(isActive: false);

    print('💾 Updating goal in database...');
    // Update goal in database
    await DatabaseHelper.instance.updateGoal(_activeGoal!);
    print('✅ Goal updated in database successfully');

    print('🔔 Showing session completion notification...');
    // Show session completion notification
    await _showSessionCompletionNotification();

    print('⏹️ Stopping timer and cleaning up...');
    // Stop the timer completely - no automatic next session
    _isRunning = false;
    _sessionStartTime = 0;
    _updateTimer?.cancel();

    // Hide running notification
    await _hideNotification();
    print('🚫 Running notification hidden');

    // Clear session state
    await _clearSessionState();
    print('🧹 Session state cleared');

    // Check if goal is complete, but don't auto-start next session
    await _checkGoalCompletion();

    notifyListeners();
    print('✅ SESSION COMPLETED: Timer stopped. User must manually start next session.');
  }

  Future<void> _showSessionCompletionNotification() async {
    if (_activeGoal == null) {
      print('❌ Cannot show session completion notification - no active goal');
      return;
    }

    print('🔔 NOTIFICATION: Preparing session completion notification');
    print('   - Goal: ${_activeGoal!.title}');
    print('   - Session duration: ${formatTime(_getSessionDuration())}');

    try {
      // Create a separate channel for completion notifications
      final androidDetails = AndroidNotificationDetails(
        'session_complete_channel', // Different channel ID
        'Session Completed',
        channelDescription: 'Notifications when a session is completed',
        importance: Importance.max, // Maximum importance
        priority: Priority.max, // Maximum priority
        ticker: 'Session completed',
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        autoCancel: true, // Auto dismiss when clicked
        styleInformation: BigTextStyleInformation(
          'Great job! You\'ve completed a ${'dfd'} minute session for ${_activeGoal!.title}. Take a break or start another session when you\'re ready!',
          contentTitle: 'Session Completed! 🎉',
          summaryText: 'Tap to continue',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default', // Use default sound
        badgeNumber: 1,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationTitle = 'Session Completed! 🎉';
      final notificationBody =
          '${_activeGoal!.title} - ${formatTime(_getSessionDuration())} session finished. Great work!';

      print('🔔 NOTIFICATION: Showing notification with:');
      print('   - Title: $notificationTitle');
      print('   - Body: $notificationBody');

      await _notificationsPlugin.show(
        2, // Different ID for completion notifications
        notificationTitle,
        notificationBody,
        details,
        payload: 'session_complete_${_activeGoal!.id}', // Add payload for handling clicks
      );

      print('✅ NOTIFICATION: Session completion notification shown successfully');
    } catch (e) {
      print('❌ NOTIFICATION ERROR: Failed to show session completion notification: $e');
      print('   - Error details: ${e.toString()}');
    }
  }

  Future<void> _checkGoalCompletion() async {
    if (_activeGoal == null) return;

    // Refresh goal data from database to get latest timeSpentSeconds
    final updatedGoal = await _db.getGoal(_activeGoal!.id!);
    if (updatedGoal != null) {
      _activeGoal = updatedGoal;

      final remaining = goalTimeRemaining;
      print('Goal remaining time after session: ${formatTime(remaining)}');

      if (remaining <= 0) {
        print('🎉 Goal is now complete!');
        await _onGoalComplete();
      } else {
        print('Goal continues - ${formatTime(remaining)} remaining');
        print('Timer stopped. User can start next session when ready.');
        // Don't auto-start next session - user must manually start it
      }
    }
  }

  Future<void> _onGoalComplete() async {
    print('🎉 Goal completed for: ${_activeGoal!.title}');

    // Save final progress
    await _saveProgressToDatabase();

    // Show goal completion notification
    await _showGoalCompleteNotification();

    // Stop the session
    await stopSession();
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

      // DON'T reset session start time during progress saves - only reset when starting new sessions
      // This was causing sessions to never complete because the timer kept resetting
      await _saveSessionState();

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

  Future<void> _saveSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isRunning && _activeGoal != null) {
        await prefs.setInt('active_goal_id', _activeGoal!.id!);
        await prefs.setInt('session_start_time', _sessionStartTime);
        await prefs.setInt('goal_start_time', _goalStartTime);
        await prefs.setInt('baseline_time_spent', _baselineTimeSpent);
        await prefs.setBool('is_running', _isRunning);
        print('Session state saved');
      } else {
        await prefs.remove('active_goal_id');
        await prefs.remove('session_start_time');
        await prefs.remove('goal_start_time');
        await prefs.remove('baseline_time_spent');
        await prefs.remove('is_running');
        print('Session state cleared');
      }
    } catch (e) {
      print('Error saving session state: $e');
    }
  }

  Future<void> _clearSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_goal_id');
      await prefs.remove('session_start_time');
      await prefs.remove('goal_start_time');
      await prefs.remove('baseline_time_spent');
      await prefs.remove('is_running');
    } catch (e) {
      print('Error clearing session state: $e');
    }
  }

  Future<void> _restoreActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeGoalId = prefs.getInt('active_goal_id');
      final sessionStartTime = prefs.getInt('session_start_time');
      final goalStartTime = prefs.getInt('goal_start_time');
      final baselineTimeSpent = prefs.getInt('baseline_time_spent') ?? 0;
      final wasRunning = prefs.getBool('is_running') ?? false;

      if (activeGoalId != null && sessionStartTime != null && wasRunning) {
        final goal = await _db.getGoal(activeGoalId);
        if (goal != null) {
          _activeGoal = goal;
          _sessionStartTime = sessionStartTime;
          _goalStartTime = goalStartTime ?? sessionStartTime;
          _baselineTimeSpent = baselineTimeSpent;
          _isRunning = true;

          print('Restored active session for: ${goal.title}');
          print('Session running for: ${formatTime(sessionTimeElapsed)}');
          print('Baseline time: ${formatTime(_baselineTimeSpent)}');

          // Check if session should have completed while app was closed
          await _checkBackgroundCompletion();

          if (_isRunning) {
            // Resume UI updates and notifications
            _startUpdateTimer();
            await _showRunningNotification();
            notifyListeners();
          }
        } else {
          // Goal not found, clear state
          await _clearSessionState();
        }
      }
    } catch (e) {
      print('Error restoring session: $e');
      await _clearSessionState();
    }
  }

  Future<void> _checkBackgroundCompletion() async {
    if (_activeGoal == null || !_isRunning) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final totalElapsed = currentTime - _goalStartTime;
    final sessionDuration = _getSessionDuration();

    // Check if sessions completed while in background
    final completedSessions = totalElapsed ~/ sessionDuration;

    if (completedSessions > 0) {
      print('$completedSessions session(s) completed while in background');

      // Add the completed session time to the goal
      final timeToAdd = completedSessions * sessionDuration;
      final newTimeSpent = _activeGoal!.timeSpentSeconds + timeToAdd;

      final updatedGoal = _activeGoal!.copyWith(timeSpentSeconds: newTimeSpent);
      await _db.updateGoal(updatedGoal);
      _activeGoal = updatedGoal;

      // Update session start time for current session
      _sessionStartTime = _goalStartTime + (completedSessions * sessionDuration);

      // Show notification for completed sessions
      await _showBackgroundSessionsCompleteNotification(completedSessions);

      // Check if goal is now complete
      if (goalTimeRemaining <= 0) {
        await _onGoalComplete();
        return;
      }

      await _saveSessionState();
    }
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
          '⏱️ Session: ${formatTime(sessionTimeElapsed)}/${formatTime(_getSessionDuration())} | Goal: ${formatTime(goalTimeRemaining)} remaining';

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

  Future<void> _showBackgroundSessionsCompleteNotification(int sessionCount) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'goal_sessions',
      'Goal Sessions',
      channelDescription: 'Notifications for completed goal sessions',
      importance: Importance.high,
      priority: Priority.high,
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
      3,
      '🎉 $sessionCount Session${sessionCount > 1 ? 's' : ''} Completed!',
      '${_activeGoal!.title} - Great progress while away!',
      platformChannelSpecifics,
    );
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
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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

          // Channel for background sessions
          const sessionsChannel = AndroidNotificationChannel(
            'goal_sessions',
            'Goal Sessions',
            description: 'Notifications for completed goal sessions',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          );
          await androidPlugin.createNotificationChannel(sessionsChannel);

          print('All notification channels created');
        }
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
