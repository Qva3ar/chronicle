import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/models/record_type.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:intl/intl.dart';

class RoutineDetail {
  final String name;
  final bool completed;

  RoutineDetail({required this.name, required this.completed});

  Map<String, dynamic> toJson() => {'name': name, 'done': completed};

  factory RoutineDetail.fromJson(Map<String, dynamic> json) => RoutineDetail(
        name: json['name'] as String? ?? '',
        completed: json['done'] as bool? ?? false,
      );
}

class GoalDetail {
  final String name;
  final double progress; // 0.0 - 1.0

  GoalDetail({required this.name, required this.progress});

  Map<String, dynamic> toJson() => {
        'name': name,
        'progress': double.parse(progress.toStringAsFixed(2)),
      };

  factory GoalDetail.fromJson(Map<String, dynamic> json) => GoalDetail(
        name: json['name'] as String? ?? '',
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      );
}

class ProductivityScore {
  final double score;
  final String date;
  final int totalWeight;
  final double completedWeight;
  final int routinesDone;
  final int routinesTotal;
  final double goalsProgress;
  final List<RoutineDetail> routineDetails;
  final List<GoalDetail> goalDetails;

  ProductivityScore({
    required this.score,
    required this.date,
    required this.totalWeight,
    required this.completedWeight,
    required this.routinesDone,
    required this.routinesTotal,
    required this.goalsProgress,
    this.routineDetails = const [],
    this.goalDetails = const [],
  });

  /// Serialized form stored in the productivity Record.
  ///
  /// Only the aggregate snapshot is persisted. Per-item breakdown
  /// (`routineDetails`/`goalDetails`) is intentionally NOT stored — it would
  /// duplicate data already held in the routine-completion and goal records.
  /// The history screen recomputes the breakdown on demand via
  /// [ProductivityService.recalculateForDate].
  Map<String, dynamic> toJson() => {
        'score': double.parse(score.toStringAsFixed(1)),
        'date': date,
        'total_weight': totalWeight,
        'completed_weight': double.parse(completedWeight.toStringAsFixed(2)),
        'routines_done': routinesDone,
        'routines_total': routinesTotal,
        'goals_progress': double.parse(goalsProgress.toStringAsFixed(2)),
      };

  factory ProductivityScore.fromJson(Map<String, dynamic> json) {
    return ProductivityScore(
      score: (json['score'] as num).toDouble(),
      date: json['date'] as String,
      totalWeight: (json['total_weight'] as num).toInt(),
      completedWeight: (json['completed_weight'] as num).toDouble(),
      routinesDone: (json['routines_done'] as num).toInt(),
      routinesTotal: (json['routines_total'] as num).toInt(),
      goalsProgress: (json['goals_progress'] as num).toDouble(),
      routineDetails: (json['routines'] as List?)
              ?.map((r) => RoutineDetail.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      goalDetails: (json['goals'] as List?)
              ?.map((g) => GoalDetail.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Factor to reduce routine weight vs goals (routines are easier to complete).
/// 0.6 = a routine contributes 60% of its nominal weight compared to a goal.
const double routineWeightFactor = 0.6;

class ProductivityService {
  static final ProductivityService instance = ProductivityService._();
  final DatabaseHelper _db = DatabaseHelper.instance;

  ProductivityService._();

  /// Calculate the current productivity score from live routine/goal state.
  Future<ProductivityScore> calculateCurrentScore() async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    return _calculateScoreForDate(dateStr);
  }

  /// Recompute the full score (including per-item routine/goal breakdown) for a
  /// given date. Used by the history screen to fill in details on demand,
  /// since the stored record only keeps the aggregate snapshot.
  Future<ProductivityScore> recalculateForDate(String date) =>
      _calculateScoreForDate(date);

  static final _productivityUpdatedController =
      StreamController<int>.broadcast(sync: true);
  static final _productivityScoreUpdatedController =
      StreamController<ProductivityScore>.broadcast(sync: true);

  /// Emits recordId when a productivity record is created or updated.
  Stream<int> get onProductivityUpdated => _productivityUpdatedController.stream;

  /// Emits the new score when a productivity record is created or updated.
  /// Use this so Banner and note stay in sync without recalculating.
  Stream<ProductivityScore> get onProductivityScoreUpdated =>
      _productivityScoreUpdatedController.stream;

  /// Calculate score for a specific date (uses that date's weekday for routine filtering).
  /// For today: routine counts as done if [Routine.isDone] **or** there is a completion
  /// record that day (covers import: export clears `is_done` but keeps notes).
  /// Goals: max(timer progress, progress inferred from goal records that day).
  /// For past dates: completion records only (routine flags are not historical).
  Future<ProductivityScore> _calculateScoreForDate(String dateStr) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final isToday = dateStr == todayStr;

    final targetDate = DateTime.tryParse(dateStr) ?? now;
    final currentDayIndex = targetDate.weekday - 1;

    final DateTime scoreDayStart = isToday
        ? DateTime(now.year, now.month, now.day)
        : DateTime(targetDate.year, targetDate.month, targetDate.day);
    final scoreDayEnd = scoreDayStart.add(const Duration(days: 1));
    final scoreStartMs = scoreDayStart.millisecondsSinceEpoch;
    final scoreEndMs = scoreDayEnd.millisecondsSinceEpoch;

    final routineMaps = await _db.getAllRoutines();
    final allRoutines = routineMaps.map((m) => Routine.fromMap(m)).toList();
    final dayRoutines =
        allRoutines.where((r) => !r.isArchived && r.isActiveOnDay(currentDayIndex)).toList();

    final allGoals = await _db.getAllGoals();
    final activeGoals = allGoals.where((g) => !g.isArchived).toList();

    if (dayRoutines.isEmpty && activeGoals.isEmpty) {
      return ProductivityScore(
        score: 0,
        date: dateStr,
        totalWeight: 0,
        completedWeight: 0,
        routinesDone: 0,
        routinesTotal: 0,
        goalsProgress: 0,
      );
    }

    double totalWeight = 0;
    double completedWeight = 0;
    int routinesDone = 0;
    final routineDetails = <RoutineDetail>[];

    for (final routine in dayRoutines) {
      final w = routine.priority * routineWeightFactor;
      totalWeight += w;
      bool completed = false;
      if (isToday) {
        completed = routine.isDone;
      }
      if (!completed && routine.id != null) {
        final records = await _db.getRecordsByRoutineId(routine.id!);
        completed = records.any((r) {
          final ts = r[DatabaseColumns.recordCreatedAt] as int;
          return ts >= scoreStartMs && ts < scoreEndMs;
        });
      }
      if (completed) {
        completedWeight += w;
        routinesDone++;
      }
      routineDetails.add(RoutineDetail(name: routine.name, completed: completed));
    }

    double goalsProgressSum = 0;
    final goalDetails = <GoalDetail>[];

    for (final goal in activeGoals) {
      totalWeight += goal.priority;
      double progress = 0.0;
      if (goal.totalSeconds > 0 && goal.id != null) {
        if (isToday) {
          progress =
              (goal.timeSpentSeconds / goal.totalSeconds).clamp(0.0, 1.0);
          final fromRecords = await _goalProgressFromRecordsForDay(
            goal,
            scoreStartMs,
            scoreEndMs,
          );
          progress = math.max(progress, fromRecords);
        } else {
          progress = await _goalProgressFromRecordsForDay(
            goal,
            scoreStartMs,
            scoreEndMs,
          );
        }
      }
      completedWeight += goal.priority * progress;
      goalsProgressSum += progress;
      goalDetails.add(GoalDetail(name: goal.title, progress: progress));
    }

    final score = totalWeight > 0 ? 10 * completedWeight / totalWeight : 0.0;
    final avgGoalsProgress =
        activeGoals.isNotEmpty ? goalsProgressSum / activeGoals.length : 0.0;

    return ProductivityScore(
      score: score,
      date: dateStr,
      totalWeight: totalWeight.round(),
      completedWeight: completedWeight,
      routinesDone: routinesDone,
      routinesTotal: dayRoutines.length,
      goalsProgress: avgGoalsProgress,
      routineDetails: routineDetails,
      goalDetails: goalDetails,
    );
  }

  Future<double> _goalProgressFromRecordsForDay(
    Goal goal,
    int startMs,
    int endMs,
  ) async {
    if (goal.totalSeconds <= 0 || goal.id == null) return 0.0;
    final records = await _db.getRecordsByGoalId(goal.id!);
    int minutesThatDay = 0;
    for (final r in records) {
      final ts = r[DatabaseColumns.recordCreatedAt] as int?;
      if (ts == null || ts < startMs || ts >= endMs) continue;
      final text = r[DatabaseColumns.recordText] as String? ?? '';
      final m = _extractTimeMinutes(text);
      if (m != null) minutesThatDay += m;
    }
    final targetMinutes = goal.totalSeconds ~/ 60;
    return targetMinutes > 0
        ? (minutesThatDay / targetMinutes).clamp(0.0, 1.0)
        : 0.0;
  }

  int? _extractTimeMinutes(String text) {
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) {
        final tm = data['time_minutes'];
        if (tm is int) return tm;
        if (tm is num) return tm.toInt();
      }
    } catch (_) {
      final match = RegExp(r'time_minutes: (\d+)').firstMatch(text);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Create or update today's productivity Record.
  /// [forDate] - if set, use this date instead of today (e.g. for finalizing yesterday at midnight).
  Future<int> createOrUpdateDailyRecord({String? forDate}) async {
    final now = DateTime.now();
    final targetDate = forDate ?? DateFormat('yyyy-MM-dd').format(now);
    final score = await _calculateScoreForDate(targetDate);
    if (score.totalWeight == 0) return -1;

    final db = await _db.database;

    final existing = await db.query(
      DatabaseTables.record,
      where:
          '${DatabaseColumns.recordType} = ? AND ${DatabaseColumns.recordText} LIKE ?',
      whereArgs: [RecordType.productivity.toDbValue(), '%"date":"$targetDate"%'],
      limit: 1,
    );

    final jsonText = jsonEncode(score.toJson());
    final title = 'Productivity: ${score.score.toStringAsFixed(1)}/10';

    if (existing.isNotEmpty) {
      final recordId = existing.first[DatabaseColumns.id] as int;
      await db.update(
        DatabaseTables.record,
        {
          DatabaseColumns.recordTitle: title,
          DatabaseColumns.recordText: jsonText,
        },
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [recordId],
      );
      log('[ProductivityService] Updated daily record #$recordId: ${score.score.toStringAsFixed(1)}');
      _productivityUpdatedController.add(recordId);
      _productivityScoreUpdatedController.add(score);
      return recordId;
    } else {
      final recordId = await _db.insertRecord({
        DatabaseColumns.recordTitle: title,
        DatabaseColumns.recordText: jsonText,
        DatabaseColumns.recordCreatedAt:
            DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: RecordType.productivity.toDbValue(),
      }, []);
      log('[ProductivityService] Created daily record #$recordId: ${score.score.toStringAsFixed(1)}');
      _productivityUpdatedController.add(recordId);
      _productivityScoreUpdatedController.add(score);
      return recordId;
    }
  }

  /// Get productivity history records for the chart.
  /// Returns scores sorted by date ascending.
  Future<List<ProductivityScore>> getHistory({int days = 30}) async {
    final db = await _db.database;

    final records = await db.query(
      DatabaseTables.record,
      where: '${DatabaseColumns.recordType} = ?',
      whereArgs: [RecordType.productivity.toDbValue()],
      orderBy: '${DatabaseColumns.recordCreatedAt} ASC',
    );

    final scores = <ProductivityScore>[];
    for (final record in records) {
      try {
        final text = record[DatabaseColumns.recordText] as String? ?? '';
        if (text.trim().startsWith('{')) {
          final json = jsonDecode(text) as Map<String, dynamic>;
          scores.add(ProductivityScore.fromJson(json));
        }
      } catch (e) {
        log('[ProductivityService] Error parsing record: $e');
      }
    }

    if (days > 0 && scores.length > days) {
      return scores.sublist(scores.length - days);
    }
    return scores;
  }
}
