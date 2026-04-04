/// Enum representing different types of records in the database
enum RecordType {
  /// Regular note/record
  regular,

  /// Routine completion record
  routine,

  /// Goal completion record
  goal,

  /// Morning checkin record
  morningCheckin,

  /// Evening checkin record
  eveningCheckin,

  /// Daily productivity score record
  productivity,

  /// Todo completion record
  todo,
}

/// Extension methods for RecordType enum
extension RecordTypeExtension on RecordType {
  /// Convert enum to database string value
  String toDbValue() {
    switch (this) {
      case RecordType.regular:
        return 'regular';
      case RecordType.routine:
        return 'routine';
      case RecordType.goal:
        return 'goal';
      case RecordType.morningCheckin:
        return 'morning_checkin';
      case RecordType.eveningCheckin:
        return 'evening_checkin';
      case RecordType.productivity:
        return 'productivity';
      case RecordType.todo:
        return 'todo';
    }
  }

  /// Get human-readable display name
  String get displayName {
    switch (this) {
      case RecordType.regular:
        return 'Заметка';
      case RecordType.routine:
        return 'Рутина';
      case RecordType.goal:
        return 'Цель';
      case RecordType.morningCheckin:
        return 'Утренний чекин';
      case RecordType.eveningCheckin:
        return 'Вечерний чекин';
      case RecordType.productivity:
        return 'Продуктивность';
      case RecordType.todo:
        return 'Todo';
    }
  }
}

/// Parse database string value to RecordType enum
RecordType recordTypeFromDbValue(String value) {
  switch (value) {
    case 'regular':
      return RecordType.regular;
    case 'routine':
      return RecordType.routine;
    case 'goal':
      return RecordType.goal;
    case 'morning_checkin':
      return RecordType.morningCheckin;
    case 'evening_checkin':
      return RecordType.eveningCheckin;
    case 'productivity':
      return RecordType.productivity;
    case 'todo':
      return RecordType.todo;
    default:
      return RecordType.regular; // Default fallback
  }
}
