import 'package:flutter/material.dart';
import '../models/goal.model.dart';

class AddGoalScreen extends StatefulWidget {
  final Function(Goal)? onGoalAdded;
  final Function(Goal)? onGoalUpdated;
  final Goal? existingGoal;

  const AddGoalScreen({
    Key? key,
    this.onGoalAdded,
    this.onGoalUpdated,
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
  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingGoal?.title ?? '');
    _hoursController = TextEditingController(
        text: widget.existingGoal?.hours.toString() ?? '');
    _minutesController = TextEditingController(
        text: widget.existingGoal?.minutes.toString() ?? '');
    _sessionMinutesController = TextEditingController(
        text: widget.existingGoal?.sessionMinutes.toString() ?? '');
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
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Goal' : 'Add Goal'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveGoal,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(_isEditing ? 'Update Goal' : 'Save Goal'),
        ),
        if (!_isEditing)
          ElevatedButton(
            onPressed: _saveTestGoal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Test Goal (10s)'),
          ),
      ],
    );
  }

  void _saveGoal() async {
    if (_formKey.currentState!.validate()) {
      final hours = int.tryParse(_hoursController.text) ?? 0;
      final minutes = int.parse(_minutesController.text);
      final sessionMinutes = int.parse(_sessionMinutesController.text);

      if (_isEditing) {
        final updatedGoal = widget.existingGoal!.copyWith(
          title: _titleController.text,
          hours: hours,
          minutes: minutes,
          sessionMinutes: sessionMinutes,
        );
        widget.onGoalUpdated!(updatedGoal);
      } else {
        final newGoal = Goal(
          title: _titleController.text,
          hours: hours,
          minutes: minutes,
          sessionMinutes: sessionMinutes,
          timeSpentSeconds: 0,
          isActive: false,
        );
        widget.onGoalAdded!(newGoal);
      }
      Navigator.pop(context);
    }
  }

  void _saveTestGoal() async {
    final goal = Goal(
      title: 'Test Goal - ${DateTime.now().toString().substring(11, 19)}',
      hours: 0,
      minutes: 1, // 1 minute total goal
      sessionMinutes: 1, // Will be treated as 10s in timer service
      timeSpentSeconds: 0,
      isActive: false,
    );

    widget.onGoalAdded!(goal);
    Navigator.pop(context);
  }
}
