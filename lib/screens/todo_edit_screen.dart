import 'package:flutter/material.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/models/todo_reminder.model.dart';
import 'package:chrono/services/todo_service.dart';
import 'package:chrono/services/todo_notification_service.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/colors.dart';

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
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDateTime != null
          ? TimeOfDay.fromDateTime(_selectedDateTime!)
          : TimeOfDay.now(),
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
        title: const Text('Custom Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hours before',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes before',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final h = int.tryParse(hoursController.text) ?? 0;
              final m = int.tryParse(minutesController.text) ?? 0;
              Navigator.pop(context, {'hours': h, 'minutes': m});
            },
            child: const Text('OK'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        title: Text(
          _isEditing ? 'Edit Todo' : 'New Todo',
          style: const TextStyle(color: white),
        ),
        iconTheme: const IconThemeData(color: white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(color: MyColors.forthyColor),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: MyColors.forthyColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: MyColors.forthyColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: MyColors.fivyColor, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Description field
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: const TextStyle(color: MyColors.forthyColor),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: MyColors.forthyColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: MyColors.forthyColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: MyColors.fivyColor, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Date & Time section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date & Time (optional)',
                    style: TextStyle(
                      color: white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDateTime == null
                              ? 'No date set'
                              : _formatDateTime(_selectedDateTime!),
                          style: const TextStyle(
                            color: MyColors.fivyColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_selectedDateTime != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: MyColors.forthyColor),
                          onPressed: () {
                            setState(() {
                              _selectedDateTime = null;
                              _selectedReminders.clear();
                            });
                          },
                        ),
                      ElevatedButton.icon(
                        onPressed: _pickDateTime,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_selectedDateTime == null ? 'Set' : 'Change'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.forthyColor,
                          foregroundColor: white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Reminders section
            if (_selectedDateTime != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reminders',
                      style: TextStyle(
                        color: white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text(
                        '1 hour before',
                        style: TextStyle(color: white),
                      ),
                      value: _selectedReminders.contains(TodoReminderType.oneHourBefore),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedReminders.add(TodoReminderType.oneHourBefore);
                          } else {
                            _selectedReminders.remove(TodoReminderType.oneHourBefore);
                          }
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    CheckboxListTile(
                      title: const Text(
                        'Morning of the day (8:00 AM)',
                        style: TextStyle(color: white),
                      ),
                      value: _selectedReminders.contains(TodoReminderType.morningOfDay),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedReminders.add(TodoReminderType.morningOfDay);
                          } else {
                            _selectedReminders.remove(TodoReminderType.morningOfDay);
                          }
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    CheckboxListTile(
                      title: const Text(
                        '1 day before',
                        style: TextStyle(color: white),
                      ),
                      value: _selectedReminders.contains(TodoReminderType.oneDayBefore),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedReminders.add(TodoReminderType.oneDayBefore);
                          } else {
                            _selectedReminders.remove(TodoReminderType.oneDayBefore);
                          }
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    ListTile(
                      title: Text(
                        _customOffsetMinutes != null
                            ? 'Custom: ${_customOffsetMinutes! ~/ 60}h ${_customOffsetMinutes! % 60}m before'
                            : 'Custom time',
                        style: const TextStyle(color: white),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: MyColors.forthyColor),
                        onPressed: _showCustomOffsetDialog,
                      ),
                      leading: Checkbox(
                        value: _selectedReminders.contains(TodoReminderType.custom),
                        onChanged: (value) {
                          if (value == true) {
                            _showCustomOffsetDialog();
                          } else {
                            setState(() {
                              _selectedReminders.remove(TodoReminderType.custom);
                              _customOffsetMinutes = null;
                            });
                          }
                        },
                        activeColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Save button
            ElevatedButton(
              onPressed: _saveTodo,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.forthyColor,
                foregroundColor: bgColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _isEditing ? 'Update Todo' : 'Save Todo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }
}
