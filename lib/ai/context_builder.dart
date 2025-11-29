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
      intervalMinutes:
          (map[DatabaseColumns.settingInsightIntervalMinutes] as int?) ?? 60,
      contextDays:
          (map[DatabaseColumns.settingInsightContextDays] as int?) ?? 7,
      tokenLimit:
          (map[DatabaseColumns.settingInsightTokenLimit] as int?) ?? 4000,
      quietStart: map[DatabaseColumns.settingQuietHoursStart] as String?,
      quietEnd: map[DatabaseColumns.settingQuietHoursEnd] as String?,
      primaryGoalId: map[DatabaseColumns.settingPrimaryGoalId] as int?,
      mainIntentionText:
          map[DatabaseColumns.settingMainIntentionText] as String?,
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
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    
    // --- 1. Time Context ---
    final hour = now.hour;
    String timeOfDay;
    if (hour < 5) timeOfDay = 'Late Night / Early Morning';
    else if (hour < 12) timeOfDay = 'Morning';
    else if (hour < 17) timeOfDay = 'Afternoon';
    else if (hour < 21) timeOfDay = 'Evening';
    else timeOfDay = 'Night';
    
    final weekday = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ][now.weekday - 1];

    final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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
    int routinesDone = 0;
    int routinesTotal = 0;
    final List<String> pendingRoutines = [];
    
    // Filter relevant routines for today
    for (final r in routines) {
      // Logic to check if routine is for today would be good, 
      // but for now we look at all active routines or check db structure.
      // The routines table has `days_of_week` string like "1,0,1..."
      final daysStr = r[DatabaseColumns.routineDaysOfWeek] as String;
      final days = daysStr.split(',').map((e) => e == '1').toList();
      final isForToday = days.length > (now.weekday - 1) && days[now.weekday - 1];
      
      if (isForToday) {
        routinesTotal++;
        final isDone = (r[DatabaseColumns.routineIsDone] ?? 0) == 1;
        if (isDone) {
          routinesDone++;
        } else {
          pendingRoutines.add("- ${r[DatabaseColumns.routineName]} (${r[DatabaseColumns.routineTime]})");
        }
      }
    }

    // --- 4. Recent Notes (Thoughts) ---
    // Fetch last 10 notes from today/yesterday to get "headspace"
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
      // Skip system logs if possible (simple heuristic: too short or specific patterns)
      if (note.text.length < 5) continue; 
      
      // Determine context
      String type = "Note";
      if (note.goalId != null) type = "Goal Log";
      else if (note.routineId != null) type = "Routine Log";
      
      // Format: [14:30] Note: Text
      final dt = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
      final tm = "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
      
      // Truncate long notes
      String text = note.text.replaceAll('\n', ' ');
      if (text.length > 100) text = text.substring(0, 100) + "...";
      
      recentThoughts.add("[$tm] $type: $text");
    }

    // --- 5. Construct Narrative ---
    final buffer = StringBuffer();
    buffer.writeln("CURRENT CONTEXT:");
    buffer.writeln("Date: $weekday, $timeString ($timeOfDay).");
    if (primaryGoalText != null && primaryGoalText.isNotEmpty) {
      buffer.writeln("User's Main Intention: \"$primaryGoalText\"");
    }
    
    buffer.writeln("\nGOALS STATUS (Today):");
    if (goalSummaries.isEmpty) {
      buffer.writeln("No active goals tracked today.");
    } else {
      goalSummaries.forEach(buffer.writeln);
    }
    
    buffer.writeln("\nROUTINES (Today):");
    buffer.writeln("Progress: $routinesDone / $routinesTotal completed.");
    if (pendingRoutines.isNotEmpty) {
      buffer.writeln("Remaining:");
      pendingRoutines.forEach(buffer.writeln);
    } else if (routinesTotal > 0) {
      buffer.writeln("All routines completed!");
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
      // Keep some raw fields for UI preview if needed, or minimal set
      'context_json': jsonEncode({'narrative': narrative}), // Simplified JSON
      'generated_at': now.millisecondsSinceEpoch,
    };
  }
}
