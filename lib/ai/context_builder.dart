import 'dart:convert';
import 'dart:io';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/models/todo.model.dart';

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

  /// Builds a narrative context for the AI.
  /// Instead of a raw data dump, this creates a structured "story" of the user's current state.
  Future<Map<String, dynamic>> buildInsightsContext({
    required int contextDays,
    required int tokenLimitApprox,
    String? primaryGoalText,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    // Detect system language
    final String systemLocale = Platform.localeName; // e.g., "en_US", "ru_RU"
    final String languageCode = systemLocale.split('_').first; // e.g., "en", "ru"

    // --- 1. Time Context ---
    final hour = now.hour;
    String timeOfDay;
    if (hour < 5)
      timeOfDay = 'Late Night / Early Morning';
    else if (hour < 12)
      timeOfDay = 'Morning';
    else if (hour < 17)
      timeOfDay = 'Afternoon';
    else if (hour < 21)
      timeOfDay = 'Evening';
    else
      timeOfDay = 'Night';

    final weekday = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][now.weekday - 1];

    final timeString =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // --- 2. Goals (Primary & Active) ---
    final goals = await DatabaseHelper.instance.getAllGoals();
    final activeGoals = goals.where((g) => g.isActive).toList();

    // Calculate today's progress
    final List<String> goalSummaries = [];
    for (final goal in activeGoals) {
      final sessions = await db.query(
        DatabaseTables.sessions,
        where: 'goal_id = ? AND start_time >= ?',
        whereArgs: [goal.id!, todayStart],
      );

      int todaySeconds = 0;
      for (final session in sessions) {
        todaySeconds += (session['actual_duration_seconds'] as int?) ?? 0;
      }
      final todayMinutes = (todaySeconds / 60).round();
      final targetMinutes = (goal.hours * 60) + goal.minutes;

      String status = "Target: ${targetMinutes}m, Done: ${todayMinutes}m";
      if (todayMinutes >= targetMinutes) status += " (Done ✅)";

      String prefix = goal.isPrimary ? "[PRIMARY GOAL] " : "";
      goalSummaries.add("- $prefix${goal.title}: $status");
    }

    // --- 3. Routines ---
    final routines = await DatabaseHelper.instance.getAllRoutines();
    final List<String> pendingRoutines = [];
    final List<String> completedRoutines = [];

    // Filter relevant routines for today
    for (final r in routines) {
      final daysStr = r[DatabaseColumns.routineDaysOfWeek] as String;
      final days = daysStr.split(',').map((e) => e == '1').toList();
      final isForToday = days.length > (now.weekday - 1) && days[now.weekday - 1];

      if (isForToday) {
        final isDone = (r[DatabaseColumns.routineIsDone] ?? 0) == 1;
        final name = r[DatabaseColumns.routineName] as String;
        final time = r[DatabaseColumns.routineTime] as String;

        if (isDone) {
          completedRoutines.add("- $name");
        } else {
          pendingRoutines.add("- $name (scheduled: $time)");
        }
      }
    }

    // --- 4. Activity Patterns (Last 7 days) ---
    final weekAgoStart = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    // Analyze note creation times to detect sleep/work patterns
    final allWeekNotes = await db.query(
      DatabaseTables.record,
      where: '${DatabaseColumns.recordCreatedAt} >= ? AND ${DatabaseColumns.recordIsLocked} = 0',
      whereArgs: [weekAgoStart],
      orderBy: '${DatabaseColumns.recordCreatedAt} ASC',
    );

    int lateNightNotes = 0; // 23:00 - 05:00
    int morningNotes = 0; // 05:00 - 12:00
    DateTime? lastActivity;
    DateTime? firstActivityToday;

    for (final m in allWeekNotes) {
      final dt = DateTime.fromMillisecondsSinceEpoch(m[DatabaseColumns.recordCreatedAt] as int);
      final h = dt.hour;

      if (h >= 23 || h < 5) {
        lateNightNotes++;
      } else if (h >= 5 && h < 12) {
        morningNotes++;
      }

      lastActivity = dt;

      // Track first activity today
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        firstActivityToday ??= dt;
      }
    }

    final List<String> patterns = [];

    if (lateNightNotes > 5) {
      patterns.add("- You're often active late at night (${lateNightNotes} notes after 23:00 this week)");
    }

    if (morningNotes < 2 && allWeekNotes.length > 10) {
      patterns.add("- Very few morning activities detected (only ${morningNotes} notes 05:00-12:00)");
    }

    if (firstActivityToday != null && firstActivityToday.hour >= 10) {
      patterns.add("- Today started at ${firstActivityToday.hour.toString().padLeft(2, '0')}:${firstActivityToday.minute.toString().padLeft(2, '0')}");
    }

    if (lastActivity != null && now.difference(lastActivity).inHours < 1) {
      final minutesAgo = now.difference(lastActivity).inMinutes;
      patterns.add("- Last activity: ${minutesAgo} minutes ago");
    }

    // --- 5. Recent Notes (Thoughts) ---
    final yesterdayStart = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    final notesMaps = await db.query(
      DatabaseTables.record,
      where: '${DatabaseColumns.recordCreatedAt} >= ? AND ${DatabaseColumns.recordIsLocked} = 0',
      whereArgs: [yesterdayStart],
      orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      limit: 10,
    );

    final List<String> recentThoughts = [];
    for (final m in notesMaps) {
      final note = Record.fromMap(m);
      if (note.text.length < 5) continue;

      String type = "Note";
      if (note.goalId != null) {
        type = "Goal Log";
      } else if (note.routineId != null) {
        type = "Routine Log";
      }

      final dt = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
      final tm = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

      String text = note.text.replaceAll('\n', ' ');
      if (text.length > 100) text = "${text.substring(0, 100)}...";

      recentThoughts.add("[$tm] $type: $text");
    }

    // --- 5. Construct Narrative ---
    final buffer = StringBuffer();
    buffer.writeln("CURRENT CONTEXT:");
    buffer.writeln("Date: $weekday, $timeString ($timeOfDay).");
    if (primaryGoalText != null && primaryGoalText.isNotEmpty) {
      buffer.writeln("User's Main Intention: \"$primaryGoalText\"");
    }

    if (patterns.isNotEmpty) {
      buffer.writeln("\nACTIVITY PATTERNS (Last 7 days):");
      patterns.forEach(buffer.writeln);
    }

    buffer.writeln("\nGOALS STATUS (Today):");
    if (goalSummaries.isEmpty) {
      buffer.writeln("No active goals tracked today.");
    } else {
      goalSummaries.forEach(buffer.writeln);
    }

    buffer.writeln("\nROUTINES (Today):");
    if (completedRoutines.isNotEmpty) {
      buffer.writeln("Completed:");
      completedRoutines.forEach(buffer.writeln);
    }
    if (pendingRoutines.isNotEmpty) {
      buffer.writeln("Still pending:");
      pendingRoutines.forEach(buffer.writeln);
    }
    if (completedRoutines.isEmpty && pendingRoutines.isEmpty) {
      buffer.writeln("No routines scheduled for today.");
    }

    // --- 3.5. Active Todos ---
    final todos = await DatabaseHelper.instance.getActiveTodos();
    final List<String> todosList = [];
    for (final todo in todos) {
      String todoText = "- ${todo.title}";
      if (todo.targetDateTime != null) {
        final dt = todo.targetDateTime!;
        final isToday = dt.day == now.day && dt.month == now.month && dt.year == now.year;
        final isTomorrow = dt.day == now.add(const Duration(days: 1)).day &&
            dt.month == now.add(const Duration(days: 1)).month &&
            dt.year == now.add(const Duration(days: 1)).year;

        if (isToday) {
          todoText += " (Due today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')})";
        } else if (isTomorrow) {
          todoText += " (Due tomorrow at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')})";
        } else {
          todoText += " (Due ${dt.day}/${dt.month})";
        }
      }
      if (todo.todoType != TodoType.noDate) {
        todoText += " [${todo.todoType.value}]";
      }
      todosList.add(todoText);
    }

    buffer.writeln("\nTODOS:");
    if (todosList.isEmpty) {
      buffer.writeln("No active todos.");
    } else {
      todosList.forEach(buffer.writeln);
    }

    buffer.writeln("\nRECENT THOUGHTS (Last 24h):");
    if (recentThoughts.isEmpty) {
      buffer.writeln("No recent notes.");
    } else {
      recentThoughts.forEach(buffer.writeln);
    }

    final narrative = buffer.toString();

    // Return map compatible with existing structure but with new 'narrative' field
    return {
      'narrative': narrative,
      'language_code': languageCode,
      'system_locale': systemLocale,
      // Keep some raw fields for UI preview if needed, or minimal set
      'context_json': jsonEncode({'narrative': narrative}), // Simplified JSON
      'generated_at': now.millisecondsSinceEpoch,
    };
  }
}
