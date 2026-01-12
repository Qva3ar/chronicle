import 'dart:convert';
import 'dart:developer' as developer;

import 'package:chrono/db_manager.dart';
import 'package:home_widget/home_widget.dart';

/// Pure widget updater for Goals home widget.
///
/// Separated from `goal_widget_service.dart` to avoid circular imports with
/// `timer_service.dart` and background dispatchers.
class GoalsWidgetUpdater {
  static const String iosWidgetName = 'ChronoGoalsWidget';

  // Widget data keys (must match Android provider expectations)
  static const String keyGoalsData = 'goals_data';
  static const String keyGoalsCount = 'goals_count';
  static const String keyActiveGoalId = 'active_goal_id';
  static const String keyAppName = 'app_name';

  final DatabaseHelper _db;
  GoalsWidgetUpdater(this._db);

  Future<void> update() async {
    try {
      developer.log('[GoalsWidgetUpdater] Updating goals widget', name: 'goal_widget');

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
      int runningGoalId = 0;
      for (final g in activeGoals) {
        if (g.isActive && g.sessionResumedTimestampSeconds != null) {
          runningGoalId = g.id ?? 0;
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
          'timeSpentSeconds': goal.timeSpentSeconds,
          'goalTime': goal.formattedGoalTime,
          'sessionResumedTimestampSeconds': goal.sessionResumedTimestampSeconds ?? 0,
          'isActive': goal.isActive,
          // "Running" should mean actively running, not just having a timestamp.
          'isRunning': isRunning,
          'isPrimary': goal.isPrimary,
        };
      }).toList();

      await HomeWidget.saveWidgetData<String>(keyGoalsData, jsonEncode(goalsData));
      await HomeWidget.saveWidgetData<int>(keyGoalsCount, activeGoals.length);
      await HomeWidget.saveWidgetData<int>(keyActiveGoalId, runningGoalId);
      await HomeWidget.saveWidgetData<String>(keyAppName, 'Chrono');

      // Trigger widget update on platform
      await HomeWidget.updateWidget(
        name: 'ChronoGoalsWidgetProvider',
        iOSName: iosWidgetName,
      );
    } catch (e) {
      developer.log('[GoalsWidgetUpdater] Error updating widget: $e',
          name: 'goal_widget', error: e);
    }
  }
}

