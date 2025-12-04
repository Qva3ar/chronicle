import '../db_manager.dart';

/// Types of reminders for todos
enum TodoReminderType {
  oneHourBefore('1_hour_before', '1 hour before'),
  oneDayBefore('1_day_before', '1 day before'),
  morningOfDay('morning_of_day', 'Morning of the day'),
  custom('custom', 'Custom time');

  final String value;
  final String displayName;

  const TodoReminderType(this.value, this.displayName);

  static TodoReminderType fromString(String value) {
    return TodoReminderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TodoReminderType.custom,
    );
  }
}

@pragma('vm:entry-point')
class TodoReminder {
  final int? id;
  final int todoId;
  final TodoReminderType reminderType;
  final int? customOffsetMinutes; // For custom reminders
  final DateTime? scheduledAt; // When the reminder should trigger

  TodoReminder({
    this.id,
    required this.todoId,
    required this.reminderType,
    this.customOffsetMinutes,
    this.scheduledAt,
  });

  // Display name for the reminder
  String get displayName {
    if (reminderType == TodoReminderType.custom && customOffsetMinutes != null) {
      final hours = customOffsetMinutes! ~/ 60;
      final minutes = customOffsetMinutes! % 60;
      if (hours > 0 && minutes > 0) {
        return '$hours hour${hours > 1 ? 's' : ''} $minutes min before';
      } else if (hours > 0) {
        return '$hours hour${hours > 1 ? 's' : ''} before';
      } else {
        return '$minutes min before';
      }
    }
    return reminderType.displayName;
  }

  // Convert from database map
  factory TodoReminder.fromMap(Map<String, dynamic> map) {
    return TodoReminder(
      id: map[DatabaseColumns.id],
      todoId: map[DatabaseColumns.todoReminderTodoId] ?? 0,
      reminderType: TodoReminderType.fromString(
          map[DatabaseColumns.todoReminderType] ?? ''),
      customOffsetMinutes: map[DatabaseColumns.todoReminderCustomOffsetMinutes],
      scheduledAt: map[DatabaseColumns.todoReminderScheduledAt] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map[DatabaseColumns.todoReminderScheduledAt])
          : null,
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseColumns.id: id,
      DatabaseColumns.todoReminderTodoId: todoId,
      DatabaseColumns.todoReminderType: reminderType.value,
      DatabaseColumns.todoReminderCustomOffsetMinutes: customOffsetMinutes,
      DatabaseColumns.todoReminderScheduledAt:
          scheduledAt?.millisecondsSinceEpoch,
    };
  }

  // Copy with changes
  TodoReminder copyWith({
    int? id,
    int? todoId,
    TodoReminderType? reminderType,
    int? customOffsetMinutes,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
  }) {
    return TodoReminder(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      reminderType: reminderType ?? this.reminderType,
      customOffsetMinutes: customOffsetMinutes ?? this.customOffsetMinutes,
      scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
    );
  }

  @override
  String toString() {
    return 'TodoReminder(id: $id, todoId: $todoId, type: ${reminderType.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoReminder &&
        other.id == id &&
        other.todoId == todoId &&
        other.reminderType == reminderType;
  }

  @override
  int get hashCode {
    return id.hashCode ^ todoId.hashCode ^ reminderType.hashCode;
  }
}
