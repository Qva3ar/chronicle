import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Centralized timezone setup for scheduling local notifications.
///
/// Sets `tz.local` to the device's real IANA timezone (e.g.
/// "Asia/Yekaterinburg") so that `zonedSchedule` fires at the wall-clock time
/// the user picked. This replaces the previous name-guessing heuristic that
/// defaulted to Europe/Moscow and caused notifications to fire with an offset
/// (e.g. +2h for UTC+5 devices).
///
/// Safe to call multiple times and from background isolates (WorkManager),
/// where the timezone database must be re-initialized per isolate.
class TimezoneHelper {
  static bool _dataInitialized = false;

  static Future<void> ensureInitialized() async {
    if (!_dataInitialized) {
      tzdata.initializeTimeZones();
      _dataInitialized = true;
    }

    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final id = info.identifier;
      tz.setLocalLocation(tz.getLocation(id));
      debugPrint('[Timezone] local set to $id');
    } catch (e) {
      debugPrint('[Timezone] Failed to detect device timezone: $e — using UTC');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
  }
}
