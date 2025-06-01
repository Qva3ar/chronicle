class Goal {
  final int? id;
  final String title;
  final int hours;
  final int minutes;
  final int sessionMinutes;
  final bool isActive;
  final int timeSpentSeconds; // Total time spent on this goal

  Goal({
    this.id,
    required this.title,
    required this.hours,
    required this.minutes,
    required this.sessionMinutes,
    this.isActive = false,
    this.timeSpentSeconds = 0,
  });

  // Total goal time in seconds
  int get totalSeconds => (hours * 3600) + (minutes * 60);

  // Progress percentage (0.0 to 1.0)
  double get progress => totalSeconds > 0 ? (timeSpentSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

  // Check if goal is completed
  bool get isCompleted => timeSpentSeconds >= totalSeconds;

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
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m';
  }

  // Convert from database map
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['_id'] ?? map['id'],
      title: map['title'] ?? '',
      hours: map['hours'] ?? 0,
      minutes: map['minutes'] ?? 0,
      sessionMinutes: map['session_minutes'] ?? 25,
      isActive: (map['is_active'] ?? 0) == 1,
      timeSpentSeconds: map['time_spent_seconds'] ?? 0,
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'title': title,
      'hours': hours,
      'minutes': minutes,
      'session_minutes': sessionMinutes,
      'is_active': isActive ? 1 : 0,
      'time_spent_seconds': timeSpentSeconds,
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
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      hours: hours ?? this.hours,
      minutes: minutes ?? this.minutes,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      isActive: isActive ?? this.isActive,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
    );
  }

  @override
  String toString() {
    return 'Goal(id: $id, title: $title, hours: $hours, minutes: $minutes, isActive: $isActive)';
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
