import 'package:chrono/db_manager.dart';
import 'package:chrono/models/todo.model.dart';

class TodoService {
  final DatabaseHelper _dbManager;

  TodoService(this._dbManager);

  Future<List<Todo>> getAllTodos() async {
    return await _dbManager.getAllTodos();
  }

  Future<List<Todo>> getActiveTodos() async {
    return await _dbManager.getActiveTodos();
  }

  Future<List<Todo>> getCompletedTodos() async {
    return await _dbManager.getCompletedTodos();
  }

  Future<Todo?> getTodo(int id) async {
    return await _dbManager.getTodo(id);
  }

  Future<int> createTodo(
    String title, {
    required TodoType todoType,
    DateTime? targetDateTime,
    bool dailyReminderEnabled = false,
    String? dailyReminderTime,
    int? reminderPeriodMinutes,
    int? reminderIntervalMinutes,
  }) async {
    // For tomorrow type, auto-compute target date
    DateTime? effectiveTarget = targetDateTime;
    if (todoType == TodoType.tomorrow) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      effectiveTarget = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59);
    }

    final hasReminder = todoType != TodoType.noDate && dailyReminderEnabled;

    final todo = Todo(
      title: title,
      todoType: todoType,
      targetDateTime: effectiveTarget,
      createdAt: DateTime.now(),
      dailyReminderEnabled: hasReminder,
      dailyReminderTime: hasReminder ? dailyReminderTime : null,
      reminderPeriodMinutes: hasReminder ? reminderPeriodMinutes : null,
      reminderIntervalMinutes: hasReminder ? reminderIntervalMinutes : null,
    );

    return await _dbManager.insertTodo(todo);
  }

  Future<void> updateTodo(Todo todo) async {
    await _dbManager.updateTodo(todo);
  }

  /// Toggle todo completion. Creates a record on check, deletes it on uncheck.
  Future<void> toggleTodoCompletion(Todo todo) async {
    final completing = !todo.isDone;

    final updatedTodo = todo.copyWith(
      isDone: completing,
      completedAt: completing ? DateTime.now() : null,
      clearCompletedAt: !completing,
    );
    await _dbManager.updateTodo(updatedTodo);

    if (completing) {
      // Create completion record
      await _dbManager.insertTodoCompletionRecord(todo.id!, todo.title);
    } else {
      // Delete completion record
      await _dbManager.deleteTodoCompletionRecord(todo.id!);
    }
  }

  Future<void> deleteTodo(int id) async {
    // Also clean up any completion record
    await _dbManager.deleteTodoCompletionRecord(id);
    await _dbManager.deleteTodo(id);
  }

  Future<List<Todo>> getTodosWithActiveReminders() async {
    return await _dbManager.getTodosWithActiveReminders();
  }
}
