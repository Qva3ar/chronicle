import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

import '../colors.dart';
import '../db_manager.dart';
import '../models/goal.model.dart';
import '../record.service.dart';
import 'package:chrono/services/productivity_service.dart';

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

  /// Whether the goal is scheduled for the given calendar day's weekday.
  bool _isScheduledDay(DateTime day) {
    return widget.goal.isActiveOnDay(day.weekday - 1);
  }

  /// Dimmed cell for days the goal isn't scheduled on (no work recorded).
  Widget _buildOffScheduleCell(DateTime day, {bool isOutside = false}) {
    return Container(
      margin: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: (isOutside ? textMuted : textSecondary).withAlpha(90),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
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
        ? textMuted
        : (isToday ? MyColors.orangeDivider : Colors.transparent);

    final TextStyle textStyle = TextStyle(
      color: isOutside ? MyColors.orangeDivider.withAlpha(160) : textPrimary,
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
          SnackBar(
            content: Text(AppLocalizations.of(context).goalCompletedCannotEdit),
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

    // Can't log work on days the goal isn't scheduled for (same as routines)
    if (!_isScheduledDay(selectedDay)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).goalNotScheduled),
          backgroundColor: MyColors.remove,
        ),
      );
      return;
    }

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
        title: Text(AppLocalizations.of(context).goalAddWorkSession,
            style: const TextStyle(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).goalAddWorkFor(
                widget.goal.title,
                '${selected.day}/${selected.month}/${selected.year}',
              ),
              style: const TextStyle(color: textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).goalMinutes,
                labelStyle: const TextStyle(color: MyColors.orangeDivider),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: MyColors.orangeDivider.withAlpha(80),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: MyColors.orangeDivider),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).goalDailyTarget(targetMinutes),
              style: const TextStyle(color: MyColors.orangeDivider, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel,
                style: const TextStyle(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).commonConfirm,
                style: const TextStyle(color: MyColors.orangeDivider)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final minutes = int.tryParse(controller.text.trim());
    if (minutes == null || minutes <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).goalEnterValidMinutes),
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

      final dateStr = '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      try {
        await ProductivityService.instance.createOrUpdateDailyRecord(forDate: dateStr);
      } catch (e) {
        log('Error updating productivity for backdated goal: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).commonAddedSuccess),
          backgroundColor: MyColors.orangeDivider,
        ),
      );
    } catch (e) {
      log('Error creating backdated goal record: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
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
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).calendarTitleHistory(widget.goal.title)),
          backgroundColor: bgColor,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: textPrimary),
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
                  color: MyColors.orangeDivider.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MyColors.orangeDivider.withAlpha(77),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: MyColors.orangeDivider,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).goalTapPastDate,
                        style: const TextStyle(
                          color: MyColors.orangeDivider,
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
                            color: MyColors.orangeDivider.withAlpha(90),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: textMuted,
                            shape: BoxShape.circle,
                          ),
                          defaultTextStyle: const TextStyle(color: textPrimary),
                          weekendTextStyle:
                              const TextStyle(color: MyColors.orangeDivider),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focused) {
                            if (_hasWork(day)) {
                              return _buildWorkDayCell(day);
                            }
                            if (!_isScheduledDay(day)) {
                              return _buildOffScheduleCell(day);
                            }
                            return null;
                          },
                          outsideBuilder: (context, day, focused) {
                            if (_hasWork(day)) {
                              return _buildWorkDayCell(day, isOutside: true);
                            }
                            if (!_isScheduledDay(day)) {
                              return _buildOffScheduleCell(day, isOutside: true);
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
                                ? AppLocalizations.of(context).commonNoData
                                : 'Time on this day: ${_formatMinutes(selectedMinutes)}',
                            style: const TextStyle(color: textPrimary),
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
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: MyColors.orangeDivider,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}


