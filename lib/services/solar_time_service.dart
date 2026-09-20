import 'package:daylight/daylight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db_manager.dart';
import '../models/routine.model.dart';
import 'timezone_coordinates.dart';

/// Outcome of a GPS location refresh, so the UI can tell the user what to do
/// next instead of just failing silently.
enum SolarLocationResult {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

/// Resolves routine times that are anchored to sunrise or sunset.
///
/// Coordinates live in SharedPreferences and are cached in memory so that
/// [sunriseFor], [sunsetFor] and [resolveRoutineTime] can stay synchronous —
/// routine sorting and list rendering call them on every build.
///
/// Accuracy note: the underlying algorithm is good to about a minute, but real
/// sunset also shifts with elevation (Tashkent at 450 m sets roughly 4 minutes
/// later than sea level) and with atmospheric refraction. Rather than chase
/// those separately, [sunriseCorrectionMinutes] and [sunsetCorrectionMinutes]
/// let the user calibrate against their own local timetable once.
class SolarTimeService {
  SolarTimeService._();

  static final SolarTimeService instance = SolarTimeService._();

  static const _latKey = 'solar_lat';
  static const _lngKey = 'solar_lng';
  static const _labelKey = 'solar_location_label';
  static const _sourceKey = 'solar_location_source';
  static const _zoneKey = 'solar_location_zone';
  static const _updatedAtKey = 'solar_location_updated_at';

  /// Location derived from the device timezone. Good to a few minutes of solar
  /// time and needs no permission, so it is the default.
  static const String sourceTimezone = 'timezone';

  /// Location from a one-off GPS reading. Sticks until the user resets it.
  static const String sourceGps = 'gps';
  static const _sunriseCorrectionKey = 'solar_sunrise_correction_min';
  static const _sunsetCorrectionKey = 'solar_sunset_correction_min';

  /// Bound on the user-facing calibration, wide enough to absorb elevation and
  /// timetable conventions without letting a typo move a routine by hours.
  static const int maxCorrectionMinutes = 30;

  bool _loaded = false;
  double? _latitude;
  double? _longitude;
  String? _label;
  String? _source;
  String? _zone;
  DateTime? _updatedAt;
  int _sunriseCorrectionMinutes = 0;
  int _sunsetCorrectionMinutes = 0;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get label => _label;
  String? get source => _source;
  String? get zone => _zone;
  DateTime? get updatedAt => _updatedAt;

  bool get isFromGps => _source == sourceGps;
  int get sunriseCorrectionMinutes => _sunriseCorrectionMinutes;
  int get sunsetCorrectionMinutes => _sunsetCorrectionMinutes;

  bool get hasLocation => _latitude != null && _longitude != null;

  /// Loads persisted state. Safe to call repeatedly; must be called before any
  /// synchronous accessor, including from background isolates which start with
  /// a fresh, empty instance.
  Future<void> ensureInitialized() async {
    if (_loaded) return;
    await reload();
  }

  Future<void> reload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _latitude = prefs.getDouble(_latKey);
      _longitude = prefs.getDouble(_lngKey);
      _label = prefs.getString(_labelKey);
      _source = prefs.getString(_sourceKey);
      _zone = prefs.getString(_zoneKey);
      final updatedAtMillis = prefs.getInt(_updatedAtKey);
      _updatedAt = updatedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMillis);
      _sunriseCorrectionMinutes = prefs.getInt(_sunriseCorrectionKey) ?? 0;
      _sunsetCorrectionMinutes = prefs.getInt(_sunsetCorrectionKey) ?? 0;
      _loaded = true;
    } catch (e) {
      debugPrint('[SolarTime] Failed to load location: $e');
    }

    // A GPS fix is the user's explicit choice and outranks the timezone.
    // Otherwise seed — or re-seed after travel — from the device timezone so
    // solar routines work without asking for anything.
    if (!isFromGps) {
      await _seedFromTimezone();
    }
  }

  /// Fills in coordinates from the device's IANA timezone, which carries a
  /// representative city. Accurate to roughly a few minutes of solar time —
  /// within what [setCorrection] is there to absorb — and needs no permission.
  ///
  /// No-ops when the current location already came from this timezone.
  Future<bool> _seedFromTimezone() async {
    try {
      final id = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (hasLocation && _zone == id) return false;

      final coordinates = timezoneCoordinates[id];
      if (coordinates == null) {
        debugPrint('[SolarTime] No coordinates known for timezone $id');
        return false;
      }

      await _persistLocation(
        latitude: coordinates.$1,
        longitude: coordinates.$2,
        source: sourceTimezone,
        label: _cityFromZone(id),
        zone: id,
      );
      debugPrint('[SolarTime] Location seeded from timezone $id');
      return true;
    } catch (e) {
      debugPrint('[SolarTime] Timezone lookup failed: $e');
      return false;
    }
  }

  /// "America/Argentina/Buenos_Aires" -> "Buenos Aires".
  static String _cityFromZone(String zone) =>
      zone.split('/').last.replaceAll('_', ' ');

  // ── Location management ────────────────────────────────────────────────

  /// Takes a single low-accuracy reading. Coarse is deliberate: one degree of
  /// longitude is four minutes of time, so a few kilometres of error moves
  /// sunset by seconds, and it keeps the permission prompt cheap.
  Future<SolarLocationResult> refreshFromGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return SolarLocationResult.serviceDisabled;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return SolarLocationResult.permissionDeniedForever;
      }
      if (permission == LocationPermission.denied) {
        return SolarLocationResult.permissionDenied;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 30),
        ),
      );

      await _persistLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        source: sourceGps,
        label: null,
        zone: null,
      );
      return SolarLocationResult.success;
    } catch (e) {
      debugPrint('[SolarTime] GPS refresh failed: $e');
      return SolarLocationResult.failed;
    }
  }

  /// Drops a GPS fix and goes back to the timezone estimate.
  Future<bool> useTimezoneLocation() async {
    await clearLocation();
    return _seedFromTimezone();
  }

  @visibleForTesting
  Future<void> setManualLocation(
    double latitude,
    double longitude, {
    String? label,
  }) async {
    await _persistLocation(
      latitude: latitude,
      longitude: longitude,
      source: 'manual',
      label: label,
      zone: null,
    );
  }

  Future<void> clearLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
    await prefs.remove(_labelKey);
    await prefs.remove(_sourceKey);
    await prefs.remove(_zoneKey);
    await prefs.remove(_updatedAtKey);
    _latitude = null;
    _longitude = null;
    _label = null;
    _source = null;
    _zone = null;
    _updatedAt = null;
  }

  Future<void> _persistLocation({
    required double latitude,
    required double longitude,
    required String source,
    required String? label,
    required String? zone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setDouble(_latKey, latitude);
    await prefs.setDouble(_lngKey, longitude);
    await prefs.setString(_sourceKey, source);
    await prefs.setInt(_updatedAtKey, now.millisecondsSinceEpoch);
    if (label == null) {
      await prefs.remove(_labelKey);
    } else {
      await prefs.setString(_labelKey, label);
    }
    if (zone == null) {
      await prefs.remove(_zoneKey);
    } else {
      await prefs.setString(_zoneKey, zone);
    }
    _latitude = latitude;
    _longitude = longitude;
    _source = source;
    _label = label;
    _zone = zone;
    _updatedAt = now;
    _loaded = true;
  }

  Future<void> setCorrection(RoutineAnchor anchor, int minutes) async {
    final clamped = minutes.clamp(-maxCorrectionMinutes, maxCorrectionMinutes);
    final prefs = await SharedPreferences.getInstance();
    if (anchor == RoutineAnchor.sunrise) {
      await prefs.setInt(_sunriseCorrectionKey, clamped);
      _sunriseCorrectionMinutes = clamped;
    } else if (anchor == RoutineAnchor.sunset) {
      await prefs.setInt(_sunsetCorrectionKey, clamped);
      _sunsetCorrectionMinutes = clamped;
    }
  }

  int correctionFor(RoutineAnchor anchor) => switch (anchor) {
        RoutineAnchor.sunrise => _sunriseCorrectionMinutes,
        RoutineAnchor.sunset => _sunsetCorrectionMinutes,
        RoutineAnchor.fixed => 0,
      };

  // ── Solar calculation ──────────────────────────────────────────────────

  /// Local sunrise on [date], with the user's calibration applied. Null when no
  /// location is set or the sun does not rise that day (polar latitudes).
  DateTime? sunriseFor(DateTime date) =>
      _anchorTime(date, EventType.sunrise, _sunriseCorrectionMinutes);

  /// Local sunset on [date], with the user's calibration applied.
  DateTime? sunsetFor(DateTime date) =>
      _anchorTime(date, EventType.sunset, _sunsetCorrectionMinutes);

  DateTime? anchorTimeFor(RoutineAnchor anchor, DateTime date) =>
      switch (anchor) {
        RoutineAnchor.sunrise => sunriseFor(date),
        RoutineAnchor.sunset => sunsetFor(date),
        RoutineAnchor.fixed => null,
      };

  DateTime? _anchorTime(DateTime date, EventType type, int correctionMinutes) {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return null;

    try {
      // Anchor the query at UTC noon of the requested calendar day. The
      // calculator derives its day from `date.toUtc()`, so passing a local
      // midnight would silently ask for the previous day east of Greenwich.
      final utcNoon = DateTime.utc(date.year, date.month, date.day, 12);
      final event = DaylightCalculator(DaylightLocation(lat, lng))
          .calculateEvent(utcNoon, Zenith.official, type);
      if (event == null) return null;

      // Keep only the wall-clock time and re-anchor it to the requested date:
      // the event instant can land on the neighbouring UTC day, and callers
      // always mean "this time on this date". Round to the nearest minute so a
      // 18:28:55 sunset is not reported as 18:28.
      final local = event.toLocal();
      return DateTime(date.year, date.month, date.day, local.hour, local.minute)
          .add(Duration(
            minutes: correctionMinutes + (local.second >= 30 ? 1 : 0),
          ));
    } catch (e) {
      debugPrint('[SolarTime] Calculation failed for $date: $e');
      return null;
    }
  }

  /// The time an [anchor] plus [offsetMinutes] lands on for [date].
  ///
  /// Returns null for [RoutineAnchor.fixed] and whenever the anchor cannot be
  /// resolved, letting callers fall back to a stored time.
  TimeOfDay? resolveTime(RoutineAnchor anchor, int offsetMinutes, DateTime date) {
    final anchorTime = anchorTimeFor(anchor, date);
    if (anchorTime == null) return null;

    // Clamp inside the day: days_of_week and streaks are keyed to the calendar
    // date, so a large offset must not silently move the routine to another one.
    final minutes = (anchorTime.hour * 60 + anchorTime.minute + offsetMinutes)
        .clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// The time [routine] should fire on [date].
  TimeOfDay? resolveRoutineTime(Routine routine, DateTime date) =>
      resolveTime(routine.anchorType, routine.anchorOffsetMinutes, date);

  /// Next fire time for [routine], resolving each candidate day's sun times
  /// rather than reusing today's. Falls back to [Routine.time] per day when the
  /// routine is fixed or the anchor is unavailable.
  DateTime nextOccurrenceOf(Routine routine) {
    if (!routine.anchorType.isSolar || !hasLocation) {
      return routine.getNextOccurrence();
    }
    return routine.getNextOccurrence(
      resolveTime: (date) => resolveRoutineTime(routine, date) ?? routine.time,
    );
  }

  /// Recomputes and persists today's cached `time` for every active solar
  /// routine. Must run before notifications are rescheduled, otherwise the
  /// alarms are armed from yesterday's sun times.
  ///
  /// Returns how many routines were updated.
  Future<int> refreshSolarRoutineTimes() async {
    await ensureInitialized();
    if (!hasLocation) return 0;

    var updated = 0;
    try {
      final db = DatabaseHelper.instance;
      final rows = await db.getAllRoutines();
      final today = DateTime.now();

      for (final row in rows) {
        final routine = Routine.fromMap(row);
        if (!routine.anchorType.isSolar || routine.isArchived) continue;

        final resolved = resolveRoutineTime(routine, today);
        if (resolved == null) {
          // Polar day or night: keep the last known time rather than inventing
          // one, so the routine still fires at a sane hour.
          debugPrint(
              '[SolarTime] No ${routine.anchorType.name} today for "${routine.name}", keeping cached time');
          continue;
        }
        if (resolved == routine.time) continue;

        final formatted = '${resolved.hour.toString().padLeft(2, '0')}:'
            '${resolved.minute.toString().padLeft(2, '0')}';
        await db.updateRoutine(routine.id!, {DatabaseColumns.routineTime: formatted});
        updated++;
      }

      if (updated > 0) {
        debugPrint('[SolarTime] Refreshed $updated solar routine time(s)');
      }
    } catch (e, stackTrace) {
      debugPrint('[SolarTime] Failed to refresh solar routine times: $e');
      debugPrint('$stackTrace');
    }
    return updated;
  }
}
