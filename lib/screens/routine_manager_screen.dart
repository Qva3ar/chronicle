import 'package:flutter/material.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/colors.dart';

class RoutineManagerScreen extends StatefulWidget {
  const RoutineManagerScreen({super.key});

  @override
  State<RoutineManagerScreen> createState() => _RoutineManagerScreenState();
}

class _RoutineManagerScreenState extends State<RoutineManagerScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService();
  List<Routine> _routines = [];

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final routines = await _db.getAllRoutines();
    setState(() {
      _routines = routines.map((r) => Routine.fromMap(r)).toList();
    });
  }

  Future<void> _toggleRoutineDone(Routine routine) async {
    final isDone = !routine.isDone;
    await _db.toggleRoutineDone(routine.id!, isDone);
    if (isDone) {
      try {
        // Create a record for the completed routine
        final record = {
          DatabaseColumns.recordTitle: 'Completed Routine: ${routine.name}',
          DatabaseColumns.recordText: 'Completed routine: ${routine.name}',
          DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
          DatabaseColumns.recordType: 'routine', // Mark as routine record
          DatabaseColumns.recordRoutineId: routine.id,
        };

        await _db.insertRecord(record, []); // No tags for routine records

        await _notifications.markRoutineDone(routine.id!);
        await _notifications.cancelRoutineNotification(routine.id!);

        // Notify parent to refresh records
        if (mounted) {
          Navigator.pop(context, true); // Pop with true to indicate records need refresh
        }
      } catch (e) {
        print('ERROR: Failed to create routine record: $e');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating routine record: $e')),
          );
        }
      }
    } else {
      // Reschedule notification if routine is marked as undone
      final nextOccurrence = routine.getNextOccurrence();
      await _notifications.scheduleRoutineNotification(
        routineId: routine.id!,
        routineName: routine.name,
        scheduledTime: nextOccurrence,
        periodAfter: routine.periodAfter,
        interval: routine.interval,
      );
    }
    await _loadRoutines();
  }

  Future<void> _showRoutineForm([Routine? routine]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutineFormScreen(routine: routine),
      ),
    );

    if (result == true) {
      await _loadRoutines();
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Are you sure you want to delete "${routine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Remove all routine data including notifications and alarms
      await _notifications.cancelRoutineNotification(routine.id!);
      // Delete the routine from database
      await _db.deleteRoutine(routine.id!);
      await _loadRoutines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
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
                  'Routine Manager',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: white),
                  onPressed: () => _showRoutineForm(),
                ),
              ],
            ),
          ),
          // List of routines
          Expanded(
            child: _routines.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _routines.length,
                    itemBuilder: (context, index) {
                      final routine = _routines[index];
                      return Dismissible(
                        key: Key(routine.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: MyColors.remove,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: white),
                        ),
                        onDismissed: (_) => _deleteRoutine(routine),
                        child: ListTile(
                          leading: Checkbox(
                            value: routine.isDone,
                            onChanged: (_) => _toggleRoutineDone(routine),
                            checkColor: MyColors.secondaryColor,
                            fillColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return MyColors.fivyColor;
                              }
                              return MyColors.forthyColor;
                            }),
                          ),
                          title: Text(
                            routine.name,
                            style: TextStyle(
                              color: routine.isDone ? MyColors.forthyColor : white,
                              decoration: routine.isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            '${routine.time.format(context)} - ${_formatDaysOfWeek(routine.daysOfWeek)}',
                            style: TextStyle(
                              color: routine.isDone ? MyColors.trecondaryColor : MyColors.fivyColor,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: white),
                                onPressed: () => _showRoutineForm(routine),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: MyColors.remove),
                                onPressed: () => _deleteRoutine(routine),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDaysOfWeek(List<bool> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final activeDays = <String>[];
    for (var i = 0; i < days.length; i++) {
      if (days[i]) {
        activeDays.add(dayNames[i]);
      }
    }
    return activeDays.join(', ');
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 80,
                color: MyColors.forthyColor,
              ),
              const SizedBox(height: 24),
              Text(
                'No Routines Yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create your first routine to build consistent daily habits and stay organized.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MyColors.fivyColor,
                    ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _showRoutineForm(),
                icon: const Icon(Icons.add),
                label: const Text('Create Your First Routine'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineFormScreen extends StatefulWidget {
  final Routine? routine;

  const RoutineFormScreen({super.key, this.routine});

  @override
  State<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _RoutineFormScreenState extends State<RoutineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();
  final List<bool> _daysOfWeek = List.filled(7, false);
  int _periodAfter = 30;
  int _interval = 10;

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _nameController.text = widget.routine!.name;
      _time = widget.routine!.time;
      _daysOfWeek.setAll(0, widget.routine!.daysOfWeek);
      _periodAfter = widget.routine!.periodAfter;
      _interval = widget.routine!.interval;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() {
        _time = picked;
      });
    }
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_daysOfWeek.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    final routine = Routine(
      id: widget.routine?.id,
      name: _nameController.text,
      time: _time,
      daysOfWeek: _daysOfWeek,
      periodAfter: _periodAfter,
      interval: _interval,
    );

    final db = DatabaseHelper.instance;
    final notifications = NotificationService();

    if (widget.routine == null) {
      final id = await db.insertRoutine(routine.toMap());
      final nextOccurrence = routine.getNextOccurrence();
      await notifications.scheduleRoutineNotification(
        routineId: id,
        routineName: routine.name,
        scheduledTime: nextOccurrence,
        periodAfter: routine.periodAfter,
        interval: routine.interval,
      );
    } else {
      await db.updateRoutine(widget.routine!.id!, routine.toMap());
      await notifications.cancelRoutineNotification(widget.routine!.id!);
      final nextOccurrence = routine.getNextOccurrence();
      await notifications.scheduleRoutineNotification(
        routineId: widget.routine!.id!,
        routineName: routine.name,
        scheduledTime: nextOccurrence,
        periodAfter: routine.periodAfter,
        interval: routine.interval,
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine == null ? 'Add Routine' : 'Edit Routine'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Routine Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: _selectTime,
            ),
            const SizedBox(height: 16),
            const Text('Days of Week'),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]),
                    selected: _daysOfWeek[i],
                    onSelected: (selected) {
                      setState(() {
                        _daysOfWeek[i] = selected;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _periodAfter.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Period After (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _periodAfter = int.tryParse(value) ?? 30;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _interval.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Interval (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _interval = int.tryParse(value) ?? 10;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveRoutine,
              child: Text(widget.routine == null ? 'Add Routine' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
