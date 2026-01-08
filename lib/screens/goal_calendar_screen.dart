import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../colors.dart';
import '../db_manager.dart';
import '../models/goal.model.dart';
import '../record.service.dart';

class GoalCalendarScreen extends StatefulWidget {
  final Goal goal;

  const GoalCalendarScreen({super.key, required this.goal});

  @override
  State<GoalCalendarScreen> createState() => _GoalCalendarScreenState();
}

class _GoalCalendarScreenState extends State<GoalCalendarScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // minutes per day; we keep max per day to avoid double-counting if duplicates exist.
  final Map<DateTime, int> _minutesByDay = {};
  int _totalMinutes = 0;
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _loadGoalHistory();
  }

  Future<void> _loadGoalHistory() async {
    try {
      final records = await _db.getRecordsByGoalId(widget.goal.id!);

      final Map<DateTime, int> minutesByDay = {};
      for (final r in records) {
        final createdAt = r[DatabaseColumns.recordCreatedAt] as int?;
        final text = (r[DatabaseColumns.recordText] as String?) ?? '';
        if (createdAt == null) continue;

        final day = DateTime.fromMillisecondsSinceEpoch(createdAt);
        final dayKey = DateTime(day.year, day.month, day.day);

        final minutes = _extractTimeMinutes(text);
        if (minutes == null) continue;

        final current = minutesByDay[dayKey] ?? 0;
        if (minutes > current) minutesByDay[dayKey] = minutes;
      }

      final totalMinutes = minutesByDay.values.fold<int>(0, (a, b) => a + b);

      if (!mounted) return;
      setState(() {
        _minutesByDay
          ..clear()
          ..addAll(minutesByDay);
        _totalMinutes = totalMinutes;
      });
    } catch (e) {
      log('Error loading goal history: $e');
    }
  }

  int? _extractTimeMinutes(String text) {
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) {
        final tm = data['time_minutes'];
        if (tm is int) return tm;
        if (tm is num) return tm.toInt();
      }
    } catch (_) {
      // Fallback for legacy text format
      final match = RegExp(r'time_minutes: (\d+)').firstMatch(text);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    return null;
  }

  bool _hasWork(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _minutesByDay.containsKey(key);
  }

  Widget _buildWorkDayCell(
    DateTime day, {
    bool isOutside = false,
    bool isSelected = false,
    bool isToday = false,
  }) {
    // Green fill means "has work record"
    // Border indicates state (selected/today/outside)
    final Color borderColor = isSelected
        ? MyColors.forthyColor
        : (isToday ? MyColors.fivyColor : Colors.transparent);

    final TextStyle textStyle = TextStyle(
      color: isOutside ? MyColors.fivyColor.withAlpha(160) : white,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
    );

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(90),
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: (isSelected || isToday) ? 2 : 0,
        ),
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: textStyle,
        ),
      ),
    );
  }

  int _minutesFor(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _minutesByDay[key] ?? 0;
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    if (m <= 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Future<void> _handleDateTap(DateTime selectedDay) async {
    if (widget.goal.isArchived) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This goal is completed and cannot be edited'),
          backgroundColor: MyColors.remove,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    // Can't backdate today or future days (same behavior as routines)
    if (!selected.isBefore(today)) return;

    // If already has work recorded, do nothing (avoid duplicates)
    if (_hasWork(selectedDay)) return;

    final targetMinutes = (widget.goal.hours * 60) + widget.goal.minutes;
    final controller = TextEditingController(
      text: widget.goal.sessionMinutes.toString(),
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Add work session', style: TextStyle(color: white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add "${widget.goal.title}" work for ${selected.day}/${selected.month}/${selected.year}',
              style: const TextStyle(color: white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: white),
              decoration: InputDecoration(
                labelText: 'Minutes',
                labelStyle: const TextStyle(color: MyColors.fivyColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: MyColors.fivyColor.withAlpha(80),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: MyColors.fivyColor),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daily target: $targetMinutes min',
              style: const TextStyle(color: MyColors.fivyColor, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: MyColors.forthyColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Confirm', style: TextStyle(color: MyColors.fivyColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final minutes = int.tryParse(controller.text.trim());
    if (minutes == null || minutes <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of minutes'),
          backgroundColor: MyColors.remove,
        ),
      );
      return;
    }

    final status = minutes >= targetMinutes ? 'completed' : 'day_ended';

    // Use midday to avoid timezone/DST edge cases shifting the calendar date.
    final createdAt = DateTime(
      selected.year,
      selected.month,
      selected.day,
      12,
      0,
      0,
    ).millisecondsSinceEpoch;

    final recordData = {
      'goal_id': widget.goal.id,
      'time_minutes': minutes,
      'status': status,
    };

    final record = {
      DatabaseColumns.recordTitle: widget.goal.title,
      DatabaseColumns.recordText: jsonEncode(recordData),
      DatabaseColumns.recordCreatedAt: createdAt,
      DatabaseColumns.recordType: 'goal',
      DatabaseColumns.recordGoalId: widget.goal.id,
    };

    try {
      await RecordService().createRecord(record, []);
      _dataChanged = true;
      await _loadGoalHistory();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added successfully'),
          backgroundColor: MyColors.fivyColor,
        ),
      );
    } catch (e) {
      log('Error creating backdated goal record: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: MyColors.remove,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMinutes =
        _selectedDay == null ? null : _minutesFor(_selectedDay!);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          Navigator.pop(context, _dataChanged);
        }
      },
      child: Scaffold(
        backgroundColor: MyColors.secondaryColor,
        appBar: AppBar(
          title: Text('${widget.goal.title} - History'),
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

            // Hint (same idea as routines)
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
                        'Tap any past date to add a work session',
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

            const SizedBox(height: 16),
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
                    _stat('Total days', '${_minutesByDay.length}'),
                    _stat('Total time', _formatMinutes(_totalMinutes)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                        onDaySelected: (selected, focused) async {
                          setState(() {
                            _selectedDay = selected;
                            _focusedDay = focused;
                          });

                          // If day doesn't have a record yet, offer to create one.
                          if (!_hasWork(selected)) {
                            await _handleDateTap(selected);
                          }
                        },
                        onFormatChanged: (format) =>
                            setState(() => _calendarFormat = format),
                        onPageChanged: (focused) => _focusedDay = focused,
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: MyColors.fivyColor.withAlpha(90),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: MyColors.forthyColor,
                            shape: BoxShape.circle,
                          ),
                          defaultTextStyle: const TextStyle(color: white),
                          weekendTextStyle:
                              const TextStyle(color: MyColors.fivyColor),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focused) {
                            if (_hasWork(day)) {
                              return _buildWorkDayCell(day);
                            }
                            return null;
                          },
                          outsideBuilder: (context, day, focused) {
                            if (_hasWork(day)) {
                              return _buildWorkDayCell(day, isOutside: true);
                            }
                            return null;
                          },
                          todayBuilder: (context, day, focused) {
                            if (_hasWork(day)) {
                              return _buildWorkDayCell(day, isToday: true);
                            }
                            return null;
                          },
                          selectedBuilder: (context, day, focused) {
                            if (_hasWork(day)) {
                              return _buildWorkDayCell(day, isSelected: true);
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    if (_selectedDay != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            selectedMinutes == null
                                ? 'No data'
                                : 'Time on this day: ${_formatMinutes(selectedMinutes)}',
                            style: const TextStyle(color: white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: MyColors.fivyColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}


