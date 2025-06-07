import 'package:flutter/material.dart';

class Routine {
  final int? id;
  final String name;
  final TimeOfDay time;
  final List<bool> daysOfWeek;
  final int periodAfter;
  final int interval;
  final bool isDone;

  Routine({
    this.id,
    required this.name,
    required this.time,
    required this.daysOfWeek,
    required this.periodAfter,
    required this.interval,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'time':
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'days_of_week': daysOfWeek.map((day) => day ? '1' : '0').join(','),
      'period_after': periodAfter,
      'interval': interval,
      'is_done': isDone ? 1 : 0,
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    final timeParts = map['time'].split(':');
    final daysOfWeekString = map['days_of_week'] as String;

    return Routine(
      id: map['_id'] as int,
      name: map['name'] as String,
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      daysOfWeek: daysOfWeekString.split(',').map((day) => day == '1').toList(),
      periodAfter: map['period_after'] as int,
      interval: map['interval'] as int,
      isDone: map['is_done'] == 1,
    );
  }

  Routine copyWith({
    int? id,
    String? name,
    TimeOfDay? time,
    List<bool>? daysOfWeek,
    int? periodAfter,
    int? interval,
    bool? isDone,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      periodAfter: periodAfter ?? this.periodAfter,
      interval: interval ?? this.interval,
      isDone: isDone ?? this.isDone,
    );
  }

  bool isActiveOnDay(int dayIndex) {
    return daysOfWeek[dayIndex];
  }

  DateTime getNextOccurrence() {
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentDay = now.weekday - 1; // Convert to 0-based index (Monday = 0)

    // If the routine is active today and the time hasn't passed yet
    if (isActiveOnDay(currentDay) &&
        (currentTime.hour < time.hour ||
            (currentTime.hour == time.hour &&
                currentTime.minute < time.minute))) {
      return DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
    }

    // Find the next active day
    int daysToAdd = 1;
    while (daysToAdd <= 7) {
      final nextDay = (currentDay + daysToAdd) % 7;
      if (isActiveOnDay(nextDay)) {
        final nextDate = now.add(Duration(days: daysToAdd));
        return DateTime(
          nextDate.year,
          nextDate.month,
          nextDate.day,
          time.hour,
          time.minute,
        );
      }
      daysToAdd++;
    }

    // This should never happen if at least one day is active
    return now;
  }
}
