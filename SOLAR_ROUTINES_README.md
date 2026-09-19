# Solar-Anchored Routines

A routine can be tied to sunrise or sunset instead of a fixed clock time, with
a signed offset. The motivating case: "an hour before sunset every Friday",
reminded every 10 minutes for half an hour.

## Data model

Two columns on `routines`, added in DB **v58**:

| Column | Values | Meaning |
|--------|--------|---------|
| `anchor_type` | `fixed` \| `sunrise` \| `sunset` | What the time is measured from |
| `anchor_offset_minutes` | signed integer | Minutes from the anchor; negative is before it |

Existing routines migrate to `fixed` / `0`, so nothing changes for them.

### `time` is a cache for solar routines

`Routine.time` still exists and still drives sorting, the routine list and the
home screen widget. For solar routines it holds **the time computed for today**,
refreshed once per day. This is deliberate: those readers are synchronous and
scattered, and making them all async to await a solar calculation would have
touched far more code than it was worth.

The consequence is an ordering constraint, described under "Daily refresh".

## Calculation

`lib/services/solar_time_service.dart` wraps the [`daylight`](https://pub.dev/packages/daylight)
package (pure Dart, no network, `Zenith.official`).

Two details in `_anchorTime` are load-bearing:

1. The query is anchored at **UTC noon** of the requested calendar day. The
   calculator derives its day from `date.toUtc()`, so passing a local midnight
   silently asks for the previous day anywhere east of Greenwich.
2. Only the wall-clock hour and minute are kept, then re-anchored to the
   requested date. The solar instant legitimately lands on the neighbouring UTC
   day at far-eastern and far-western longitudes, and callers always mean
   "this time on this date".

Coordinates live in `SharedPreferences`, cached in memory so the accessors stay
synchronous. **Background isolates start with an empty instance**, so every
background entry point calls `ensureInitialized()` first.

### Accuracy and the calibration setting

Error budget at mid latitudes:

| Source | Magnitude |
|--------|-----------|
| The algorithm itself | about 1 minute below 60 degrees latitude |
| Coordinate error | negligible; 1 degree of longitude is 4 minutes, coarse GPS is a few km |
| Elevation above sea level | **the dominant systematic term**: horizon dip is 1.76' x sqrt(metres), so Tashkent at 450 m sets about 4 minutes later than sea level, Almaty at 800 m about 6 |
| Atmospheric refraction | 1 to 2 minutes, varies with temperature and pressure |
| Local horizon (mountains, buildings) | not modelled by anything |

Second-level precision is therefore meaningless, and the elevation term is
larger than any difference between algorithms. Instead of modelling each one,
the user calibrates once: `solar_sunrise_correction_min` and
`solar_sunset_correction_min` (clamped to ±`maxCorrectionMinutes`) shift the
anchor itself, so the correction flows into the form preview, the settings
readout and the scheduled notifications from a single place.

## Daily refresh

```
midnight
  -> DailyResetService._performDailyReset
     -> SolarTimeService.refreshSolarRoutineTimes()   # recompute cached `time`
     -> NotificationService.checkAndRescheduleRoutines()
```

**The order matters.** Rescheduling first arms every alarm from yesterday's sun
times.

`refreshSolarRoutineTimes()` also runs unconditionally on app launch, because
the daily reset only fires when it detects a new day and aggressive-battery
OEMs do skip it. Changing the location or a correction in Settings triggers the
same refresh plus a reschedule immediately, otherwise the change would appear
to do nothing until the next midnight.

## Scheduling a future day

`Routine.getNextOccurrence({resolveTime})` takes an optional per-date resolver.
`SolarTimeService.nextOccurrenceOf(routine)` supplies one, so an alarm for next
Friday uses **that Friday's** sunset rather than today's cached value. Every
scheduling path goes through it: daily reschedule, routine save, un-checking a
routine, unarchiving, widget uncheck and backup import.

Notification behaviour is unchanged. `periodAfter` and `interval` already give
the repeat window, so 30 minutes at a 10-minute interval is 4 notifications.

## Edge cases

| Case | Behaviour |
|------|-----------|
| Polar day or night | The anchor resolves to null; the cached `time` is kept and the event is logged rather than inventing a time |
| Offset spills past midnight | Clamped to 00:00 / 23:59, because `days_of_week` and streaks are keyed to the calendar date |
| No coordinates set | Solar routines fall back to the cached `time`; the form blocks saving a new one and offers to set the location |
| Backup from another device | Import calls `refreshSolarRoutineTimes()` so the exporting device's cached times are replaced |
| Pre-v58 backup | `Routine.fromMap` defaults to `fixed` / `0` |
| DST change or travel | Corrects itself at the next refresh |
| Device timezone does not match the coordinates | Times will be wrong; the calculation converts through device local time |

## Privacy

Coordinates are requested only when the feature is used, taken at
`LocationAccuracy.low`, stored locally and never transmitted. Manual entry
avoids the permission entirely. See section 1.3 of `privacy_policy.html`,
`NSLocationWhenInUseUsageDescription` in `ios/Runner/Info.plist` and
`ACCESS_COARSE_LOCATION` in the Android manifest.

## Related files

- `lib/services/solar_time_service.dart` - location, calculation, calibration, daily refresh
- `lib/models/routine.model.dart` - `RoutineAnchor`, anchor fields, `getNextOccurrence` resolver
- `lib/widgets/solar_location_sheet.dart` - shared GPS / manual coordinate entry
- `lib/screens/routine_manager_screen.dart` - anchor picker, offset editor, live preview
- `lib/settings_page.dart` - location and calibration settings
- `test/solar_time_service_test.dart` - calculation, offset, clamping, migration defaults
