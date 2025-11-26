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
      where: '${DatabaseColumns.recordCreatedAt} >= ? AND ${DatabaseColumns.recordIsLocked} = 0',
      whereArgs: [since],
      orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      limit: 500,
    );
    final recentNotes = notesMaps.map((m) => Record.fromMap(m)).toList();

    // Fetch all tags to build a dictionary
    final tagsRows = await db.query(DatabaseTables.category);
    final tagsDict = <String, String>{};
    for (final row in tagsRows) {
      tagsDict['${row[DatabaseColumns.id]}'] =
          row[DatabaseColumns.tagName] as String;
    }

    // Attach tag IDs to notes
    for (var note in recentNotes) {
      final tagsData = await db.query(
        DatabaseTables.recordTag,
        columns: ['tagId'],
        where: 'recordId = ?',
        whereArgs: [note.id],
      );
      note.tagIds = tagsData.map((tag) => tag['tagId'] as int).toList();
    }


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
        'title': r[DatabaseColumns.routineName] as String?,
        'scheduled_time': r[DatabaseColumns.routineTime] as String?,
        'is_done': (r[DatabaseColumns.routineIsDone] ?? 0) == 1,
        'is_skipped': false, // Not currently tracked in DB
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

    // Last 3 insights (to avoid repetition)
    final lastInsights = await db.query(
      DatabaseTables.aiInsights,
      orderBy: '${DatabaseColumns.insightDeliveredAt} DESC',
      limit: 3,
    );
    final previousInsights = lastInsights.map((m) => {
      'title': m[DatabaseColumns.insightTitle] as String?,
      'body': m[DatabaseColumns.insightBody] as String?,
      'delivered_at': m[DatabaseColumns.insightDeliveredAt] as int?,
    }).toList();

    // Truncate notes to fit token limit roughly (very rough: 4 chars ≈ 1 token)
    final int charBudget = tokenLimitApprox * 4;
    int used = 0;
    final List<Map<String, dynamic>> compactNotes = [];
    for (final n in recentNotes) {
      final text = (n.title.isNotEmpty ? '${n.title}\n' : '') + n.text;
      final cut = text.substring(0, text.length > 600 ? 600 : text.length);
      if (used + cut.length > charBudget) break;
      used += cut.length;
      
      // Determine type for AI context
      String type = 'note'; // default
      if (n.goalId != null) type = 'goal';
      else if (n.routineId != null) type = 'routine';
      else if (n.recordType.isNotEmpty && n.recordType != 'regular') type = n.recordType;

      final Map<String, dynamic> noteMap = {
        'd': _formatDate(DateTime.fromMillisecondsSinceEpoch(n.createdAt)), // created_at -> d (formatted)
        'txt': cut,        // text -> txt
        'tp': type,        // type -> tp
      };
      
      if (n.tagIds.isNotEmpty) {
        noteMap['t'] = n.tagIds; // t -> tag_ids
      }
      
      compactNotes.add(noteMap);
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
      'tags_map': tagsDict,
      'recent_notes': compactNotes,
      'previous_insights': previousInsights,
      'generated_at': DateTime.now().millisecondsSinceEpoch,
    };

    // Also provide a compact JSON string if needed
    context['context_json'] = jsonEncode(context);
    return context;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (checkDate == today) {
      return 'Сегодня $timeStr';
    } else if (checkDate == yesterday) {
      return 'Вчера $timeStr';
    } else {
      final month = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'][date.month - 1];
      return '${date.day} $month $timeStr';
    }
  }
}
