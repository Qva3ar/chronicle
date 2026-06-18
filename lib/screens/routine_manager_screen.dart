import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/services/daily_reset_service.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/shared/chrono_ui.dart';
import 'package:chrono/screens/routine_calendar_screen.dart';
import 'package:chrono/services/routine_widget_service.dart';
import 'package:chrono/services/filter_service.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:chrono/widgets/reminder_timeline_widget.dart';
import 'package:chrono/shared/premium_gate.dart';

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
  List<Routine> _archivedRoutines = [];
  bool _showOtherDays = false;
  bool _showArchived = false;

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

    final active = allRoutines.where((r) => !r.isArchived).toList();
    final archived = allRoutines.where((r) => r.isArchived).toList();

    final todayList = active
        .where((r) => r.isActiveOnDay(currentDayIndex))
        .toList();

    final otherDayList = active
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
      _archivedRoutines = archived;
    });
  }

  Future<void> _toggleRoutineDone(Routine routine) async {
    if (!checkPremiumOrShowPaywall(context)) return;
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
            DatabaseColumns.recordText: jsonEncode({
              'routine_id': routine.id,
              'routine_name': routine.name,
              'status': 'completed',
            }),
            DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
            DatabaseColumns.recordType: 'routine',
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

  Future<void> _archiveRoutine(Routine routine, bool archive) async {
    if (archive) {
      await _notifications.cancelRoutineNotification(routine.id!);
    }
    await _db.updateRoutine(routine.id!, {
      DatabaseColumns.routineIsArchived: archive ? 1 : 0,
    });
    if (!archive) {
      // Reschedule notifications when unarchiving
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

  Future<void> _deleteRoutine(Routine routine) async {
    // Remove all routine data including notifications and alarms
    await _notifications.cancelRoutineNotification(routine.id!);
    // Delete the routine from database
    await _db.deleteRoutine(routine.id!);
    await _loadRoutines();
    await _updateWidget();
  }

  Widget _buildHeader() {
    return ChronoSheetHeader(
      title: 'Routines',
      titleIcon: Icons.arrow_upward_rounded,
      itemCount: _routines.length,
      actions: [
        if (_otherDayRoutines.isNotEmpty)
          IconButton(
            icon: Icon(
              _showOtherDays ? Icons.visibility : Icons.visibility_off,
              color: _showOtherDays ? textPrimary : textMuted,
              size: 20,
            ),
            onPressed: () {
              setState(() => _showOtherDays = !_showOtherDays);
              FilterService.instance.setShowOtherDayRoutines(_showOtherDays);
            },
            tooltip: _showOtherDays ? 'Hide other days' : 'Show other days',
          ),
        IconButton(
          icon: const Icon(Icons.add, color: textPrimary),
          onPressed: () {
            if (!checkPremiumOrShowPaywall(context)) return;
            _showRoutineForm();
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
    bool expanded = true,
  }) {
    final c = color ?? MyColors.forthyColor.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: c,
              ),
            ],
            const SizedBox(width: 8),
            Expanded(child: Divider(color: c.withValues(alpha: 0.3), height: 1)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoutineListChildren() {
    return [
      ..._routines.map((r) => _buildRoutineTile(r, isOtherDay: false)),
      if (_showOtherDays && _otherDayRoutines.isNotEmpty) ...[
        _buildSectionHeader(icon: Icons.calendar_month, label: 'Other days'),
        ..._otherDayRoutines.map((r) => _buildRoutineTile(r, isOtherDay: true)),
      ],
      if (_archivedRoutines.isNotEmpty) ...[
        _buildSectionHeader(
          icon: Icons.archive_outlined,
          label: 'Archived (${_archivedRoutines.length})',
          color: textHint,
          onTap: () => setState(() => _showArchived = !_showArchived),
          expanded: _showArchived,
        ),
        if (_showArchived)
          ..._archivedRoutines.map((r) => _buildRoutineTile(r, isArchived: true)),
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
                          _buildEmptyState(),
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

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1: return textMuted;
      case 2: return infoColor;
      case 3: return warningColor;
      case 4: return MyColors.remove;
      default: return infoColor;
    }
  }

  Widget _buildRoutineTile(Routine routine, {bool isOtherDay = false, bool isArchived = false}) {
    final prioColor = _priorityColor(routine.priority);
    final dimmed = isOtherDay || isArchived;

    return Dismissible(
      key: Key('${routine.id}_${isArchived ? 'archived' : isOtherDay ? 'other' : 'today'}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isArchived ? successColor : infoColor,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Icon(isArchived ? Icons.unarchive : Icons.edit, color: white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isArchived ? MyColors.remove : textMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(isArchived ? Icons.delete : Icons.archive, color: white),
      ),
      confirmDismiss: (direction) async {
        if (isArchived) {
          if (direction == DismissDirection.startToEnd) {
            // Unarchive
            _archiveRoutine(routine, false);
            return false;
          } else {
            // Delete
            return await _confirmDeleteDialog(routine);
          }
        }
        if (direction == DismissDirection.startToEnd) {
          _showRoutineForm(routine);
          return false;
        } else {
          // Archive
          _archiveRoutine(routine, true);
          return false;
        }
      },
      onDismissed: (direction) {
        if (isArchived && direction == DismissDirection.endToStart) {
          _deleteRoutine(routine);
        }
      },
      child: Opacity(
        opacity: dimmed ? 0.5 : 1.0,
        child: ChronoCard(
          leftIndicator: prioColor.withValues(alpha: isArchived ? 0.3 : 0.7),
          borderColor: routine.isDone && !dimmed
              ? successColor.withValues(alpha: 0.3)
              : cardBorder.withValues(alpha: 0.3),
          onTap: isArchived
              ? () => _archiveRoutine(routine, false)
              : isOtherDay
                  ? () => _showRoutineForm(routine)
                  : () => _toggleRoutineDone(routine),
          child: Row(
            children: [
              // Checkbox / calendar / archive icon
              if (isArchived)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.archive_outlined, color: textHint, size: 20),
                )
              else if (isOtherDay)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.calendar_today, color: textMuted, size: 20),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: routine.isDone,
                      onChanged: (_) => _toggleRoutineDone(routine),
                      checkColor: cardColor2,
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return successColor;
                        }
                        return textMuted;
                      }),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

              // Name + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: TextStyle(
                        color: dimmed
                            ? textMuted
                            : routine.isDone
                                ? textMuted
                                : textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: routine.isDone && !dimmed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArchived
                          ? '${routine.time.format(context)} · ${_formatDaysOfWeek(routine.daysOfWeek)}'
                          : isOtherDay
                              ? '${routine.time.format(context)} · ${_formatDaysOfWeek(routine.daysOfWeek)}'
                              : '${routine.time.format(context)} — ${_formatDaysOfWeek(routine.daysOfWeek)}',
                      style: TextStyle(
                        color: dimmed ? textHint : routine.isDone ? textHint : textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Streak badge + calendar
              if (!dimmed && routine.showStreak && routine.streak > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChronoBadge(
                    label: '${routine.streak}',
                    icon: Icons.local_fire_department,
                    color: warningColor,
                  ),
                ),
              if (!isArchived)
                IconButton(
                  icon: Icon(Icons.calendar_today, color: textMuted, size: 18),
                  onPressed: () => _showCalendarHistory(routine),
                  tooltip: 'View completion history',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteDialog(Routine routine) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Delete Routine', style: TextStyle(color: textPrimary)),
        content: Text(
          'Are you sure you want to delete "${routine.name}"?',
          style: const TextStyle(color: textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: MyColors.remove)),
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
    return ChronoEmptyState(
      icon: Icons.schedule_outlined,
      title: 'No Routines Yet',
      subtitle: 'Create your first routine to build consistent daily habits and stay organized.',
      buttonLabel: 'Create Your First Routine',
      onButton: () => _showRoutineForm(),
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
      isArchived: widget.routine?.isArchived ?? false,
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

    await ProductivityService.instance.createOrUpdateDailyRecord();

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
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _priorityColor(_priority),
            inactiveTrackColor: cardBorder,
            thumbColor: _priorityColor(_priority),
            overlayColor: _priorityColor(_priority).withValues(alpha: 0.2),
            valueIndicatorColor: _priorityColor(_priority),
            trackHeight: 4,
          ),
          child: Slider(
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
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _priorityLabels[_priority] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _priorityColor(_priority),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _priorityDescriptions[_priority] ?? '',
                  style: const TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return textMuted;
      case 2:
        return infoColor;
      case 3:
        return warningColor;
      case 4:
        return MyColors.remove;
      default:
        return infoColor;
    }
  }

  InputDecoration _inputDecoration(String label, {String? helperText, String? suffixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textMuted),
      helperText: helperText,
      helperStyle: const TextStyle(color: textHint, fontSize: 12),
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: textMuted),
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
    bool isEditing = widget.routine != null;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          isEditing ? 'Edit Routine' : 'New Routine',
          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _saveRoutine,
            child: Text(
              isEditing ? 'Save' : 'Create',
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
            // ── Basic Info ──
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: textPrimary, fontSize: 16),
              decoration: _inputDecoration('Routine Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 24),

            // ── Schedule ──
            ChronoSettingsGroup(
              title: 'Schedule',
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: const Text('Time', style: TextStyle(color: textPrimary, fontSize: 16)),
                  subtitle: Text(_time.format(context), style: const TextStyle(color: textMuted)),
                  trailing: const Icon(Icons.access_time_rounded, color: textSecondary),
                  onTap: _selectTime,
                ),
                Divider(height: 1, color: cardBorder.withValues(alpha: 0.5)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Days of Week', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 4.0;
                          const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final raw = (constraints.maxWidth - 6 * gap) / 7;
                          final diameter = raw.clamp(32.0, 44.0);
                          final fontSize = (diameter * 0.38).clamp(12.0, 15.0);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(7, (i) {
                              final isSelected = _daysOfWeek[i];
                              return Padding(
                                padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _daysOfWeek[i] = !isSelected;
                                      });
                                    },
                                    customBorder: const CircleBorder(),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: diameter,
                                      height: diameter,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? MyColors.orangeDivider.withValues(alpha: 0.15) : cardColor3,
                                        border: Border.all(
                                          color: isSelected ? MyColors.orangeDivider.withValues(alpha: 0.5) : cardBorder.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        dayLetters[i],
                                        style: TextStyle(
                                          color: isSelected ? MyColors.orangeDivider : textMuted,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: fontSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Reminders & Persistence ──
            ChronoSettingsGroup(
              title: 'Reminders & Persistence',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _periodController,
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDecoration('Duration', suffixText: 'min'),
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
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDecoration('Interval', suffixText: 'min'),
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: ReminderTimelineWidget(
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
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Extras & Importance ──
            ChronoSettingsGroup(
              title: 'Additional',
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: const Text('Track streak', style: TextStyle(color: textPrimary, fontSize: 15)),
                  subtitle: const Text('Display streak count when completing this routine', style: TextStyle(color: textMuted, fontSize: 13)),
                  activeColor: MyColors.orangeDivider,
                  value: _showStreak,
                  onChanged: (value) {
                    setState(() {
                      _showStreak = value;
                    });
                  },
                ),
                Divider(height: 1, color: cardBorder.withValues(alpha: 0.5)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: _buildPrioritySlider(),
                ),
              ],
            ),

            const SizedBox(height: 80), // Padding for sticky bottom button
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saveRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.orangeDivider,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                isEditing ? 'Update Routine' : 'Create Routine',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
