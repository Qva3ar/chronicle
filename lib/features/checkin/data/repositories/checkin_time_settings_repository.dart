import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Repository for managing checkin notification time settings
class CheckinTimeSettingsRepository {
  static const String _morningTimeKey = 'checkin_morning_time';
  static const String _eveningTimeKey = 'checkin_evening_time';

  // Default times
  static const TimeOfDay defaultMorningTime = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay defaultEveningTime = TimeOfDay(hour: 22, minute: 0);

  /// Load morning checkin time
  Future<TimeOfDay> loadMorningTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_morningTimeKey);

    if (timeString == null) {
      return defaultMorningTime;
    }

    return _parseTimeOfDay(timeString) ?? defaultMorningTime;
  }

  /// Load evening checkin time
  Future<TimeOfDay> loadEveningTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_eveningTimeKey);

    if (timeString == null) {
      return defaultEveningTime;
    }

    return _parseTimeOfDay(timeString) ?? defaultEveningTime;
  }

  /// Save morning checkin time
  Future<void> saveMorningTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_morningTimeKey, _formatTimeOfDay(time));
  }

  /// Save evening checkin time
  Future<void> saveEveningTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eveningTimeKey, _formatTimeOfDay(time));
  }

  /// Format TimeOfDay to string (HH:mm)
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Parse TimeOfDay from string (HH:mm)
  TimeOfDay? _parseTimeOfDay(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return null;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
}
