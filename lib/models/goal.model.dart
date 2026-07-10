import '../db_manager.dart';

@pragma('vm:entry-point')
class Goal {
  final int? id;
  final String title;
  final int hours;
  final int minutes;
  final int sessionMinutes;
  final bool isActive;
  final int timeSpentSeconds; // Total time spent on this goal
  final int? sessionResumedTimestampSeconds; // Added field
  final int? completedAt; // Added field
  final int? archivedAt; // Manual completion/hide (does NOT reset daily)
  final bool isPrimary;
  final bool createdFromOnboarding;
  final int? currentDayRecordId; // ID of the record created for today's work
  final int priority;
  final List<bool> daysOfWeek; // 7 flags, Monday-first (index 0 = Monday)

  Goal({
    this.id,
    required this.title,
    required this.hours,
    required this.minutes,
    required this.sessionMinutes,
    this.isActive = false,
    this.timeSpentSeconds = 0,
    this.sessionResumedTimestampSeconds,
    this.completedAt,
    this.archivedAt,
    this.isPrimary = false,
    this.createdFromOnboarding = false,
    this.currentDayRecordId,
    this.priority = 2,
    this.daysOfWeek = const [true, true, true, true, true, true, true],
  });

  /// Whether this goal is scheduled for the given weekday.
  /// [dayIndex] is 0-based, Monday = 0 (matches `DateTime.weekday - 1`).
  bool isActiveOnDay(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= daysOfWeek.length) return true;
    return daysOfWeek[dayIndex];
  }

  // Total goal time in seconds
  int get totalSeconds => (hours * 3600) + (minutes * 60);

  // Progress percentage (0.0 to 1.0)
  double get progress => totalSeconds > 0
      ? (timeSpentSeconds / totalSeconds).clamp(0.0, 1.0)
      : 0.0;

  // Check if goal is completed
  bool get isCompleted => timeSpentSeconds >= totalSeconds;

  bool get isArchived => archivedAt != null;

  // Formatted time strings
  String get formattedGoalTime {
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedSessionTime {
    final h = sessionMinutes ~/ 60;
    final m = sessionMinutes % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m';
  }

  String get formattedTimeSpent {
    final h = timeSpentSeconds ~/ 3600;
    final m = (timeSpentSeconds % 3600) ~/ 60;
    final s = timeSpentSeconds % 60;

    // Always show hh:mm:ss format
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Convert from database map
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map[DatabaseColumns.id],
      title: map[DatabaseColumns.goalTitle] ?? '',
      hours: map[DatabaseColumns.goalHours] ?? 0,
      minutes: map[DatabaseColumns.goalMinutes] ?? 0,
      sessionMinutes: map[DatabaseColumns.goalSessionMinutes] ?? 25,
      isActive: (map[DatabaseColumns.goalIsActive] ?? 0) == 1,
      timeSpentSeconds: map[DatabaseColumns.goalTimeSpentSeconds] ?? 0,
      sessionResumedTimestampSeconds:
          map[DatabaseColumns.goalSessionResumedTimestampSeconds],
      completedAt: map[DatabaseColumns.goalCompletedAt],
      archivedAt: map[DatabaseColumns.goalArchivedAt],
      isPrimary: (map[DatabaseColumns.goalIsPrimary] ?? 0) == 1,
      createdFromOnboarding:
          (map[DatabaseColumns.goalCreatedFromOnboarding] ?? 0) == 1,
      currentDayRecordId: map[DatabaseColumns.goalCurrentDayRecordId],
      priority: map[DatabaseColumns.goalPriority] as int? ?? 2,
      daysOfWeek: _parseDaysOfWeek(map[DatabaseColumns.goalDaysOfWeek]),
    );
  }

  /// Parse the `days_of_week` string ("1,0,1,...") into 7 flags.
  /// Defaults to every day when missing or malformed (backward compatible
  /// with goals created before day-of-week scheduling existed).
  static List<bool> _parseDaysOfWeek(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      final parts = raw.split(',');
      if (parts.length == 7) {
        return parts.map((p) => p == '1').toList();
      }
    }
    return const [true, true, true, true, true, true, true];
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseColumns.id: id,
      DatabaseColumns.goalTitle: title,
      DatabaseColumns.goalHours: hours,
      DatabaseColumns.goalMinutes: minutes,
      DatabaseColumns.goalSessionMinutes: sessionMinutes,
      DatabaseColumns.goalIsActive: isActive ? 1 : 0,
      DatabaseColumns.goalTimeSpentSeconds: timeSpentSeconds,
      DatabaseColumns.goalSessionResumedTimestampSeconds:
          sessionResumedTimestampSeconds,
      DatabaseColumns.goalCompletedAt: completedAt,
      DatabaseColumns.goalArchivedAt: archivedAt,
      DatabaseColumns.goalIsPrimary: isPrimary ? 1 : 0,
      DatabaseColumns.goalCreatedFromOnboarding: createdFromOnboarding ? 1 : 0,
      DatabaseColumns.goalCurrentDayRecordId: currentDayRecordId,
      DatabaseColumns.goalPriority: priority,
      DatabaseColumns.goalDaysOfWeek:
          daysOfWeek.map((day) => day ? '1' : '0').join(','),
    };
  }

  // Copy with changes
  Goal copyWith({
    int? id,
    String? title,
    int? hours,
    int? minutes,
    int? sessionMinutes,
    bool? isActive,
    int? timeSpentSeconds,
    int? sessionResumedTimestampSeconds, // Added parameter
    int? completedAt, // Added parameter
    int? archivedAt,
    bool clearArchivedAt = false,
    bool clearSessionResumedTimestamp = false, // Added helper parameter
    bool? isPrimary,
    bool? createdFromOnboarding,
    int? currentDayRecordId,
    bool clearCurrentDayRecordId = false,
    int? priority,
    List<bool>? daysOfWeek,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      hours: hours ?? this.hours,
      minutes: minutes ?? this.minutes,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      isActive: isActive ?? this.isActive,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      completedAt: completedAt ?? this.completedAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      sessionResumedTimestampSeconds: clearSessionResumedTimestamp
          ? null
          : (sessionResumedTimestampSeconds ??
              this.sessionResumedTimestampSeconds),
      isPrimary: isPrimary ?? this.isPrimary,
      createdFromOnboarding:
          createdFromOnboarding ?? this.createdFromOnboarding,
      currentDayRecordId: clearCurrentDayRecordId
          ? null
          : (currentDayRecordId ?? this.currentDayRecordId),
      priority: priority ?? this.priority,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }

  @override
  String toString() {
    return 'Goal(id: $id, title: $title, hours: $hours, minutes: $minutes, isActive: $isActive, isPrimary: $isPrimary)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Goal &&
        other.id == id &&
        other.title == title &&
        other.hours == hours &&
        other.minutes == minutes &&
        other.sessionMinutes == sessionMinutes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        hours.hashCode ^
        minutes.hashCode ^
        sessionMinutes.hashCode;
  }
}
