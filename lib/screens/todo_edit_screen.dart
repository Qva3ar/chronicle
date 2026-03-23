import 'package:flutter/material.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/models/todo_reminder.model.dart';
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
  late TextEditingController _descriptionController;
  late TodoService _todoService;
  late TodoNotificationService _notificationService;

  DateTime? _selectedDateTime;
  final Set<TodoReminderType> _selectedReminders = {};
  int? _customOffsetMinutes;

  bool get _isEditing => widget.existingTodo != null;

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(DatabaseHelper.instance);
    _notificationService = TodoNotificationService();

    _titleController = TextEditingController(text: widget.existingTodo?.title ?? '');
    _descriptionController = TextEditingController(text: widget.existingTodo?.description ?? '');
    _selectedDateTime = widget.existingTodo?.targetDateTime;

    // Load existing reminders if editing
    if (_isEditing) {
      _loadExistingReminders();
    }
  }

  Future<void> _loadExistingReminders() async {
    final reminders = await _todoService.getTodoReminders(widget.existingTodo!.id!);
    setState(() {
      for (final reminder in reminders) {
        _selectedReminders.add(reminder.reminderType);
        if (reminder.reminderType == TodoReminderType.custom) {
          _customOffsetMinutes = reminder.customOffsetMinutes;
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDateTime != null
          ? TimeOfDay.fromDateTime(_selectedDateTime!)
          : TimeOfDay.now(),
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

    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _showCustomOffsetDialog() async {
    int? hours;
    int? minutes;

    if (_customOffsetMinutes != null) {
      hours = _customOffsetMinutes! ~/ 60;
      minutes = _customOffsetMinutes! % 60;
    }

    final hoursController = TextEditingController(text: hours?.toString() ?? '');
    final minutesController = TextEditingController(text: minutes?.toString() ?? '');

    if (!mounted) return;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Custom Reminder', style: TextStyle(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hoursController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Hours before',
                labelStyle: const TextStyle(color: textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Minutes before',
                labelStyle: const TextStyle(color: textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final h = int.tryParse(hoursController.text) ?? 0;
              final m = int.tryParse(minutesController.text) ?? 0;
              Navigator.pop(context, {'hours': h, 'minutes': m});
            },
            child: const Text('OK', style: TextStyle(color: MyColors.orangeDivider)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _customOffsetMinutes = (result['hours']! * 60) + result['minutes']!;
        if (_customOffsetMinutes! > 0) {
          _selectedReminders.add(TodoReminderType.custom);
        }
      });
    }
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      if (_isEditing) {
        // Update existing todo
        final updatedTodo = widget.existingTodo!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          targetDateTime: _selectedDateTime,
          clearTargetDateTime: _selectedDateTime == null,
          clearDescription: _descriptionController.text.trim().isEmpty,
        );

        await _todoService.updateTodo(
          updatedTodo,
          reminderTypes: _selectedDateTime != null ? _selectedReminders.toList() : [],
          customReminderOffsetMinutes: _customOffsetMinutes,
        );

        // Schedule new reminders
        if (_selectedDateTime != null && _selectedReminders.isNotEmpty) {
          final reminders = await _todoService.getTodoReminders(updatedTodo.id!);
          await _notificationService.scheduleAllRemindersForTodo(
            todo: updatedTodo,
            reminders: reminders,
          );
        }
      } else {
        // Create new todo
        final todoId = await _todoService.createTodo(
          _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          targetDateTime: _selectedDateTime,
          reminderTypes: _selectedDateTime != null ? _selectedReminders.toList() : null,
          customReminderOffsetMinutes: _customOffsetMinutes,
        );

        // Schedule reminders
        if (_selectedDateTime != null && _selectedReminders.isNotEmpty) {
          final todo = await _todoService.getTodo(todoId);
          final reminders = await _todoService.getTodoReminders(todoId);
          if (todo != null) {
            await _notificationService.scheduleAllRemindersForTodo(
              todo: todo,
              reminders: reminders,
            );
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

  // ── Quick-date helpers ──────────────────────────────────────────────────

  void _setQuickDate(DateTime date) {
    setState(() {
      _selectedDateTime = date;
    });
  }

  DateTime _today9am() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 9, 0);
  }

  DateTime _tomorrow9am() {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day, 9, 0);
  }

  DateTime _nextWeek9am() {
    // Next Monday
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    final monday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(monday.year, monday.month, monday.day, 9, 0);
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textMuted),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cardBorder),
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
            // ── Title ──
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
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 14),

            // ── Description ──
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: textPrimary),
              maxLines: 3,
              decoration: _inputDecoration('Description (optional)'),
            ),

            const SizedBox(height: 20),

            // ── Date & Time section ──
            ChronoSettingsGroup(
              title: 'Date & Time',
              children: [
                // Quick-set date chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickChip(
                        label: 'Today',
                        icon: Icons.today,
                        isActive: _isMatchingDate(_today9am()),
                        onTap: () => _setQuickDate(_today9am()),
                      ),
                      _quickChip(
                        label: 'Tomorrow',
                        icon: Icons.event,
                        isActive: _isMatchingDate(_tomorrow9am()),
                        onTap: () => _setQuickDate(_tomorrow9am()),
                      ),
                      _quickChip(
                        label: 'Next week',
                        icon: Icons.date_range,
                        isActive: _isMatchingDate(_nextWeek9am()),
                        onTap: () => _setQuickDate(_nextWeek9am()),
                      ),
                      _quickChip(
                        label: 'No date',
                        icon: Icons.block,
                        isActive: _selectedDateTime == null,
                        onTap: () {
                          setState(() {
                            _selectedDateTime = null;
                            _selectedReminders.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Current date display + custom picker
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Row(
                    children: [
                      Icon(
                        _selectedDateTime != null ? Icons.event_available : Icons.event_busy,
                        size: 18,
                        color: _selectedDateTime != null ? infoColor : textHint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedDateTime == null
                              ? 'No specific date set'
                              : _formatDateTime(_selectedDateTime!),
                          style: TextStyle(
                            color: _selectedDateTime != null ? textPrimary : textHint,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickDateTime,
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: const Text('Custom'),
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

            // ── Reminders section ──
            if (_selectedDateTime != null) ...[
              const SizedBox(height: 16),
              ChronoSettingsGroup(
                title: 'Reminders',
                children: [
                  _reminderRow(
                    label: '1 hour before',
                    icon: Icons.alarm,
                    type: TodoReminderType.oneHourBefore,
                  ),
                  _reminderRow(
                    label: 'Morning of the day (8:00)',
                    icon: Icons.wb_sunny_outlined,
                    type: TodoReminderType.morningOfDay,
                  ),
                  _reminderRow(
                    label: '1 day before',
                    icon: Icons.hourglass_top,
                    type: TodoReminderType.oneDayBefore,
                  ),
                  _customReminderRow(),
                ],
              ),
            ],

            const SizedBox(height: 80), // space for button
          ],
        ),
      ),

      // ── Sticky save button at bottom ──
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

  // ── Quick-date chip ────────────────────────────────────────────────────

  bool _isMatchingDate(DateTime target) {
    if (_selectedDateTime == null) return false;
    final s = _selectedDateTime!;
    return s.year == target.year && s.month == target.month && s.day == target.day;
  }

  Widget _quickChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? MyColors.orangeDivider.withValues(alpha: 0.15) : cardColor2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? MyColors.orangeDivider.withValues(alpha: 0.5) : cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? MyColors.orangeDivider : textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? MyColors.orangeDivider : textSecondary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reminder row ──────────────────────────────────────────────────────

  Widget _reminderRow({
    required String label,
    required IconData icon,
    required TodoReminderType type,
  }) {
    final isSelected = _selectedReminders.contains(type);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedReminders.remove(type);
          } else {
            _selectedReminders.add(type);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? successColor : textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? textPrimary : textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? successColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? successColor : textMuted,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _customReminderRow() {
    final isSelected = _selectedReminders.contains(TodoReminderType.custom);
    final hasValue = _customOffsetMinutes != null && _customOffsetMinutes! > 0;

    return InkWell(
      onTap: () {
        if (isSelected) {
          setState(() {
            _selectedReminders.remove(TodoReminderType.custom);
            _customOffsetMinutes = null;
          });
        } else {
          _showCustomOffsetDialog();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.tune, size: 18, color: isSelected ? successColor : textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom',
                    style: TextStyle(
                      color: isSelected ? textPrimary : textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (hasValue)
                    Text(
                      '${_customOffsetMinutes! ~/ 60}h ${_customOffsetMinutes! % 60}m before',
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (!isSelected)
              const Icon(Icons.add, size: 18, color: textMuted),
            if (isSelected) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: textMuted),
                onPressed: _showCustomOffsetDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: successColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (targetDay == today) {
      dateStr = 'Today';
    } else if (targetDay == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      dateStr = '${weekdays[dateTime.weekday - 1]}, ${dateTime.day} ${months[dateTime.month - 1]}';
    }

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }
}
