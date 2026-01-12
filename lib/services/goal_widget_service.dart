import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/background/task_dispatcher.dart';
import 'package:chrono/record.service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level callback for goal widget interactions
/// MUST be top-level function for background execution
@pragma('vm:entry-point')
Future<void> goalWidgetCallback(Uri? uri) async {
  developer.log('[GoalWidgetService] Widget interaction received: $uri', name: 'goal_widget');

  if (uri == null) return;

  final db = DatabaseHelper.instance;
  final notifications = FlutterLocalNotificationsPlugin();

  // Initialize notifications for background
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await notifications.initialize(initSettings);

  // Handle different widget actions
  if (uri.host == 'start_goal') {
    final goalId = uri.queryParameters['id'];
    developer.log('[GoalWidgetService] Start goal action triggered: $goalId', name: 'goal_widget');

    if (goalId != null) {
      try {
        // 1. Stop any currently active goal first
        final allGoals = await db.getAllGoals();
        for (final g in allGoals) {
          if (g.isActive && g.id.toString() != goalId) {
            // Save progress for other active goal if it was running
            if (g.sessionResumedTimestampSeconds != null) {
              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              final elapsed = now - g.sessionResumedTimestampSeconds!;
              final newTimeSpent = (g.timeSpentSeconds + elapsed).clamp(0, g.totalSeconds);
              await db.updateGoal(g.copyWith(
                isActive: false,
                timeSpentSeconds: newTimeSpent,
                sessionResumedTimestampSeconds: null,
                clearSessionResumedTimestamp: true,
              ));
            } else {
              await db.updateGoal(g.copyWith(isActive: false));
            }
            // Cancel background tasks for others
            await BackgroundTaskManager.cancelSessionCompletion(g.id!);
          }
        }

        // 2. Start this goal
        final goal = allGoals.firstWhere((g) => g.id.toString() == goalId);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await db.updateGoal(goal.copyWith(
          isActive: true,
          sessionResumedTimestampSeconds: now,
        ));

        // 3. Schedule background alarm
        final sessionDuration = goal.sessionMinutes * 60;
        final completionTime = DateTime.now().add(Duration(seconds: sessionDuration));
        await BackgroundTaskManager.scheduleSessionCompletion(
          goalId: goal.id!,
          sessionStartTime: now,
          sessionDuration: sessionDuration,
          completionTime: completionTime,
        );

        // 4. Show running notification
        await _showRunningNotification(notifications, goal);

        // Update widget
        final service = GoalWidgetService(db);
        await service.updateWidget();
      } catch (e) {
        developer.log('[GoalWidgetService] Error starting goal: $e', name: 'goal_widget', error: e);
      }
    }
  } else if (uri.host == 'stop_goal') {
    final goalId = uri.queryParameters['id'];
    developer.log('[GoalWidgetService] Stop goal action triggered: $goalId', name: 'goal_widget');

    if (goalId != null) {
      try {
        // Get goal
        final goal = await db.getGoal(int.parse(goalId));
        if (goal != null) {
          // 1. Calculate elapsed time and save progress
          int newTimeSpent = goal.timeSpentSeconds;
          if (goal.sessionResumedTimestampSeconds != null) {
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final elapsed = now - goal.sessionResumedTimestampSeconds!;
            newTimeSpent = (goal.timeSpentSeconds + elapsed).clamp(0, goal.totalSeconds);
          }

          final isComplete = newTimeSpent >= goal.totalSeconds;

          // 2. Stop timer (clear isActive and sessionResumedTimestamp)
          await db.updateGoal(goal.copyWith(
            isActive: false,
            timeSpentSeconds: newTimeSpent,
            sessionResumedTimestampSeconds: null,
            clearSessionResumedTimestamp: true,
            completedAt: isComplete ? DateTime.now().millisecondsSinceEpoch : null,
          ));

          // 3. Cancel background tasks and notifications
          await BackgroundTaskManager.cancelSessionCompletion(goal.id!);
          await notifications.cancel(1); // Cancel running notification

          // 4. If completed, create record and notify
          if (isComplete) {
            final recordService = RecordService();
            final recordData = {
              'goal_id': goal.id,
              'time_minutes': (newTimeSpent / 60).round(),
              'status': 'completed',
            };
            final record = {
              DatabaseColumns.recordTitle: goal.title,
              DatabaseColumns.recordText: jsonEncode(recordData),
              DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
              DatabaseColumns.recordType: 'goal',
              DatabaseColumns.recordGoalId: goal.id,
            };
            await recordService.createRecord(record, []);

            // Show completion notification
            await _showGoalCompleteNotification(notifications, goal);
          }

          // Update widget
          final service = GoalWidgetService(db);
          await service.updateWidget();
        }
      } catch (e) {
        developer.log('[GoalWidgetService] Error stopping goal: $e', name: 'goal_widget', error: e);
      }
    }
  } else if (uri.host == 'open_goals') {
    developer.log('[GoalWidgetService] Open goals action triggered', name: 'goal_widget');
    // The main app will handle this through initial URI
  }
}

Future<void> _showRunningNotification(FlutterLocalNotificationsPlugin notifications, Goal goal) async {
  final androidDetails = AndroidNotificationDetails(
    'timer_channel',
    'Timer Notifications',
    channelDescription: 'Notifications for goal timer sessions',
    importance: Importance.high,
    priority: Priority.high,
    ongoing: true,
    autoCancel: false,
    icon: '@mipmap/ic_launcher',
    showProgress: true,
    indeterminate: true,
  );
  final details = NotificationDetails(android: androidDetails);
  await notifications.show(
    1,
    '🎯 ${goal.title}',
    '⏱️ Timer Running via Widget',
    details,
  );
}

Future<void> _showGoalCompleteNotification(FlutterLocalNotificationsPlugin notifications, Goal goal) async {
  final androidDetails = AndroidNotificationDetails(
    'goal_complete',
    'Goal Complete',
    importance: Importance.max,
    priority: Priority.max,
  );
  final details = NotificationDetails(android: androidDetails);
  await notifications.show(
    4,
    '🎉 Goal Completed!',
    '${goal.title} - Congratulations!',
    details,
  );
}

/// Service for managing goals home screen widget on iOS and Android
/// Displays active goals with progress and allows quick actions
class GoalWidgetService {
  static const String _iosWidgetName = 'ChronoGoalsWidget';

  // Widget data keys
  static const String _keyGoalsData = 'goals_data';
  static const String _keyGoalsCount = 'goals_count';
  static const String _keyActiveGoalId = 'active_goal_id';
  static const String _keyAppName = 'app_name';

  final DatabaseHelper _db;

  GoalWidgetService(this._db);

  /// Initialize widget service and set up callbacks
  Future<void> initialize() async {
    try {
      developer.log('[GoalWidgetService] Initializing goal widget service', name: 'goal_widget');

      // Callback registration is now handled centrally in main.dart
      // via UnifiedWidgetHandler to support multiple widgets
      // HomeWidget.registerInteractivityCallback(goalWidgetCallback);

      // Initial widget update
      await updateWidget();

      developer.log('[GoalWidgetService] Goal widget service initialized', name: 'goal_widget');
    } catch (e) {
      developer.log('[GoalWidgetService] Error initializing: $e', name: 'goal_widget', error: e);
    }
  }

  /// Update widget with latest goal data
  Future<void> updateWidget() async {
    try {
      developer.log('[GoalWidgetService] Updating goal widget', name: 'goal_widget');

      // Fetch goals
      final goals = await _db.getAllGoals();

      // Filter out completed (today) and archived (manual) goals and sort by primary status
      final activeGoals =
          goals.where((g) => g.completedAt == null && g.archivedAt == null).toList();
      activeGoals.sort((a, b) {
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        return 0;
      });

      // Find currently running goal (null if none)
      Goal? runningGoal;
      for (final g in activeGoals) {
        if (g.isActive && g.sessionResumedTimestampSeconds != null) {
          runningGoal = g;
          break;
        }
      }

      // Convert goals to JSON
      final goalsData = activeGoals.take(5).map((goal) {
        final progressPercent = (goal.progress * 100).toInt();
        final isRunning = goal.isActive && goal.sessionResumedTimestampSeconds != null;
        return {
          'id': goal.id,
          'title': goal.title,
          'progress': progressPercent,
          'timeSpent': goal.formattedTimeSpent,
          'goalTime': goal.formattedGoalTime,
          'isActive': goal.isActive,
          // "Running" should mean actively running, not just having a timestamp.
          'isRunning': isRunning,
          'isPrimary': goal.isPrimary,
        };
      }).toList();

      // Save widget data
      await HomeWidget.saveWidgetData<String>(_keyGoalsData, jsonEncode(goalsData));
      await HomeWidget.saveWidgetData<int>(_keyGoalsCount, activeGoals.length);
      await HomeWidget.saveWidgetData<int>(_keyActiveGoalId, runningGoal?.id ?? 0);
      await HomeWidget.saveWidgetData<String>(_keyAppName, 'Chrono');

      // Trigger widget update on platform
      await HomeWidget.updateWidget(
        name: 'ChronoGoalsWidgetProvider',
        iOSName: _iosWidgetName,
      );

      developer.log('[GoalWidgetService] Goal widget updated with ${activeGoals.length} goals', name: 'goal_widget');
    } catch (e) {
      developer.log('[GoalWidgetService] Error updating widget: $e', name: 'goal_widget', error: e);
    }
  }

  /// Clear all widget data
  Future<void> clearWidget() async {
    try {
      developer.log('[GoalWidgetService] Clearing goal widget data', name: 'goal_widget');

      await HomeWidget.saveWidgetData<String>(_keyGoalsData, jsonEncode([]));
      await HomeWidget.saveWidgetData<int>(_keyGoalsCount, 0);
      await HomeWidget.saveWidgetData<int>(_keyActiveGoalId, 0);

      await HomeWidget.updateWidget(
        name: 'ChronoGoalsWidgetProvider',
        iOSName: _iosWidgetName,
      );

      developer.log('[GoalWidgetService] Goal widget cleared', name: 'goal_widget');
    } catch (e) {
      developer.log('[GoalWidgetService] Error clearing widget: $e', name: 'goal_widget', error: e);
    }
  }


  /// Get the launch URI if the app was opened from widget
  static Future<Uri?> getWidgetLaunchUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      developer.log('[GoalWidgetService] Error getting launch URI: $e', name: 'goal_widget', error: e);
      return null;
    }
  }
}
