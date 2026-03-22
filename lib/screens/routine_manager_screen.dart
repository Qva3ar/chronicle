import 'dart:developer';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/services/daily_reset_service.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/screens/routine_calendar_screen.dart';
import 'package:chrono/services/routine_widget_service.dart';
import 'package:chrono/services/filter_service.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:chrono/widgets/reminder_timeline_widget.dart';

class RoutineManagerScreen extends StatefulWidget {
  /// When set (e.g. inside [DraggableScrollableSheet]), list scroll is linked to sheet drag.
  final ScrollController? sheetScrollController;

  const RoutineManagerScreen({super.key, this.sheetScrollController});

  @override
  State<RoutineManagerScreen> createState() => _RoutineManagerScreenState();
}

class _RoutineManagerScreenState extends State<RoutineManagerScreen> with WidgetsBindingObserver {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService();
  List<Routine> _routines = [];
  List<Routine> _otherDayRoutines = [];
  bool _showOtherDays = false;

  // ignore: cancel_subscriptions
  StreamSubscription? _resetSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShowOtherDays();
    _loadRoutines();

    _resetSubscription = DailyResetService.instance.onResetComplete.listen((_) {
      print("🔄 RoutineManagerScreen: Daily reset detected, reloading routines");
      _loadRoutines();
    });
  }

  Future<void> _loadShowOtherDays() async {
    final value = await FilterService.instance.getShowOtherDayRoutines();
    if (mounted) setState(() => _showOtherDays = value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("📱 RoutineManagerScreen: App resumed, reloading routines");
      _loadRoutines();
    }
  }

  Future<void> _loadRoutines() async {
    final routines = await _db.getAllRoutines();
    final now = DateTime.now();
    final currentDayIndex = now.weekday - 1;

    final allRoutines = routines.map((r) => Routine.fromMap(r)).toList();

    final todayList = allRoutines
        .where((r) => r.isActiveOnDay(currentDayIndex))
        .toList();

    final otherDayList = allRoutines
        .where((r) => !r.isActiveOnDay(currentDayIndex))
        .toList();

    todayList.sort((a, b) {
      if (a.isDone && !b.isDone) return 1;
      if (!a.isDone && b.isDone) return -1;
      final aMin = a.time.hour * 60 + a.time.minute;
      final bMin = b.time.hour * 60 + b.time.minute;
      return aMin.compareTo(bMin);
    });

    otherDayList.sort((a, b) {
      final aMin = a.time.hour * 60 + a.time.minute;
      final bMin = b.time.hour * 60 + b.time.minute;
      return aMin.compareTo(bMin);
    });

    setState(() {
      _routines = todayList;
      _otherDayRoutines = otherDayList;
    });
  }

  Future<void> _toggleRoutineDone(Routine routine) async {
    final isDone = !routine.isDone;
    await _db.toggleRoutineDone(routine.id!, isDone);

    // Optimistic UI: update immediately so checkbox responds without lag
    if (mounted) {
      setState(() {
        final idx = _routines.indexWhere((r) => r.id == routine.id);
        if (idx >= 0) {
          _routines[idx] = routine.copyWith(isDone: isDone);
        }
      });
    }

    if (isDone) {
      try {
        // Create a record only if there isn't one for today (one note per routine per day)
        final alreadyHasRecord = await _db.hasRoutineRecordForToday(routine.id!);
        if (!alreadyHasRecord) {
          final record = {
            DatabaseColumns.recordText: 'Completed routine: ${routine.name}',
            DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
            DatabaseColumns.recordType: 'routine', // Mark as routine record
            DatabaseColumns.recordRoutineId: routine.id,
          };

          await _db.insertRecord(record, []); // No tags for routine records
        }

        await _notifications.markRoutineDone(routine.id!);
        await _notifications.cancelRoutineNotification(routine.id!);

        // Don't close the bottom sheet - keep it open for more interactions
        // The parent will refresh records automatically when the bottom sheet is dismissed
      } catch (e) {
        log('ERROR: Failed to create routine record: $e');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating routine record: $e')),
          );
        }
      }
    } else {
      // Delete the routine completion note for today when user unchecks
      await _db.deleteRoutineRecordsForToday(routine.id!);

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
    await _updateWidget();
    await ProductivityService.instance.createOrUpdateDailyRecord();
  }

  Future<void> _updateWidget() async {
    try {
      final service = RoutineWidgetService(_db);
      await service.updateWidget();
    } catch (e) {
      log('Error updating widget: $e');
    }
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
      await _updateWidget();
    }
  }

  Future<void> _showCalendarHistory(Routine routine) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutineCalendarScreen(routine: routine),
      ),
    );

    // Reload routines if data was changed in the calendar
    if (result == true) {
      await _loadRoutines();
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    // Remove all routine data including notifications and alarms
    await _notifications.cancelRoutineNotification(routine.id!);
    // Delete the routine from database
    await _db.deleteRoutine(routine.id!);
    await _loadRoutines();
    await _updateWidget();
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: MyColors.forthyColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_otherDayRoutines.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        _showOtherDays ? Icons.visibility : Icons.visibility_off,
                        color: _showOtherDays ? white : MyColors.forthyColor,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _showOtherDays = !_showOtherDays);
                        FilterService.instance.setShowOtherDayRoutines(_showOtherDays);
                      },
                      tooltip: _showOtherDays ? 'Hide other days' : 'Show other days',
                    ),
                  IconButton(
                    icon: const Icon(Icons.add, color: white),
                    onPressed: () => _showRoutineForm(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRoutineListChildren() {
    return [
      ..._routines.map((r) => _buildRoutineTile(r, isOtherDay: false)),
      if (_showOtherDays && _otherDayRoutines.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.calendar_month,
                  size: 14, color: MyColors.forthyColor.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                'Other days',
                style: TextStyle(
                  color: MyColors.forthyColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: MyColors.forthyColor.withValues(alpha: 0.2),
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        ..._otherDayRoutines.map((r) => _buildRoutineTile(r, isOtherDay: true)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtrl = widget.sheetScrollController;

    if (sheetCtrl != null) {
      final empty = _routines.isEmpty && (!_showOtherDays || _otherDayRoutines.isEmpty);
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
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.35,
                            child: _buildEmptyState(),
                          ),
                        ],
                      )
                    : ListView(
                        controller: sheetCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: _buildRoutineListChildren(),
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
            child: _routines.isEmpty && (!_showOtherDays || _otherDayRoutines.isEmpty)
                ? _buildEmptyState()
                : ListView(
                    children: _buildRoutineListChildren(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineTile(Routine routine, {required bool isOtherDay}) {
    return Dismissible(
      key: Key('${routine.id}_${isOtherDay ? 'other' : 'today'}'),
      direction: DismissDirection.horizontal,
      background: Container(
        color: MyColors.fivyColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.edit, color: white),
      ),
      secondaryBackground: Container(
        color: MyColors.remove,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _showRoutineForm(routine);
          return false;
        } else {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: cardColor,
              title: const Text('Delete Routine', style: TextStyle(color: white)),
              content: Text(
                'Are you sure you want to delete "${routine.name}"?',
                style: const TextStyle(color: white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: MyColors.fivyColor)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete',
                      style: TextStyle(color: MyColors.remove)),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteRoutine(routine);
        }
      },
      child: Opacity(
        opacity: isOtherDay ? 0.5 : 1.0,
        child: ListTile(
          onTap: isOtherDay ? () => _showRoutineForm(routine) : () => _toggleRoutineDone(routine),
          leading: isOtherDay
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.calendar_today, color: MyColors.forthyColor, size: 20),
                )
              : Checkbox(
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
              color: isOtherDay
                  ? MyColors.forthyColor
                  : routine.isDone
                      ? MyColors.forthyColor
                      : white,
              decoration: routine.isDone && !isOtherDay ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            isOtherDay
                ? '${routine.time.format(context)} · ${_formatDaysOfWeek(routine.daysOfWeek)}'
                : '${routine.time.format(context)} - ${_formatDaysOfWeek(routine.daysOfWeek)}',
            style: TextStyle(
              color: isOtherDay ? MyColors.trecondaryColor : (routine.isDone ? MyColors.trecondaryColor : MyColors.fivyColor),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isOtherDay && routine.showStreak && routine.streak > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MyColors.fivyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '${routine.streak}',
                          style: const TextStyle(
                            color: MyColors.fivyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: MyColors.fivyColor),
                onPressed: () => _showCalendarHistory(routine),
                tooltip: 'View completion history',
              ),
            ],
          ),
        ),
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
  late final TextEditingController _periodController;
  late final TextEditingController _intervalController;
  TimeOfDay _time = TimeOfDay.now();
  final List<bool> _daysOfWeek = List.filled(7, false);
  int _periodAfter = 30;
  int _interval = 10;
  bool _showStreak = true;
  int _priority = 2;

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _nameController.text = widget.routine!.name;
      _time = widget.routine!.time;
      _daysOfWeek.setAll(0, widget.routine!.daysOfWeek);
      _periodAfter = widget.routine!.periodAfter;
      _interval = widget.routine!.interval;
      _showStreak = widget.routine!.showStreak;
      _priority = widget.routine!.priority;
    }
    _periodController = TextEditingController(text: _periodAfter.toString());
    _intervalController = TextEditingController(text: _interval.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _periodController.dispose();
    _intervalController.dispose();
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
      showStreak: _showStreak,
      isDone: widget.routine?.isDone ?? false,
      streak: widget.routine?.streak ?? 0,
      lastCompletedDate: widget.routine?.lastCompletedDate,
      priority: _priority,
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
                    controller: _periodController,
                    decoration: const InputDecoration(
                      labelText: 'Period (min)',
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _periodAfter = int.tryParse(value) ?? 30;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _intervalController,
                    decoration: const InputDecoration(
                      labelText: 'Interval (min)',
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _interval = int.tryParse(value) ?? 10;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReminderTimelineWidget(
              scheduledTime: _time,
              periodAfter: _periodAfter,
              interval: _interval,
              onPeriodAfterChanged: (value) {
                setState(() {
                  _periodAfter = value;
                  _periodController.text = value.toString();
                });
              },
              onIntervalChanged: (value) {
                setState(() {
                  _interval = value;
                  _intervalController.text = value.toString();
                });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Streak'),
              subtitle: const Text('Display streak count when completing this routine'),
              value: _showStreak,
              onChanged: (value) {
                setState(() {
                  _showStreak = value;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildPrioritySlider(),
            const SizedBox(height: 16),
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
