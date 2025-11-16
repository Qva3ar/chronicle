import 'package:workmanager/workmanager.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/record.service.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/services/routine_service.dart';
import 'package:chrono/ai/insight_engine.dart';
import 'package:chrono/ai/context_builder.dart';
import 'package:chrono/ai/summarizer.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Unified background task dispatcher for WorkManager
/// Handles all background tasks: session completion, daily reset, and insights
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
      final recordService = RecordService(db);
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
    final routineService = RoutineService(db);
    final goalService = GoalService(db);

    // Reset routines and goals
    final routines = await routineService.getAllRoutines();
    for (final routine in routines) {
      await routineService.resetRoutine(routine.id);
    }
    await goalService.resetAllGoals();

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

/// Show session completion notifications
Future<void> _showSessionCompletionNotifications(
  Goal goal,
  int sessionDuration,
  bool isGoalComplete,
) async {
  try {
    final notif = NotificationService();
    await notif.initialize(calledFromBackgroundTask: true);

    // For now, use simple notification - we can enhance this later
    // The notification service has the methods for routine notifications,
    // we can add goal-specific methods later if needed

    print('[SessionCompletion] ✅ Session completed - notifications would be shown here');
    // TODO: Add showSessionCompletedNotification method to NotificationService
    // TODO: Add showGoalCompletedNotification method to NotificationService
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

      print('[BackgroundTaskManager] ✅ Daily reset scheduled for $nextMidnight');
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
