import 'dart:convert';

import 'package:chrono/db_manager.dart';
import 'package:chrono/models/record.dart';

class InsightsSettings {
  final bool insightEnabled;
  final int intervalMinutes;
  final int contextDays;
  final int tokenLimit;
  final String? quietStart; // HH:mm
  final String? quietEnd; // HH:mm
  final int? primaryGoalId;
  final String? mainIntentionText;

  InsightsSettings({
    required this.insightEnabled,
    required this.intervalMinutes,
    required this.contextDays,
    required this.tokenLimit,
    required this.quietStart,
    required this.quietEnd,
    required this.primaryGoalId,
    required this.mainIntentionText,
  });
}

class ContextBuilder {
  ContextBuilder._();
  static final ContextBuilder instance = ContextBuilder._();

  Future<InsightsSettings> loadSettings() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.appSettings, limit: 1);
    if (rows.isEmpty) {
      return InsightsSettings(
        insightEnabled: true,
        intervalMinutes: 60,
        contextDays: 7,
        tokenLimit: 4000,
        quietStart: null,
        quietEnd: null,
        primaryGoalId: null,
        mainIntentionText: null,
      );
    }
    final map = rows.first;
    return InsightsSettings(
      insightEnabled: (map[DatabaseColumns.settingInsightEnabled] ?? 1) == 1,
      intervalMinutes: (map[DatabaseColumns.settingInsightIntervalMinutes] as int?) ?? 60,
      contextDays: (map[DatabaseColumns.settingInsightContextDays] as int?) ?? 7,
      tokenLimit: (map[DatabaseColumns.settingInsightTokenLimit] as int?) ?? 4000,
      quietStart: map[DatabaseColumns.settingQuietHoursStart] as String?,
      quietEnd: map[DatabaseColumns.settingQuietHoursEnd] as String?,
      primaryGoalId: map[DatabaseColumns.settingPrimaryGoalId] as int?,
      mainIntentionText: map[DatabaseColumns.settingMainIntentionText] as String?,
    );
  }

  Future<Map<String, dynamic>> buildInsightsContext({
    required int contextDays,
    required int tokenLimitApprox,
    String? primaryGoalText,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final since = now.subtract(Duration(days: contextDays)).millisecondsSinceEpoch;
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    // Recent notes
    final notesMaps = await db.query(
      DatabaseTables.record,
      where: '${DatabaseColumns.recordCreatedAt} >= ?',
      whereArgs: [since],
      orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      limit: 500,
    );
    final recentNotes = notesMaps.map((m) => Record.fromMap(m)).toList();

    // Goals with today's session data
    final goals = await DatabaseHelper.instance.getAllGoals();

    // Get today's session data for each active goal
    final goalsWithTodayData = <Map<String, dynamic>>[];
    for (final goal in goals.where((g) => g.isActive)) {
      final sessions = await db.query(
        DatabaseTables.sessions,
        where: 'goal_id = ? AND start_time >= ?',
        whereArgs: [goal.id!, todayStart],
      );

      int todaySeconds = 0;
      for (final session in sessions) {
        todaySeconds += (session['actual_duration_seconds'] as int?) ?? 0;
      }

      final targetSeconds = goal.hours * 3600 + goal.minutes * 60;
      final remainingSeconds = targetSeconds - todaySeconds;

      goalsWithTodayData.add({
        'id': goal.id,
        'title': goal.title,
        'progress': goal.progress,
        'target_today_minutes': (targetSeconds / 60).round(),
        'completed_today_minutes': (todaySeconds / 60).round(),
        'remaining_today_minutes': (remainingSeconds / 60).round(),
        'is_on_track': todaySeconds >= targetSeconds,
      });
    }

    // Routines with completion status
    final routines = await DatabaseHelper.instance.getAllRoutines();
    final routinesWithStatus = routines.map((r) {
      return {
        'title': r['title'] as String?,
        'scheduled_time': r['scheduled_time'] as String?,
        'is_done': (r['is_done'] ?? 0) == 1,
        'is_skipped': (r['is_skipped'] ?? 0) == 1,
      };
    }).toList();

    // Interest signals
    final interestRows = await db.query(
      DatabaseTables.aiInterestSignals,
      where: '${DatabaseColumns.aiCreatedAt} >= ?',
      whereArgs: [since],
      orderBy: '${DatabaseColumns.aiCreatedAt} DESC',
      limit: 200,
    );

    // Truncate notes to fit token limit roughly (very rough: 4 chars ≈ 1 token)
    final int charBudget = tokenLimitApprox * 4;
    int used = 0;
    final List<Map<String, dynamic>> compactNotes = [];
    for (final n in recentNotes) {
      final text = (n.title.isNotEmpty ? '${n.title}\n' : '') + n.text;
      final cut = text.substring(0, text.length > 600 ? 600 : text.length);
      if (used + cut.length > charBudget) break;
      used += cut.length;
      compactNotes.add({
        'created_at': n.createdAt,
        'text': cut,
      });
    }

    // Time context
    final hour = now.hour;
    String timeOfDay;
    if (hour < 6) {
      timeOfDay = 'ночь';
    } else if (hour < 12) {
      timeOfDay = 'утро';
    } else if (hour < 18) {
      timeOfDay = 'день';
    } else if (hour < 22) {
      timeOfDay = 'вечер';
    } else {
      timeOfDay = 'ночь';
    }

    final context = {
      'current_time': {
        'hour': now.hour,
        'minute': now.minute,
        'time_of_day': timeOfDay,
        'day_of_week': ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'][now.weekday - 1],
      },
      'primary_goal': primaryGoalText,
      'active_goals_today': goalsWithTodayData,
      'routines_today': {
        'total': routines.length,
        'completed': routinesWithStatus.where((r) => r['is_done'] == true).length,
        'pending': routinesWithStatus.where((r) => r['is_done'] == false && r['is_skipped'] == false).length,
        'details': routinesWithStatus,
      },
      'recent_interest_signals': interestRows
          .map((m) => {
                'topic': m[DatabaseColumns.aiTopic],
                'intent': m[DatabaseColumns.aiIntent],
                'confidence': m[DatabaseColumns.aiConfidence],
                'created_at': m[DatabaseColumns.aiCreatedAt],
              })
          .toList(),
      'recent_notes': compactNotes,
      'generated_at': DateTime.now().millisecondsSinceEpoch,
    };

    // Also provide a compact JSON string if needed
    context['context_json'] = jsonEncode(context);
    return context;
  }
}
