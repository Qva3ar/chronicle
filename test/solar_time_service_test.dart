import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chrono/models/routine.model.dart';
import 'package:chrono/services/solar_time_service.dart';

/// Tashkent. These tests assume the machine runs at UTC+5, matching the
/// coordinates, because the calculation converts the solar instant into device
/// local time the same way the app does.
const _lat = 41.2995;
const _lng = 69.2401;

Routine _routine({
  required RoutineAnchor anchor,
  required int offsetMinutes,
  List<bool>? days,
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0),
}) {
  return Routine(
    id: 1,
    name: 'test',
    time: time,
    daysOfWeek: days ?? List.filled(7, true),
    periodAfter: 30,
    interval: 10,
    anchorType: anchor,
    anchorOffsetMinutes: offsetMinutes,
  );
}

void main() {
  final service = SolarTimeService.instance;
  final isTashkentOffset = DateTime.now().timeZoneOffset == const Duration(hours: 5);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await service.reload();
    await service.setManualLocation(_lat, _lng);
    await service.setCorrection(RoutineAnchor.sunrise, 0);
    await service.setCorrection(RoutineAnchor.sunset, 0);
  });

  test('sunrise and sunset match published times for Tashkent', () {
    final day = DateTime(2026, 9, 19);
    final sunrise = service.sunriseFor(day)!;
    final sunset = service.sunsetFor(day)!;

    expect(sunrise.year, 2026);
    expect(sunrise.month, 9);
    expect(sunrise.day, 19);
    expect(sunset.day, 19);
    expect(sunrise.hour, 6);
    expect(sunrise.minute, closeTo(6, 2));
    expect(sunset.hour, 18);
    expect(sunset.minute, closeTo(28, 2));
  }, skip: isTashkentOffset ? null : 'requires a UTC+5 machine');

  test('winter solstice day length matches the spherical-astronomy value', () {
    final day = DateTime(2026, 12, 21);
    final sunrise = service.sunriseFor(day)!;
    final sunset = service.sunsetFor(day)!;

    // 9h11m from cos(H) = (cos(90.833) - sin(d)sin(lat)) / (cos(d)cos(lat))
    expect(sunset.difference(sunrise).inMinutes, closeTo(551, 3));
  }, skip: isTashkentOffset ? null : 'requires a UTC+5 machine');

  test('no location yields no solar time', () async {
    await service.clearLocation();
    expect(service.hasLocation, isFalse);
    expect(service.sunsetFor(DateTime(2026, 9, 19)), isNull);
    expect(
      service.resolveTime(RoutineAnchor.sunset, -60, DateTime(2026, 9, 19)),
      isNull,
    );
  });

  test('polar night has no sunrise or sunset', () async {
    await service.setManualLocation(69.6492, 18.9553); // Tromso
    expect(service.sunriseFor(DateTime(2026, 12, 21)), isNull);
    expect(service.sunsetFor(DateTime(2026, 12, 21)), isNull);
  });

  test('negative offset lands before the anchor', () {
    final day = DateTime(2026, 9, 19);
    final sunset = service.sunsetFor(day)!;
    final resolved = service.resolveTime(RoutineAnchor.sunset, -60, day)!;

    final anchorMinutes = sunset.hour * 60 + sunset.minute;
    expect(resolved.hour * 60 + resolved.minute, anchorMinutes - 60);
  }, skip: isTashkentOffset ? null : 'requires a UTC+5 machine');

  test('offset is clamped inside the calendar day', () {
    final day = DateTime(2026, 9, 19);

    // Sunset plus 12 hours would spill into tomorrow, which would break the
    // weekday and streak bookkeeping that is keyed to the date.
    final late = service.resolveTime(RoutineAnchor.sunset, 720, day)!;
    expect(late, const TimeOfDay(hour: 23, minute: 59));

    final early = service.resolveTime(RoutineAnchor.sunrise, -720, day)!;
    expect(early, const TimeOfDay(hour: 0, minute: 0));
  });

  test('calibration shifts the anchor and everything derived from it', () async {
    final day = DateTime(2026, 9, 19);
    final before = service.sunsetFor(day)!;
    final beforeResolved = service.resolveTime(RoutineAnchor.sunset, -60, day)!;

    await service.setCorrection(RoutineAnchor.sunset, 7);

    final after = service.sunsetFor(day)!;
    final afterResolved = service.resolveTime(RoutineAnchor.sunset, -60, day)!;

    expect(after.difference(before).inMinutes, 7);
    expect(
      afterResolved.hour * 60 + afterResolved.minute,
      beforeResolved.hour * 60 + beforeResolved.minute + 7,
    );
  });

  test('calibration is clamped to the supported range', () async {
    await service.setCorrection(RoutineAnchor.sunrise, 500);
    expect(
      service.sunriseCorrectionMinutes,
      SolarTimeService.maxCorrectionMinutes,
    );
  });

  test('next occurrence uses the target day sun times, not today\'s', () {
    // Friday-only routine, an hour before sunset.
    final days = List.filled(7, false)..[4] = true;
    final routine = _routine(
      anchor: RoutineAnchor.sunset,
      offsetMinutes: -60,
      days: days,
    );

    final next = SolarTimeService.instance.nextOccurrenceOf(routine);
    expect(next.weekday, DateTime.friday);

    final expected = service.resolveTime(RoutineAnchor.sunset, -60, next)!;
    expect(next.hour, expected.hour);
    expect(next.minute, expected.minute);
  }, skip: isTashkentOffset ? null : 'requires a UTC+5 machine');

  test('fixed routines ignore the solar anchor entirely', () {
    final routine = _routine(
      anchor: RoutineAnchor.fixed,
      offsetMinutes: 0,
      time: const TimeOfDay(hour: 7, minute: 30),
    );

    expect(service.resolveRoutineTime(routine, DateTime(2026, 9, 19)), isNull);
    final next = SolarTimeService.instance.nextOccurrenceOf(routine);
    expect(next.hour, 7);
    expect(next.minute, 30);
  });

  test('round trip through toMap and fromMap preserves the anchor', () {
    final routine = _routine(anchor: RoutineAnchor.sunset, offsetMinutes: -60);
    final restored = Routine.fromMap(routine.toMap());

    expect(restored.anchorType, RoutineAnchor.sunset);
    expect(restored.anchorOffsetMinutes, -60);
  });

  test('routines from a pre-v58 backup default to a fixed anchor', () {
    final legacy = {
      '_id': 1,
      'name': 'legacy',
      'time': '09:00',
      'days_of_week': '1,1,1,1,1,1,1',
      'period_after': 30,
      'interval': 10,
      'is_done': 0,
    };

    final restored = Routine.fromMap(legacy);
    expect(restored.anchorType, RoutineAnchor.fixed);
    expect(restored.anchorOffsetMinutes, 0);
  });
}
