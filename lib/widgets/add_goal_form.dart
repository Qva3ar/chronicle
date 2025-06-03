import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/goal.model.dart';

class AddGoalForm extends StatefulWidget {
  final Function(Goal) onGoalAdded;
  final Function(Goal)? onGoalUpdated;
  final Goal? existingGoal; // For editing existing goals

  const AddGoalForm({
    Key? key,
    required this.onGoalAdded,
    this.onGoalUpdated,
    this.existingGoal,
  }) : super(key: key);

  @override
  State<AddGoalForm> createState() => _AddGoalFormState();
}

class _AddGoalFormState extends State<AddGoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _sessionController = TextEditingController(text: '25');

  bool get isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();

    // If editing, populate fields with existing goal data
    if (isEditing) {
      final goal = widget.existingGoal!;
      _titleController.text = goal.title;
      _hoursController.text = goal.hours.toString();
      _minutesController.text = goal.minutes.toString();
      _sessionController.text = goal.sessionMinutes.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  void _saveGoal() {
    if (_formKey.currentState!.validate()) {
      final goal = Goal(
        id: isEditing ? widget.existingGoal!.id : null,
        title: _titleController.text.trim(),
        hours: int.tryParse(_hoursController.text) ?? 0,
        minutes: int.tryParse(_minutesController.text) ?? 0,
        sessionMinutes: int.tryParse(_sessionController.text) ?? 25,
        // Preserve existing time spent and active status when editing
        timeSpentSeconds: isEditing ? widget.existingGoal!.timeSpentSeconds : 0,
        isActive: isEditing ? widget.existingGoal!.isActive : false,
      );

      if (isEditing) {
        widget.onGoalUpdated?.call(goal);
      } else {
        widget.onGoalAdded(goal);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Goal' : 'Add New Goal'),
        actions: [
          TextButton(
            onPressed: _saveGoal,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Goal Title',
                hintText: 'e.g., Learn Flutter, Read Books',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a goal title';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Goal duration section
            Text(
              'Goal Duration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'How much time do you want to spend on this goal?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
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
                      suffixText: 'h',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final hours = int.tryParse(value ?? '0') ?? 0;
                      final minutes = int.tryParse(_minutesController.text) ?? 0;
                      if (hours == 0 && minutes == 0) {
                        return 'Set time';
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
                      suffixText: 'm',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final minutes = int.tryParse(value ?? '0') ?? 0;
                      if (minutes > 59) {
                        return 'Max 59';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Session duration
            Text(
              'Session Duration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'How long should each focused session be?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: 200,
              child: TextFormField(
                controller: _sessionController,
                decoration: const InputDecoration(
                  labelText: 'Session Minutes',
                  border: OutlineInputBorder(),
                  suffixText: 'min',
                  hintText: '25',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final session = int.tryParse(value ?? '0') ?? 0;
                  if (session <= 0) {
                    return 'Please enter a valid session duration';
                  }
                  if (session > 180) {
                    return 'Sessions should be under 3 hours';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _saveGoal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isEditing ? 'Update Goal' : 'Create Goal',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // Only show presets when adding new goals
            if (!isEditing) ...[
              const SizedBox(height: 16),

              // Quick presets
              Text(
                'Quick Presets',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _PresetChip(
                    label: '30min goal',
                    onTap: () {
                      _hoursController.text = '0';
                      _minutesController.text = '30';
                      _sessionController.text = '25';
                    },
                  ),
                  _PresetChip(
                    label: '1h goal',
                    onTap: () {
                      _hoursController.text = '1';
                      _minutesController.text = '0';
                      _sessionController.text = '25';
                    },
                  ),
                  _PresetChip(
                    label: '2h goal',
                    onTap: () {
                      _hoursController.text = '2';
                      _minutesController.text = '0';
                      _sessionController.text = '30';
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      labelStyle: TextStyle(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
