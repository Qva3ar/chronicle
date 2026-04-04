import 'package:flutter/material.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/services/todo_service.dart';
import 'package:chrono/services/todo_notification_service.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/shared/chrono_ui.dart';

class TodoEditScreen extends StatefulWidget {
  final Todo? existingTodo;

  const TodoEditScreen({super.key, this.existingTodo});

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TodoService _todoService;
  late TodoNotificationService _notificationService;

  TodoType _selectedType = TodoType.tomorrow;
  DateTime? _deadlineDate;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _repeatEnabled = false;
  int _periodMinutes = 60;
  int _intervalMinutes = 30;

  bool get _isEditing => widget.existingTodo != null;

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(DatabaseHelper.instance);
    _notificationService = TodoNotificationService();

    _titleController = TextEditingController(text: widget.existingTodo?.title ?? '');

    if (_isEditing) {
      final todo = widget.existingTodo!;
      _selectedType = todo.todoType;
      _deadlineDate = todo.targetDateTime;
      _reminderEnabled = todo.dailyReminderEnabled;
      if (todo.dailyReminderTime != null) {
        final parts = todo.dailyReminderTime!.split(':');
        if (parts.length == 2) {
          _reminderTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      if (todo.reminderPeriodMinutes != null && todo.reminderIntervalMinutes != null) {
        _repeatEnabled = true;
        _periodMinutes = todo.reminderPeriodMinutes!;
        _intervalMinutes = todo.reminderIntervalMinutes!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadlineDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: MyColors.orangeDivider,
            surface: Color(0xFF2D2E33),
          ),
        ),
        child: child!,
      ),
    );

    if (date != null) {
      setState(() {
        _deadlineDate = date;
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: MyColors.orangeDivider,
            surface: Color(0xFF2D2E33),
          ),
        ),
        child: child!,
      ),
    );

    if (time != null) {
      setState(() {
        _reminderTime = time;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int get _previewNotificationCount {
    if (!_repeatEnabled || _intervalMinutes <= 0) return 1;
    return (_periodMinutes ~/ _intervalMinutes) + 1;
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate deadline date for deadline type
    if (_selectedType == TodoType.deadline && _deadlineDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline date')),
      );
      return;
    }

    try {
      final title = _titleController.text.trim();
      final reminderTimeStr = _formatTimeOfDay(_reminderTime);
      final hasReminder = _selectedType != TodoType.noDate && _reminderEnabled;

      if (_isEditing) {
        final old = widget.existingTodo!;

        DateTime? targetDateTime;
        if (_selectedType == TodoType.tomorrow) {
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          targetDateTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59);
        } else if (_selectedType == TodoType.deadline) {
          targetDateTime = _deadlineDate;
        }

        final updatedTodo = old.copyWith(
          title: title,
          todoType: _selectedType,
          targetDateTime: targetDateTime,
          clearTargetDateTime: _selectedType == TodoType.noDate,
          dailyReminderEnabled: hasReminder,
          dailyReminderTime: hasReminder ? reminderTimeStr : null,
          clearDailyReminderTime: !hasReminder,
          reminderPeriodMinutes: hasReminder && _repeatEnabled ? _periodMinutes : null,
          reminderIntervalMinutes: hasReminder && _repeatEnabled ? _intervalMinutes : null,
          clearReminderPeriod: !(hasReminder && _repeatEnabled),
        );

        await _todoService.updateTodo(updatedTodo);

        // Handle notifications
        await _notificationService.initialize();
        await _notificationService.cancelTodoReminders(old.id!);
        if (updatedTodo.dailyReminderEnabled) {
          await _notificationService.scheduleTodoReminders(updatedTodo);
        }
      } else {
        final todoId = await _todoService.createTodo(
          title,
          todoType: _selectedType,
          targetDateTime: _selectedType == TodoType.deadline ? _deadlineDate : null,
          dailyReminderEnabled: hasReminder,
          dailyReminderTime: hasReminder ? reminderTimeStr : null,
          reminderPeriodMinutes: hasReminder && _repeatEnabled ? _periodMinutes : null,
          reminderIntervalMinutes: hasReminder && _repeatEnabled ? _intervalMinutes : null,
        );

        // Schedule notifications if enabled
        if (hasReminder) {
          final todo = await _todoService.getTodo(todoId);
          if (todo != null) {
            await _notificationService.initialize();
            await _notificationService.scheduleTodoReminders(todo);
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving todo: $e')),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textMuted),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: MyColors.orangeDivider, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: MyColors.remove),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Todo' : 'New Todo',
          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
          TextButton(
            onPressed: _saveTodo,
            child: Text(
              _isEditing ? 'Save' : 'Create',
              style: const TextStyle(
                color: MyColors.orangeDivider,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: textPrimary, fontSize: 16),
              decoration: _inputDecoration('Title'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 20),

            // Type selector
            ChronoSettingsGroup(
              title: 'Type',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _typeChip(
                          label: 'Tomorrow',
                          icon: Icons.wb_sunny_outlined,
                          type: TodoType.tomorrow,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _typeChip(
                          label: 'Deadline',
                          icon: Icons.flag_outlined,
                          type: TodoType.deadline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _typeChip(
                          label: 'No date',
                          icon: Icons.inbox_outlined,
                          type: TodoType.noDate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Deadline date picker (only for deadline type)
            if (_selectedType == TodoType.deadline) ...[
              const SizedBox(height: 16),
              ChronoSettingsGroup(
                title: 'Deadline Date',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Icon(
                          _deadlineDate != null ? Icons.event_available : Icons.event_busy,
                          size: 18,
                          color: _deadlineDate != null ? infoColor : textHint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _deadlineDate == null
                                ? 'Select a deadline date'
                                : _formatDate(_deadlineDate!),
                            style: TextStyle(
                              color: _deadlineDate != null ? textPrimary : textHint,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickDeadlineDate,
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('Pick date'),
                          style: TextButton.styleFrom(
                            foregroundColor: MyColors.orangeDivider,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: MyColors.orangeDivider.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Notification section (for tomorrow and deadline)
            if (_selectedType != TodoType.noDate) ...[
              const SizedBox(height: 16),
              ChronoSettingsGroup(
                title: 'Notification',
                children: [
                  // Enable toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: _reminderEnabled ? MyColors.orangeDivider : textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedType == TodoType.tomorrow
                                ? 'Remind me tomorrow'
                                : 'Remind me every day',
                            style: const TextStyle(color: textPrimary, fontSize: 14),
                          ),
                        ),
                        Switch(
                          value: _reminderEnabled,
                          onChanged: (value) {
                            setState(() {
                              _reminderEnabled = value;
                              if (!value) _repeatEnabled = false;
                            });
                          },
                          activeTrackColor: MyColors.orangeDivider,
                        ),
                      ],
                    ),
                  ),

                  if (_reminderEnabled) ...[
                    // Time picker
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: textMuted),
                          const SizedBox(width: 10),
                          Text(
                            'At ${_formatTimeOfDay(_reminderTime)}',
                            style: const TextStyle(color: textSecondary, fontSize: 14),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _pickReminderTime,
                            style: TextButton.styleFrom(
                              foregroundColor: MyColors.orangeDivider,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                    color: MyColors.orangeDivider.withValues(alpha: 0.3)),
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),

                    // Repeat toggle (only for tomorrow type)
                    if (_selectedType == TodoType.tomorrow) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 8, 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 18,
                              color: _repeatEnabled ? MyColors.orangeDivider : textMuted,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Repeat notifications',
                                style: TextStyle(color: textPrimary, fontSize: 14),
                              ),
                            ),
                            Switch(
                              value: _repeatEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _repeatEnabled = value;
                                });
                              },
                              activeTrackColor: MyColors.orangeDivider,
                            ),
                          ],
                        ),
                      ),

                      if (_repeatEnabled) ...[
                        // Period picker
                        Padding(
                          padding: const EdgeInsets.fromLTRB(42, 0, 14, 6),
                          child: Row(
                            children: [
                              const Text('Period: ', style: TextStyle(color: textSecondary, fontSize: 13)),
                              _minuteChip(30, _periodMinutes, (v) => setState(() => _periodMinutes = v)),
                              const SizedBox(width: 6),
                              _minuteChip(60, _periodMinutes, (v) => setState(() => _periodMinutes = v)),
                              const SizedBox(width: 6),
                              _minuteChip(120, _periodMinutes, (v) => setState(() => _periodMinutes = v)),
                            ],
                          ),
                        ),

                        // Interval picker
                        Padding(
                          padding: const EdgeInsets.fromLTRB(42, 0, 14, 6),
                          child: Row(
                            children: [
                              const Text('Every: ', style: TextStyle(color: textSecondary, fontSize: 13)),
                              _minuteChip(10, _intervalMinutes, (v) => setState(() => _intervalMinutes = v)),
                              const SizedBox(width: 6),
                              _minuteChip(15, _intervalMinutes, (v) => setState(() => _intervalMinutes = v)),
                              const SizedBox(width: 6),
                              _minuteChip(30, _intervalMinutes, (v) => setState(() => _intervalMinutes = v)),
                              const SizedBox(width: 6),
                              _minuteChip(60, _intervalMinutes, (v) => setState(() => _intervalMinutes = v)),
                            ],
                          ),
                        ),

                        // Preview
                        Padding(
                          padding: const EdgeInsets.fromLTRB(42, 2, 14, 12),
                          child: Text(
                            '$_previewNotificationCount notification${_previewNotificationCount > 1 ? 's' : ''}: '
                            'starting ${_formatMinutes(_periodMinutes)} before, every ${_formatMinutes(_intervalMinutes)}',
                            style: const TextStyle(color: textMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ],

                  if (!_reminderEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(42, 0, 14, 12),
                      child: Text(
                        _selectedType == TodoType.tomorrow
                            ? 'Get a notification on the day'
                            : 'Get a notification every day until the deadline',
                        style: const TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),

      // Save button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saveTodo,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.orangeDivider,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _isEditing ? 'Update Todo' : 'Create Todo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    }
    return '${minutes}m';
  }

  Widget _minuteChip(int value, int selected, ValueChanged<int> onTap) {
    final isActive = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? MyColors.orangeDivider.withValues(alpha: 0.15) : cardColor2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? MyColors.orangeDivider.withValues(alpha: 0.5) : cardBorder,
          ),
        ),
        child: Text(
          _formatMinutes(value),
          style: TextStyle(
            color: isActive ? MyColors.orangeDivider : textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required IconData icon,
    required TodoType type,
  }) {
    final isActive = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          if (type == TodoType.noDate) {
            _reminderEnabled = false;
            _repeatEnabled = false;
          } else if (type == TodoType.deadline) {
            _repeatEnabled = false;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? MyColors.orangeDivider.withValues(alpha: 0.15) : cardColor2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? MyColors.orangeDivider.withValues(alpha: 0.5) : cardBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isActive ? MyColors.orangeDivider : textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? MyColors.orangeDivider : textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
