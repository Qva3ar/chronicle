import 'package:flutter/material.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/todo_service.dart';
import 'package:chrono/services/todo_notification_service.dart';
import 'package:chrono/screens/todo_edit_screen.dart';
import 'package:chrono/services/filter_service.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/shared/chrono_ui.dart';
import 'package:chrono/shared/premium_gate.dart';

class TodoListScreen extends StatefulWidget {
  final int? highlightTodoId;
  final ScrollController? sheetScrollController;

  const TodoListScreen({super.key, this.highlightTodoId, this.sheetScrollController});

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
    final showCompleted = await FilterService.instance.getShowCompletedTodos();

    if (mounted) {
      setState(() {
        _activeTodos = activeTodos;
        _completedTodos = completedTodos;
        _showCompleted = showCompleted;
      });
    }
  }

  List<Widget> _buildGroupedTodos() {
    final List<Widget> widgets = [];

    final tomorrow = <Todo>[];
    final deadline = <Todo>[];
    final noDate = <Todo>[];
    final overdue = <Todo>[];

    for (final todo in _activeTodos) {
      if (todo.isOverdue) {
        overdue.add(todo);
      } else if (todo.todoType == TodoType.tomorrow) {
        tomorrow.add(todo);
      } else if (todo.todoType == TodoType.deadline) {
        deadline.add(todo);
      } else {
        noDate.add(todo);
      }
    }

    // Sort deadline by target date (soonest first)
    deadline.sort((a, b) {
      if (a.targetDateTime == null) return 1;
      if (b.targetDateTime == null) return -1;
      return a.targetDateTime!.compareTo(b.targetDateTime!);
    });

    // Sort overdue by target date (most recent first)
    overdue.sort((a, b) {
      if (a.targetDateTime == null) return 1;
      if (b.targetDateTime == null) return -1;
      return b.targetDateTime!.compareTo(a.targetDateTime!);
    });

    // Tomorrow section
    if (tomorrow.isNotEmpty) {
      widgets.add(
        ChronoSectionHeader(
          icon: Icons.wb_sunny_outlined,
          iconColor: MyColors.orangeDivider,
          label: 'TOMORROW',
          count: tomorrow.length,
          countColor: MyColors.orangeDivider,
        ),
      );
      for (final todo in tomorrow) {
        widgets.add(_buildTodoItem(todo));
      }
      widgets.add(const SizedBox(height: 8));
    }

    // Deadline section
    if (deadline.isNotEmpty) {
      widgets.add(
        ChronoSectionHeader(
          icon: Icons.flag_outlined,
          iconColor: infoColor,
          label: 'DEADLINE',
          count: deadline.length,
          countColor: infoColor,
        ),
      );
      for (final todo in deadline) {
        widgets.add(_buildTodoItem(todo));
      }
      widgets.add(const SizedBox(height: 8));
    }

    // No Date section
    if (noDate.isNotEmpty) {
      widgets.add(
        ChronoSectionHeader(
          icon: Icons.inbox_outlined,
          iconColor: textMuted,
          label: 'NO DATE',
          count: noDate.length,
          countColor: textMuted,
        ),
      );
      for (final todo in noDate) {
        widgets.add(_buildTodoItem(todo));
      }
      widgets.add(const SizedBox(height: 8));
    }

    // Overdue section (at the bottom)
    if (overdue.isNotEmpty) {
      widgets.add(
        ChronoSectionHeader(
          icon: Icons.warning_amber_rounded,
          iconColor: MyColors.remove,
          label: 'OVERDUE',
          count: overdue.length,
          countColor: MyColors.remove,
        ),
      );
      for (final todo in overdue) {
        widgets.add(_buildTodoItem(todo));
      }
    }

    return widgets;
  }

  Future<void> _toggleTodoCompletion(Todo todo) async {
    await _todoService.toggleTodoCompletion(todo);

    // Cancel reminders if completing
    if (!todo.isDone && todo.dailyReminderEnabled) {
      await _notificationService.cancelTodoReminders(todo.id!);
    }

    await _loadTodos();
  }

  Future<void> _deleteTodo(Todo todo) async {
    // Cancel reminders
    if (todo.dailyReminderEnabled) {
      await _notificationService.cancelTodoReminders(todo.id!);
    }

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

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Todo Types',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              icon: Icons.wb_sunny_outlined,
              color: MyColors.orangeDivider,
              title: 'Tomorrow',
              description: 'Tasks you plan to do tomorrow. Moves to overdue if not completed.',
            ),
            SizedBox(height: 12),
            _InfoRow(
              icon: Icons.flag_outlined,
              color: infoColor,
              title: 'Deadline',
              description: 'Tasks with a specific due date. Enable daily reminders to get notified every day.',
            ),
            SizedBox(height: 12),
            _InfoRow(
              icon: Icons.inbox_outlined,
              color: textMuted,
              title: 'No Date',
              description: 'Backlog tasks without a specific timeframe.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: MyColors.orangeDivider)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ChronoSheetHeader(
      title: 'Todo',
      titleIcon: Icons.checklist_rounded,
      itemCount: _activeTodos.length,
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: textMuted, size: 20),
          onPressed: _showInfoDialog,
          tooltip: 'About todo types',
        ),
        IconButton(
          icon: Icon(
            _showCompleted ? Icons.visibility : Icons.visibility_off,
            color: _showCompleted ? textPrimary : textMuted,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _showCompleted = !_showCompleted;
            });
            FilterService.instance.setShowCompletedTodos(_showCompleted);
          },
          tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
        ),
        IconButton(
          icon: const Icon(Icons.add, color: textPrimary),
          onPressed: () {
            if (!checkPremiumOrShowPaywall(context)) return;
            _showTodoForm();
          },
        ),
      ],
    );
  }

  List<Widget> _buildTodoListChildren() {
    return [
      if (_activeTodos.isNotEmpty) ..._buildGroupedTodos(),
      if (_showCompleted && _completedTodos.isNotEmpty) ...[
        const SizedBox(height: 4),
        ChronoSectionHeader(
          icon: Icons.check_circle_outline,
          iconColor: successColor,
          label: 'COMPLETED',
          count: _completedTodos.length,
          countColor: successColor,
        ),
        ..._completedTodos.map((todo) => _buildTodoItem(todo)),
      ],
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtrl = widget.sheetScrollController;

    if (sheetCtrl != null) {
      final empty = _activeTodos.isEmpty && _completedTodos.isEmpty;
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: cardColor,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: empty
                    ? ListView(
                        controller: sheetCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ChronoEmptyState(
                            icon: Icons.checklist_outlined,
                            title: 'No Todos Yet',
                            subtitle: 'Tap + to create your first todo',
                            buttonLabel: 'Add Todo',
                            onButton: () => _showTodoForm(),
                          ),
                        ],
                      )
                    : ListView(
                        controller: sheetCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: _buildTodoListChildren(),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
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
                    children: _buildTodoListChildren(),
                  ),
          ),
        ],
      ),
    );
  }

  Color _todoIndicatorColor(Todo todo) {
    if (todo.isDone) return successColor;
    if (todo.isOverdue) return MyColors.remove;
    switch (todo.todoType) {
      case TodoType.tomorrow:
        return MyColors.orangeDivider;
      case TodoType.deadline:
        return infoColor;
      case TodoType.noDate:
        return textMuted;
    }
  }

  Widget _buildTodoItem(Todo todo) {
    final isHighlighted = widget.highlightTodoId == todo.id;
    final indicatorColor = _todoIndicatorColor(todo);

    return Dismissible(
      key: Key('todo_${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: MyColors.remove,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteTodo(todo),
      child: ChronoCard(
        leftIndicator: indicatorColor.withValues(alpha: 0.7),
        margin: const EdgeInsets.only(bottom: 6),
        borderColor: isHighlighted
            ? MyColors.orangeDivider.withValues(alpha: 0.5)
            : todo.isDone
                ? successColor.withValues(alpha: 0.2)
                : cardBorder.withValues(alpha: 0.3),
        onTap: () => _toggleTodoCompletion(todo),
        onLongPress: () => _showTodoForm(todo),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: todo.isDone,
                onChanged: (_) => _toggleTodoCompletion(todo),
                activeColor: successColor,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: TextStyle(
                      color: todo.isDone ? textMuted : textPrimary,
                      decoration: todo.isDone ? TextDecoration.lineThrough : null,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (todo.formattedTargetDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          todo.todoType == TodoType.deadline
                              ? Icons.flag_outlined
                              : Icons.wb_sunny_outlined,
                          size: 13,
                          color: todo.isOverdue ? MyColors.remove : textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          todo.formattedTargetDate,
                          style: TextStyle(
                            color: todo.isOverdue ? MyColors.remove : textMuted,
                            fontSize: 11,
                            fontWeight: todo.isOverdue ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (todo.dailyReminderEnabled) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 12,
                            color: textMuted.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: textMuted, size: 18),
              onPressed: () => _showTodoForm(todo),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small helper widget for the info dialog.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
