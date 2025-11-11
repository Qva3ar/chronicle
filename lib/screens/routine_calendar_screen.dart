import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/colors.dart';

class RoutineCalendarScreen extends StatefulWidget {
  final Routine routine;

  const RoutineCalendarScreen({super.key, required this.routine});

  @override
  State<RoutineCalendarScreen> createState() => _RoutineCalendarScreenState();
}

class _RoutineCalendarScreenState extends State<RoutineCalendarScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _completionDates = {};
  Routine? _currentRoutine;
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _currentRoutine = widget.routine;
    _loadCompletionDates();
  }

  Future<void> _loadCompletionDates() async {
    try {
      // Query the record table for all records associated with this routine
      final records = await _db.getRecordsByRoutineId(widget.routine.id!);

      final Set<DateTime> dates = {};
      for (var record in records) {
        final timestamp = record[DatabaseColumns.recordCreatedAt] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        // Normalize to just the date (no time component)
        dates.add(DateTime(date.year, date.month, date.day));
      }

      // Reload routine data to get updated streak
      final routineData = await _db.getAllRoutines();
      final updatedRoutine = routineData
          .map((r) => Routine.fromMap(r))
          .firstWhere((r) => r.id == widget.routine.id);

      setState(() {
        _completionDates = dates;
        _currentRoutine = updatedRoutine;
      });
    } catch (e) {
      log('Error loading completion dates: $e');
    }
  }

  bool _isCompletionDate(DateTime day) {
    return _completionDates.any((date) =>
      date.year == day.year &&
      date.month == day.month &&
      date.day == day.day
    );
  }

  bool _isScheduledDay(DateTime day) {
    final int dayIndex = day.weekday - 1; // Convert to 0-based index (Monday = 0)
    return widget.routine.daysOfWeek[dayIndex];
  }

  Future<void> _handleDateTap(DateTime selectedDay) async {
    final DateTime today = DateTime.now();
    final DateTime todayNormalized = DateTime(today.year, today.month, today.day);
    final DateTime selectedNormalized = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    // Check if it's a past date
    if (selectedNormalized.isAfter(todayNormalized) || selectedNormalized.isAtSameMomentAs(todayNormalized)) {
      return; // Can't backdate today or future dates
    }

    // Check if it's within the 7-day window
    final int daysDifference = todayNormalized.difference(selectedNormalized).inDays;
    if (daysDifference > 7) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Can only backdate completions within the last 7 days'),
            backgroundColor: MyColors.remove,
          ),
        );
      }
      return;
    }

    // Check if it's a scheduled day
    if (!_isScheduledDay(selectedDay)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Routine is not scheduled for this day of the week'),
            backgroundColor: MyColors.remove,
          ),
        );
      }
      return;
    }

    // Check if already completed
    if (_isCompletionDate(selectedDay)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Routine already completed on this date'),
            backgroundColor: MyColors.fivyColor,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Mark as Complete', style: TextStyle(color: white)),
        content: Text(
          'Mark "${widget.routine.name}" as completed on ${selectedDay.day}/${selectedDay.month}/${selectedDay.year}?\n\nThis will update your streak accordingly.',
          style: const TextStyle(color: white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: MyColors.forthyColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: MyColors.fivyColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.backdateRoutineCompletion(widget.routine.id!, selectedDay);
        await _loadCompletionDates();
        _dataChanged = true; // Mark that data has changed

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Routine completion added successfully'),
              backgroundColor: MyColors.fivyColor,
            ),
          );
        }
      } catch (e) {
        log('Error backdating routine: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: MyColors.remove,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Handle system back button
          Navigator.pop(context, _dataChanged);
        }
      },
      child: Scaffold(
        backgroundColor: MyColors.secondaryColor,
        appBar: AppBar(
          title: Text('${widget.routine.name} - History'),
          backgroundColor: cardColor,
          foregroundColor: white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dataChanged),
          ),
        ),
        body: Column(
        children: [
          const SizedBox(height: 16),
          // Stats Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.check_circle_outline,
                    label: 'Total Completions',
                    value: '${_completionDates.length}',
                  ),
                  if (_currentRoutine?.showStreak == true && (_currentRoutine?.streak ?? 0) > 0)
                    _buildStatItem(
                      icon: null,
                      emoji: '🔥',
                      label: 'Current Streak',
                      value: '${_currentRoutine?.streak ?? 0}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Hint about backdating
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MyColors.fivyColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MyColors.fivyColor.withAlpha(77),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: MyColors.fivyColor,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tap any past date (within 7 days) to mark as complete',
                      style: TextStyle(
                        color: MyColors.fivyColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Calendar
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _handleDateTap(selectedDay);
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  // Today's date
                  todayDecoration: BoxDecoration(
                    color: MyColors.fivyColor.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: white,
                    fontWeight: FontWeight.bold,
                  ),
                  // Selected date
                  selectedDecoration: const BoxDecoration(
                    color: MyColors.fivyColor,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: white,
                    fontWeight: FontWeight.bold,
                  ),
                  // Completion dates - highlighted
                  markerDecoration: const BoxDecoration(
                    color: MyColors.fivyColor,
                    shape: BoxShape.circle,
                  ),
                  // Default text colors
                  defaultTextStyle: const TextStyle(color: white),
                  weekendTextStyle: const TextStyle(color: MyColors.fivyColor),
                  outsideTextStyle: const TextStyle(color: MyColors.forthyColor),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  titleTextStyle: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  leftChevronIcon: Icon(Icons.chevron_left, color: white),
                  rightChevronIcon: Icon(Icons.chevron_right, color: white),
                  formatButtonTextStyle: TextStyle(color: white),
                  formatButtonDecoration: BoxDecoration(
                    border: Border.fromBorderSide(BorderSide(color: white)),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: white),
                  weekendStyle: TextStyle(color: MyColors.fivyColor),
                ),
                calendarBuilders: CalendarBuilders(
                  // Custom builder to highlight completion dates
                  defaultBuilder: (context, day, focusedDay) {
                    if (_isCompletionDate(day)) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MyColors.fivyColor.withAlpha(77),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MyColors.fivyColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    if (_isCompletionDate(day)) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MyColors.fivyColor.withAlpha(51),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MyColors.fivyColor.withAlpha(128),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: MyColors.forthyColor,
                            ),
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: MyColors.fivyColor.withAlpha(77),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MyColors.fivyColor,
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Completed on this day',
                    style: TextStyle(color: white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatItem({
    IconData? icon,
    String? emoji,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        if (icon != null)
          Icon(icon, color: MyColors.fivyColor, size: 32)
        else if (emoji != null)
          Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: MyColors.forthyColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
