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

### Where the coordinates come from

Asking a user to type latitude and longitude is asking for a number most people
have no way to look up, so the default needs no input at all:

1. **Timezone** (default, `source == 'timezone'`). The device's IANA zone names a
   representative city, and the tz database ships its coordinates. `reload()`
   seeds from `timezoneCoordinates` — generated from `zone.tab` by
   `tool/generate_timezone_coordinates.py` — and re-seeds when the zone changes.
   No permission, no prompt, works on first launch.
2. **GPS** (opt-in, `source == 'gps'`). A single `LocationAccuracy.low` reading
   from the location sheet. Treated as the user's explicit choice, so it is never
   overwritten by the timezone; `useTimezoneLocation()` reverts.

### Accuracy and the calibration setting

Error budget at mid latitudes:

| Source | Magnitude |
|--------|-----------|
| The algorithm itself | about 1 minute below 60 degrees latitude |
| Coordinate error | small; 1 degree of longitude is 4 minutes of time. Coarse GPS is a few km, the timezone estimate is usually a few tens of km (Asia/Almaty's representative point is 5 km from central Almaty) |
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
| Timezone not in the lookup table | No coordinates; solar routines fall back to the cached `time`, and the form blocks saving a new one and offers to set the location |
| Backup from another device | Import calls `refreshSolarRoutineTimes()` so the exporting device's cached times are replaced |
| Pre-v58 backup | `Routine.fromMap` defaults to `fixed` / `0` |
| DST change or travel | Corrects itself at the next refresh. A timezone-derived location is re-seeded whenever the device's zone changes; a GPS fix is the user's explicit choice and is left alone |
| Device timezone does not match the coordinates | Times will be wrong; the calculation converts through device local time |

## Privacy

The default path touches no location API at all — it reads the timezone setting
and looks the city up in a bundled table. GPS is opt-in, taken once at
`LocationAccuracy.low`. Either way the coordinates are stored locally and never
transmitted. See section 1.3 of `privacy_policy.html`,
`NSLocationWhenInUseUsageDescription` in `ios/Runner/Info.plist` and
`ACCESS_COARSE_LOCATION` in the Android manifest.

## Related files

- `lib/services/solar_time_service.dart` - location, calculation, calibration, daily refresh
- `lib/models/routine.model.dart` - `RoutineAnchor`, anchor fields, `getNextOccurrence` resolver
- `lib/services/timezone_coordinates.dart` - generated IANA zone -> coordinates table
- `lib/widgets/solar_location_sheet.dart` - shows the current location, switches between timezone and GPS
- `lib/screens/routine_manager_screen.dart` - anchor picker, offset editor, live preview
- `lib/settings_page.dart` - location and calibration settings
- `test/solar_time_service_test.dart` - calculation, offset, clamping, migration defaults
