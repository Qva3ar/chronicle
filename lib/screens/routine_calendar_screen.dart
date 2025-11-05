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

  @override
  void initState() {
    super.initState();
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

      setState(() {
        _completionDates = dates;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.secondaryColor,
      appBar: AppBar(
        title: Text('${widget.routine.name} - History'),
        backgroundColor: cardColor,
        foregroundColor: white,
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
                  if (widget.routine.showStreak && widget.routine.streak > 0)
                    _buildStatItem(
                      icon: null,
                      emoji: '🔥',
                      label: 'Current Streak',
                      value: '${widget.routine.streak}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  outsideTextStyle: TextStyle(color: MyColors.forthyColor),
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
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: const TextStyle(color: white),
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
                            style: TextStyle(
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
