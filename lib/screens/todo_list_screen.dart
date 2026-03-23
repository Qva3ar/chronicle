import 'package:flutter/material.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/todo_service.dart';
import 'package:chrono/services/todo_notification_service.dart';
import 'package:chrono/screens/todo_edit_screen.dart';
import 'package:chrono/services/filter_service.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/shared/chrono_ui.dart';

class TodoListScreen extends StatefulWidget {
  final int? highlightTodoId; // To highlight a specific todo when opened from notification
  /// When set (e.g. inside [DraggableScrollableSheet]), list scroll is linked to sheet drag.
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

  // ── Build the flat list with simple sections ────────────────────────────
  List<Widget> _buildGroupedTodos() {
    final List<Widget> widgets = [];

    // Split active todos into three groups
    final overdue = <Todo>[];
    final scheduled = <Todo>[];
    final noDate = <Todo>[];

    for (final todo in _activeTodos) {
      if (todo.isOverdue) {
        overdue.add(todo);
      } else if (todo.hasTargetTime) {
        scheduled.add(todo);
      } else {
        noDate.add(todo);
      }
    }

    // Sort scheduled by target date (soonest first)
    scheduled.sort((a, b) => a.targetDateTime!.compareTo(b.targetDateTime!));

    // ── Overdue ──
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
      widgets.add(const SizedBox(height: 8));
    }

    // ── Scheduled (has date) ──
    if (scheduled.isNotEmpty) {
      widgets.add(
        ChronoSectionHeader(
          icon: Icons.schedule_outlined,
          iconColor: infoColor,
          label: 'SCHEDULED',
          count: scheduled.length,
          countColor: infoColor,
        ),
      );
      for (final todo in scheduled) {
        widgets.add(_buildTodoItem(todo));
      }
      widgets.add(const SizedBox(height: 8));
    }

    // ── No date ──
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
    }

    return widgets;
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

  Widget _buildHeader() {
    return ChronoSheetHeader(
      title: 'Todo',
      titleIcon: Icons.checklist_rounded,
      itemCount: _activeTodos.length,
      actions: [
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
          onPressed: () => _showTodoForm(),
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
    if (todo.hasTargetTime) return infoColor;
    return textMuted;
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
        onTap: () => _showTodoForm(todo),
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

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          todo.title,
                          style: TextStyle(
                            color: todo.isDone ? textMuted : textPrimary,
                            decoration: todo.isDone ? TextDecoration.lineThrough : null,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (todo.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      todo.description!,
                      style: TextStyle(
                        color: todo.isDone ? textHint : textMuted,
                        fontSize: 13,
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
