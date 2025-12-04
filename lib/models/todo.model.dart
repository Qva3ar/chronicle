import '../db_manager.dart';

@pragma('vm:entry-point')
class Todo {
  final int? id;
  final String title;
  final String? description;
  final bool isDone;
  final DateTime? targetDateTime;
  final DateTime createdAt;
  final DateTime? completedAt;

  Todo({
    this.id,
    required this.title,
    this.description,
    this.isDone = false,
    this.targetDateTime,
    required this.createdAt,
    this.completedAt,
  });

  // Check if todo has a target time
  bool get hasTargetTime => targetDateTime != null;

  // Check if todo is overdue
  bool get isOverdue {
    if (!hasTargetTime || isDone) return false;
    return DateTime.now().isAfter(targetDateTime!);
  }

  // Formatted date strings
  String get formattedTargetDate {
    if (!hasTargetTime) return '';

    final now = DateTime.now();
    final target = targetDateTime!;
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDay = DateTime(target.year, target.month, target.day);

    if (targetDay == today) {
      return 'Today at ${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
    } else if (targetDay == tomorrow) {
      return 'Tomorrow at ${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
    } else {
      return '${target.day}/${target.month}/${target.year} at ${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
    }
  }

  // Convert from database map
  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map[DatabaseColumns.id],
      title: map[DatabaseColumns.todoTitle] ?? '',
      description: map[DatabaseColumns.todoDescription],
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
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseColumns.id: id,
      DatabaseColumns.todoTitle: title,
      DatabaseColumns.todoDescription: description,
      DatabaseColumns.todoIsDone: isDone ? 1 : 0,
      DatabaseColumns.todoTargetDateTime:
          targetDateTime?.millisecondsSinceEpoch,
      DatabaseColumns.todoCreatedAt: createdAt.millisecondsSinceEpoch,
      DatabaseColumns.todoCompletedAt: completedAt?.millisecondsSinceEpoch,
    };
  }

  // Copy with changes
  Todo copyWith({
    int? id,
    String? title,
    String? description,
    bool? isDone,
    DateTime? targetDateTime,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearTargetDateTime = false,
    bool clearDescription = false,
    bool clearCompletedAt = false,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      isDone: isDone ?? this.isDone,
      targetDateTime:
          clearTargetDateTime ? null : (targetDateTime ?? this.targetDateTime),
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, isDone: $isDone, targetDateTime: $targetDateTime)';
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
