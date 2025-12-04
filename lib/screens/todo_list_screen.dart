import 'package:flutter/material.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/todo_service.dart';
import 'package:chrono/services/todo_notification_service.dart';
import 'package:chrono/screens/todo_edit_screen.dart';
import 'package:chrono/colors.dart';

class TodoListScreen extends StatefulWidget {
  final int? highlightTodoId; // To highlight a specific todo when opened from notification

  const TodoListScreen({super.key, this.highlightTodoId});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  late final TodoService _todoService;
  late final TodoNotificationService _notificationService;

  List<Todo> _activeTodos = [];
  List<Todo> _completedTodos = [];
  bool _showCompleted = true;

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(_db);
    _notificationService = TodoNotificationService();
    _notificationService.initialize();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final activeTodos = await _todoService.getActiveTodos();
    final completedTodos = await _todoService.getCompletedTodos();

    setState(() {
      _activeTodos = activeTodos;
      _completedTodos = completedTodos;
    });
  }

  Future<void> _toggleTodoCompletion(Todo todo) async {
    await _todoService.toggleTodoCompletion(todo);

    // If completing, cancel notifications
    if (!todo.isDone) {
      final reminders = await _todoService.getTodoReminders(todo.id!);
      await _notificationService.cancelTodoNotifications(todo.id!, reminders);
    }

    await _loadTodos();
  }

  Future<void> _deleteTodo(Todo todo) async {
    // Cancel notifications first
    final reminders = await _todoService.getTodoReminders(todo.id!);
    await _notificationService.cancelTodoNotifications(todo.id!, reminders);

    // Delete todo
    await _todoService.deleteTodo(todo.id!);
    await _loadTodos();
  }

  Future<void> _showTodoForm([Todo? todo]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodoEditScreen(existingTodo: todo),
      ),
    );

    if (result == true) {
      await _loadTodos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MyColors.forthyColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Todo List',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showCompleted ? Icons.visibility : Icons.visibility_off,
                        color: white,
                      ),
                      onPressed: () {
                        setState(() {
                          _showCompleted = !_showCompleted;
                        });
                      },
                      tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: white),
                      onPressed: () => _showTodoForm(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Todo list
          Expanded(
            child: _activeTodos.isEmpty && _completedTodos.isEmpty
                ? const Center(
                    child: Text(
                      'No todos yet\nTap + to create one',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MyColors.fivyColor,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Active todos
                      if (_activeTodos.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, top: 8),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MyColors.fivyColor,
                            ),
                          ),
                        ),
                        ..._activeTodos.map((todo) => _buildTodoItem(todo)),
                      ],
                      // Completed todos
                      if (_showCompleted && _completedTodos.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: 8,
                            top: _activeTodos.isNotEmpty ? 16 : 8,
                          ),
                          child: const Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MyColors.fivyColor,
                            ),
                          ),
                        ),
                        ..._completedTodos.map((todo) => _buildTodoItem(todo)),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(Todo todo) {
    final isHighlighted = widget.highlightTodoId == todo.id;

    return Dismissible(
      key: Key('todo_${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteTodo(todo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isHighlighted ? MyColors.primaryColor.withValues(alpha: 0.1) : cardColor2,
          borderRadius: BorderRadius.circular(10),
          border: isHighlighted
              ? Border.all(color: MyColors.primaryColor, width: 2)
              : null,
        ),
        child: ListTile(
          leading: Checkbox(
            value: todo.isDone,
            onChanged: (_) => _toggleTodoCompletion(todo),
            activeColor: Colors.green,
            checkColor: Colors.white,
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              color: todo.isDone ? MyColors.forthyColor : white,
              decoration: todo.isDone ? TextDecoration.lineThrough : null,
              fontSize: 16,
            ),
          ),
          subtitle: todo.hasTargetTime || todo.description != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (todo.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        todo.description!,
                        style: TextStyle(
                          color: todo.isDone
                              ? MyColors.forthyColor
                              : MyColors.fivyColor,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (todo.hasTargetTime) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: todo.isOverdue
                                ? Colors.red
                                : MyColors.forthyColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            todo.formattedTargetDate,
                            style: TextStyle(
                              color: todo.isOverdue
                                  ? Colors.red
                                  : MyColors.forthyColor,
                              fontSize: 12,
                              fontWeight: todo.isOverdue
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.edit, color: MyColors.forthyColor),
            onPressed: () => _showTodoForm(todo),
          ),
          onTap: () => _showTodoForm(todo),
        ),
      ),
    );
  }
}
