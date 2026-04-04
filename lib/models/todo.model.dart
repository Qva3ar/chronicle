import '../db_manager.dart';

enum TodoType {
  tomorrow('tomorrow'),
  deadline('deadline'),
  noDate('no_date');

  final String value;
  const TodoType(this.value);

  static TodoType fromString(String value) {
    return TodoType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TodoType.noDate,
    );
  }
}

@pragma('vm:entry-point')
class Todo {
  final int? id;
  final String title;
  final bool isDone;
  final DateTime? targetDateTime;
  final DateTime createdAt;
  final DateTime? completedAt;
  final TodoType todoType;
  final bool dailyReminderEnabled;
  final String? dailyReminderTime; // "HH:mm" format
  final int? reminderPeriodMinutes; // repeat: total period before reminder time
  final int? reminderIntervalMinutes; // repeat: interval between notifications

  Todo({
    this.id,
    required this.title,
    this.isDone = false,
    this.targetDateTime,
    required this.createdAt,
    this.completedAt,
    this.todoType = TodoType.noDate,
    this.dailyReminderEnabled = false,
    this.dailyReminderTime,
    this.reminderPeriodMinutes,
    this.reminderIntervalMinutes,
  });

  /// Number of repeat notifications based on period and interval.
  /// E.g. period=60, interval=30 → notifications at time-60, time-30, time → 3 total.
  int get repeatNotificationCount {
    if (reminderPeriodMinutes == null ||
        reminderIntervalMinutes == null ||
        reminderPeriodMinutes! <= 0 ||
        reminderIntervalMinutes! <= 0) {
      return 1; // just the main notification
    }
    return (reminderPeriodMinutes! ~/ reminderIntervalMinutes!) + 1;
  }

  bool get isOverdue {
    if (isDone) return false;
    if (todoType == TodoType.noDate) return false;
    if (targetDateTime == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      targetDateTime!.year,
      targetDateTime!.month,
      targetDateTime!.day,
    );
    return todayStart.isAfter(targetDay);
  }

  String get formattedTargetDate {
    if (todoType == TodoType.tomorrow) {
      if (isOverdue) {
        final t = targetDateTime!;
        return '${t.day}/${t.month}/${t.year}';
      }
      return 'Tomorrow';
    }
    if (todoType == TodoType.deadline && targetDateTime != null) {
      final t = targetDateTime!;
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${t.day} ${months[t.month - 1]} ${t.year}';
    }
    return '';
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    // Infer todoType from data if not present (backward compat with old exports)
    String typeStr = map[DatabaseColumns.todoType] ?? 'no_date';
    if (typeStr == 'no_date' &&
        map[DatabaseColumns.todoTargetDateTime] != null &&
        map[DatabaseColumns.todoType] == null) {
      typeStr = 'deadline';
    }

    return Todo(
      id: map[DatabaseColumns.id],
      title: map[DatabaseColumns.todoTitle] ?? '',
      isDone: (map[DatabaseColumns.todoIsDone] ?? 0) == 1,
      targetDateTime: map[DatabaseColumns.todoTargetDateTime] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map[DatabaseColumns.todoTargetDateTime])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          map[DatabaseColumns.todoCreatedAt]),
      completedAt: map[DatabaseColumns.todoCompletedAt] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map[DatabaseColumns.todoCompletedAt])
          : null,
      todoType: TodoType.fromString(typeStr),
      dailyReminderEnabled:
          (map[DatabaseColumns.todoDailyReminderEnabled] ?? 0) == 1,
      dailyReminderTime: map[DatabaseColumns.todoDailyReminderTime],
      reminderPeriodMinutes: map[DatabaseColumns.todoReminderPeriodMinutes],
      reminderIntervalMinutes: map[DatabaseColumns.todoReminderIntervalMinutes],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseColumns.id: id,
      DatabaseColumns.todoTitle: title,
      DatabaseColumns.todoIsDone: isDone ? 1 : 0,
      DatabaseColumns.todoTargetDateTime:
          targetDateTime?.millisecondsSinceEpoch,
      DatabaseColumns.todoCreatedAt: createdAt.millisecondsSinceEpoch,
      DatabaseColumns.todoCompletedAt: completedAt?.millisecondsSinceEpoch,
      DatabaseColumns.todoType: todoType.value,
      DatabaseColumns.todoDailyReminderEnabled: dailyReminderEnabled ? 1 : 0,
      DatabaseColumns.todoDailyReminderTime: dailyReminderTime,
      DatabaseColumns.todoReminderPeriodMinutes: reminderPeriodMinutes,
      DatabaseColumns.todoReminderIntervalMinutes: reminderIntervalMinutes,
    };
  }

  Todo copyWith({
    int? id,
    String? title,
    bool? isDone,
    DateTime? targetDateTime,
    DateTime? createdAt,
    DateTime? completedAt,
    TodoType? todoType,
    bool? dailyReminderEnabled,
    String? dailyReminderTime,
    int? reminderPeriodMinutes,
    int? reminderIntervalMinutes,
    bool clearTargetDateTime = false,
    bool clearCompletedAt = false,
    bool clearDailyReminderTime = false,
    bool clearReminderPeriod = false,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      targetDateTime:
          clearTargetDateTime ? null : (targetDateTime ?? this.targetDateTime),
      createdAt: createdAt ?? this.createdAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      todoType: todoType ?? this.todoType,
      dailyReminderEnabled:
          dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderTime: clearDailyReminderTime
          ? null
          : (dailyReminderTime ?? this.dailyReminderTime),
      reminderPeriodMinutes: clearReminderPeriod
          ? null
          : (reminderPeriodMinutes ?? this.reminderPeriodMinutes),
      reminderIntervalMinutes: clearReminderPeriod
          ? null
          : (reminderIntervalMinutes ?? this.reminderIntervalMinutes),
    );
  }

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, type: ${todoType.value}, isDone: $isDone, targetDateTime: $targetDateTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        other.id == id &&
        other.title == title &&
        other.isDone == isDone;
  }

  @override
  int get hashCode {
    return id.hashCode ^ title.hashCode ^ isDone.hashCode;
  }
}
