import 'package:flutter/material.dart';
import '../models/goal.model.dart';
import '../db_manager.dart';
import '../services/productivity_service.dart';

class AddGoalScreen extends StatefulWidget {
  final Goal? existingGoal;

  const AddGoalScreen({
    Key? key,
    this.existingGoal,
  }) : super(key: key);

  @override
  _AddGoalScreenState createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;
  late TextEditingController _sessionMinutesController;
  int _priority = 2;
  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingGoal?.title ?? '');
    _hoursController = TextEditingController(text: widget.existingGoal?.hours.toString() ?? '');
    _minutesController = TextEditingController(text: widget.existingGoal?.minutes.toString() ?? '');
    _sessionMinutesController =
        TextEditingController(text: widget.existingGoal?.sessionMinutes.toString() ?? '');
    _priority = widget.existingGoal?.priority ?? 2;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _sessionMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Goal' : 'Add Goal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Goal Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a goal title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Hours',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null;
                      }
                      final hours = int.tryParse(value);
                      if (hours == null || hours < 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter minutes';
                      }
                      final minutes = int.tryParse(value);
                      if (minutes == null || minutes < 0 || minutes >= 60) {
                        return 'Please enter 0-59 minutes';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sessionMinutesController,
              decoration: const InputDecoration(
                labelText: 'Session Duration (minutes)',
                border: OutlineInputBorder(),
                helperText: 'How long each work session should be',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter session duration';
                }
                final sessionMinutes = int.tryParse(value);
                if (sessionMinutes == null || sessionMinutes <= 0) {
                  return 'Please enter a valid session duration';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildPrioritySlider(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveGoal,
              child: Text(_isEditing ? 'Update Goal' : 'Save Goal'),
            ),
          ],
        ),
      ),
    );
  }

  static const _priorityLabels = {
    1: 'Необязательно',
    2: 'Стандарт',
    3: 'Важно',
    4: 'Ключевая',
  };

  static const _priorityDescriptions = {
    1: 'Пропуск почти не влияет на индекс',
    2: 'Обычная повседневная активность',
    3: 'Важно выполнить для продуктивности',
    4: 'Критически важно, сильно влияет на индекс',
  };

  Widget _buildPrioritySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Важность', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Slider(
          value: _priority.toDouble(),
          min: 1,
          max: 4,
          divisions: 3,
          label: _priorityLabels[_priority],
          onChanged: (value) {
            setState(() {
              _priority = value.round();
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _priorityLabels[_priority] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _priorityColor(_priority),
              ),
            ),
            Text(
              _priorityDescriptions[_priority] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.redAccent;
      default:
        return Colors.blue;
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.parse(_minutesController.text);
    final sessionMinutes = int.parse(_sessionMinutesController.text);

    final db = DatabaseHelper.instance;

    try {
      if (_isEditing) {
        final updatedGoal = widget.existingGoal!.copyWith(
          title: _titleController.text,
          hours: hours,
          minutes: minutes,
          sessionMinutes: sessionMinutes,
          priority: _priority,
        );
        await db.updateGoal(updatedGoal);
      } else {
        final newGoal = Goal(
          title: _titleController.text,
          hours: hours,
          minutes: minutes,
          sessionMinutes: sessionMinutes,
          timeSpentSeconds: 0,
          isActive: false,
          priority: _priority,
        );
        await db.insertGoal(newGoal);
      }

      await ProductivityService.instance.createOrUpdateDailyRecord();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving goal: $e')),
        );
      }
    }
  }
}
