import 'package:flutter/material.dart';
import '../models/goal.model.dart';
import '../services/database_helper.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({Key? key}) : super(key: key);

  @override
  _AddGoalScreenState createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _sessionMinutesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Goal'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
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
                          return 'Please enter hours';
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveGoal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save Goal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveTestGoal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Test Goal (10s)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveGoal() async {
    if (_formKey.currentState!.validate()) {
      final hours = int.parse(_hoursController.text);
      final minutes = int.parse(_minutesController.text);
      final sessionMinutes = int.parse(_sessionMinutesController.text);

      final goal = Goal(
        title: _titleController.text,
        hours: hours,
        minutes: minutes,
        sessionMinutes: sessionMinutes,
        timeSpentSeconds: 0,
        isActive: false,
      );

      try {
        await DatabaseHelper.instance.insertGoal(goal);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Goal saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving goal: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _saveTestGoal() async {
    // Create a test goal with 10-second sessions
    final goal = Goal(
      title: 'Test Goal - ${DateTime.now().toString().substring(11, 19)}',
      hours: 0,
      minutes: 1, // 1 minute total goal
      sessionMinutes: 1, // But use a very short session for testing
      timeSpentSeconds: 0,
      isActive: false,
    );

    // Override sessionMinutes to 10 seconds for testing
    final testGoal = Goal(
      title: goal.title,
      hours: goal.hours,
      minutes: goal.minutes,
      sessionMinutes: 1, // This will be treated as 10 seconds in the timer
      timeSpentSeconds: goal.timeSpentSeconds,
      isActive: goal.isActive,
    );

    try {
      await DatabaseHelper.instance.insertGoal(testGoal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test goal created with 10-second sessions!'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating test goal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
