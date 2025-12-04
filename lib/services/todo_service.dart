import 'package:chrono/db_manager.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/models/todo_reminder.model.dart';

class TodoService {
  final DatabaseHelper _dbManager;

  TodoService(this._dbManager);

  /// Get all todos (active and completed)
  Future<List<Todo>> getAllTodos() async {
    return await _dbManager.getAllTodos();
  }

  /// Get only active (not completed) todos
  Future<List<Todo>> getActiveTodos() async {
    return await _dbManager.getActiveTodos();
  }

  /// Get only completed todos
  Future<List<Todo>> getCompletedTodos() async {
    return await _dbManager.getCompletedTodos();
  }

  /// Get a specific todo by id
  Future<Todo?> getTodo(int id) async {
    return await _dbManager.getTodo(id);
  }

  /// Create a new todo with optional reminders
  Future<int> createTodo(
    String title, {
    String? description,
    DateTime? targetDateTime,
    List<TodoReminderType>? reminderTypes,
    int? customReminderOffsetMinutes,
  }) async {
    final todo = Todo(
      title: title,
      description: description,
      targetDateTime: targetDateTime,
      createdAt: DateTime.now(),
    );

    final todoId = await _dbManager.insertTodo(todo);

    // Add reminders if target date is set and reminders are specified
    if (targetDateTime != null && reminderTypes != null && reminderTypes.isNotEmpty) {
      await _addReminders(todoId, targetDateTime, reminderTypes, customReminderOffsetMinutes);
    }

    return todoId;
  }

  /// Update an existing todo and its reminders
  Future<void> updateTodo(
    Todo todo, {
    List<TodoReminderType>? reminderTypes,
    int? customReminderOffsetMinutes,
  }) async {
    await _dbManager.updateTodo(todo);

    // Update reminders if target date is set
    if (todo.targetDateTime != null && reminderTypes != null) {
      // Remove old reminders
      await _dbManager.deleteTodoRemindersByTodoId(todo.id!);

      // Add new reminders
      if (reminderTypes.isNotEmpty) {
        await _addReminders(
          todo.id!,
          todo.targetDateTime!,
          reminderTypes,
          customReminderOffsetMinutes,
        );
      }
    } else if (todo.targetDateTime == null) {
      // If target date is removed, remove all reminders
      await _dbManager.deleteTodoRemindersByTodoId(todo.id!);
    }
  }

  /// Toggle todo completion status
  Future<void> toggleTodoCompletion(Todo todo) async {
    final updatedTodo = todo.copyWith(
      isDone: !todo.isDone,
      completedAt: !todo.isDone ? DateTime.now() : null,
      clearCompletedAt: todo.isDone, // Clear if unchecking
    );
    await _dbManager.updateTodo(updatedTodo);
  }

  /// Delete a todo (reminders will be deleted automatically via CASCADE)
  Future<void> deleteTodo(int id) async {
    await _dbManager.deleteTodo(id);
  }

  /// Get reminders for a specific todo
  Future<List<TodoReminder>> getTodoReminders(int todoId) async {
    return await _dbManager.getTodoReminders(todoId);
  }

  /// Add reminders for a todo
  Future<void> _addReminders(
    int todoId,
    DateTime targetDateTime,
    List<TodoReminderType> reminderTypes,
    int? customOffsetMinutes,
  ) async {
    for (final reminderType in reminderTypes) {
      DateTime? scheduledAt;
      int? offsetMinutes;

      switch (reminderType) {
        case TodoReminderType.oneHourBefore:
          scheduledAt = targetDateTime.subtract(const Duration(hours: 1));
          break;
        case TodoReminderType.oneDayBefore:
          scheduledAt = targetDateTime.subtract(const Duration(days: 1));
          break;
        case TodoReminderType.morningOfDay:
          // Schedule for 8 AM on the day of the todo
          scheduledAt = DateTime(
            targetDateTime.year,
            targetDateTime.month,
            targetDateTime.day,
            8,
            0,
          );
          break;
        case TodoReminderType.custom:
          if (customOffsetMinutes != null && customOffsetMinutes > 0) {
            scheduledAt = targetDateTime.subtract(Duration(minutes: customOffsetMinutes));
            offsetMinutes = customOffsetMinutes;
          }
          break;
      }

      // Only add reminder if scheduledAt is in the future
      if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
        final reminder = TodoReminder(
          todoId: todoId,
          reminderType: reminderType,
          customOffsetMinutes: offsetMinutes,
          scheduledAt: scheduledAt,
        );
        await _dbManager.insertTodoReminder(reminder);
      }
    }
  }

  /// Get todos that need reminders to be sent (scheduled time has passed)
  Future<List<TodoReminder>> getPendingReminders() async {
    final db = await _dbManager.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final maps = await db.rawQuery('''
      SELECT r.* FROM ${DatabaseTables.todoReminders} r
      INNER JOIN ${DatabaseTables.todos} t ON r.${DatabaseColumns.todoReminderTodoId} = t.${DatabaseColumns.id}
      WHERE r.${DatabaseColumns.todoReminderScheduledAt} <= ?
      AND t.${DatabaseColumns.todoIsDone} = 0
      ORDER BY r.${DatabaseColumns.todoReminderScheduledAt} ASC
    ''', [now]);

    return maps.map((map) => TodoReminder.fromMap(map)).toList();
  }
}
