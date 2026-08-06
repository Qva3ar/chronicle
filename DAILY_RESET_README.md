# Daily Reset System Documentation

## Overview

The Daily Reset system manages the automatic resetting of routines and goals at midnight each day. All reset logic lives in `DailyResetService` (`lib/services/daily_reset_service.dart`) and is **idempotent by date**: every trigger path goes through the `last_daily_reset_date` SharedPreferences guard, so duplicate or late triggers are harmless no-ops. An in-flight lock additionally prevents two concurrent triggers from running the reset twice.

## Reset Trigger Paths (Defense in Depth)

Because no single background mechanism is reliable on both platforms (Android Doze / OEM battery killers, iOS BGTaskScheduler being best-effort), the reset is triggered from several independent places. All of them call the same date-guarded `DailyResetService.runDailyResetIfNeeded()`:

| # | Path | When | File |
|---|------|------|------|
| 1 | WorkManager midnight task (`com.chrono.daily_reset`) | ~00:00 local time | `lib/background/task_dispatcher.dart` `_handleDailyReset()` |
| 2 | Periodic safety check (`com.chrono.daily_reset_check`) | Every ~6h in background | `lib/background/task_dispatcher.dart` `_handleDailyResetCheck()` |
| 3 | App startup catch-up | Deferred init after first frame | `lib/main.dart` `_deferredInitialization()` |
| 4 | App resume catch-up | `AppLifecycleState.resumed` | `lib/services/app_lifecycle_service.dart` `_onAppForeground()` |
| 5 | Foreground midnight timer | App kept open across 00:00 | `lib/services/app_lifecycle_service.dart` `_armMidnightTimer()` |

Guaranteed correctness comes from paths 3–5: whenever the user sees the app, the data is reset. Paths 1–2 exist so background state (widgets, notifications) is also fresh without opening the app.

### Platform specifics

- **Android:** path 1 is a one-off WorkManager task with `initialDelay` to next local midnight and `ExistingWorkPolicy.replace` (default `KEEP` would let a stale pending task silently block a fresh registration). Doze can still delay/drop it — hence paths 2–5.
- **iOS:** one-off workmanager tasks run immediately via `beginBackgroundTask` and **ignore `initialDelay`**, so path 1 uses `registerProcessingTask` (a `BGProcessingTask` with `earliestBeginDate` = next midnight). iOS decides the actual run time — it is best-effort only. Both identifiers are registered in `ios/Runner/AppDelegate.swift` (`registerBGProcessingTask` / `registerPeriodicTask`) and listed in `BGTaskSchedulerPermittedIdentifiers` in `ios/Runner/Info.plist`. `WorkmanagerPlugin.setPluginRegistrantCallback` is also required there so the background Dart isolate can use sqflite/shared_preferences.
- **Task naming:** `uniqueName` **must equal** the task name constant (`com.chrono.daily_reset`). On iOS the dispatcher receives the `uniqueName` (which is also the BGTask identifier), while Android passes the `taskName` — using the same string for both makes the dispatcher switch work on both platforms. The dispatcher still accepts the legacy `'daily_reset'` name for tasks scheduled by old installs.

## Architecture

### Background Task Dispatcher
**File:** `lib/background/task_dispatcher.dart`

The unified WorkManager dispatcher handles all background tasks including:
- Session completion timers
- **Daily reset (at midnight)** and the periodic reset safety check
- Routine notifications
- Insight generation

### Daily Reset Handler
**Function:** `_handleDailyReset()` → `DailyResetService.performDailyResetAndStoreDate()`

Executes at midnight (00:00) local time and performs:
1. Finalize yesterday's productivity record (from live state)
2. Reset routine `isDone` status to `false` (streak-safe, see below)
3. Run the routine streak self-heal pass
4. Reset goal progress to `0`
5. Reschedule routine notifications and todo reminders for the new day
6. Run daily summary generation (optional)
7. Schedule next daily reset — done in a `finally` block, so the chain is re-armed **even when the reset itself fails**

## What Gets Reset

### Routines
| Field | Action | Reason |
|-------|--------|--------|
| `isDone` | ✅ Reset to `false` | Allow user to check routine again today |
| `streak` | ❌ **PRESERVED** | Maintain user's achievement history |
| `lastCompletedDate` | ❌ **PRESERVED** | Track last completion for streak calculation |
| SharedPreferences `routine_{id}_done` | ✅ Cleared | Reset notification system state |

### Goals
| Field | Action | Reason |
|-------|--------|--------|
| `timeSpentSeconds` | ✅ Reset to `0` | Fresh timer for daily goal work |
| `isActive` | ✅ Reset to `false` | Stop any running timers |
| `sessionResumedTimestampSeconds` | ✅ Cleared | Clear session state |
| `completedAt` | ✅ Cleared | Allow goal to be completed again today |

**Note:** When a goal is completed during the day, the app creates a record/note to preserve the achievement history.

### ⚠️ Today-Session Guard (Catch-Up Race)

The reset usually runs NOT at midnight but as a **catch-up** at the first app
open of the new day (or a Doze-delayed WorkManager task firing when the user
unlocks the phone). By that time the user may have **already started a goal
session** — the reset would land a few seconds later and wipe
`isActive`/`timeSpentSeconds` of the running session, stopping the timer 2-3
seconds after start.

`resetGoalsStatus()` therefore treats local midnight as the day boundary:

- Goals with `isActive = 1` **and** `sessionResumedTimestampSeconds >= today's
  midnight` are **skipped** by the reset — they are fresh today-sessions.
- Goal progress records **created today** are never finalized to `day_ended` —
  only records from before midnight are.

This makes the reset safe regardless of which isolate runs it (main isolate or
WorkManager background isolate) and in any interleaving with `startSession()`.

Two ordering guards complement this on the main isolate:

- `TimerService.startSession()` awaits `runDailyResetIfNeeded()` before
  reading the goal, so the baseline it reads is post-reset (0), not
  yesterday's leftover time. On already-reset days this is a cheap prefs read.
- `AppLifecycleService._onAppForeground()` calls `TimerService.refreshState()`
  only after the reset future settles, so a stale yesterday-session is never
  re-adopted from the DB mid-reset.

## Critical Implementation Details

### ⚠️ IMPORTANT: Routine Reset Method

**CORRECT - Daily Reset:**
```dart
await db.resetRoutinesDoneStatus();
```

**INCORRECT - Do NOT use for daily reset:**
```dart
await routineService.resetRoutine(routine.id);  // Calls toggleRoutineDone
```

### Why This Matters

The database has TWO different methods for resetting routines:

#### 1. `resetRoutinesDoneStatus()` - For Daily Reset
**File:** `db_manager.dart:1820-1831`

```dart
Future<void> resetRoutinesDoneStatus() async {
  await db.update(
    DatabaseTables.routines,
    {DatabaseColumns.routineIsDone: 0},
  );
}
```

- **Purpose:** Automated daily reset at midnight
- **Effect:** Only resets `isDone` flag
- **Preserves:** Streak, lastCompletedDate, all streak data

#### 2. `toggleRoutineDone(id, false)` - For User Undo
**File:** `db_manager.dart:1515-1630`

```dart
Future<int> toggleRoutineDone(int id, bool isDone) async {
  if (!isDone) {
    // If unchecking on same day as completion, restore previous streak
    if (lastCompletedDate == today) {
      return await db.update(
        DatabaseTables.routines,
        {
          DatabaseColumns.routineIsDone: 0,
          DatabaseColumns.routineStreak: previousStreak ?? 0,  // ⚠️ Reverts streak!
          DatabaseColumns.routineLastCompletedDate: previousLastCompletedDate,
        },
      );
    }
  }
}
```

- **Purpose:** User manually unchecks a routine (undo action)
- **Effect:** If unchecking on same day, restores `previousStreak` value
- **Why:** Allows users to undo accidental checks without losing their streak

### The Bug This Could Cause

If daily reset uses `toggleRoutineDone(id, false)`:
1. User completes routine at 11:00 PM (streak goes from 5 → 6)
2. `previousStreak` is saved as `5`
3. `lastCompletedDate` is set to today
4. Midnight reset runs
5. `toggleRoutineDone` sees `lastCompletedDate == today`
6. **Streak gets reverted from 6 → 5** ❌

## Streak Calculation Logic

### When User Checks a Routine

**File:** `db_manager.dart:1538-1562`

```dart
// Calculate new streak using scheduled-day logic
if (lastCompletedDate == today) {
  // Already completed today - keep current streak
  newStreak = currentStreak;
} else if (lastCompletedDate != null) {
  // Find the previous scheduled occurrence before today
  final DateTime? previousScheduled = _findPreviousScheduledOccurrence(
    DateTime(now.year, now.month, now.day),
    daysOfWeek,
  );

  if (previousScheduled != null) {
    final String previousScheduledStr = DateFormat('yyyy-MM-dd').format(previousScheduled);

    // If the previous scheduled day was completed, increment streak
    if (lastCompletedDate == previousScheduledStr) {
      newStreak = currentStreak + 1;
    } else {
      newStreak = 1;  // Streak broken, start over
    }
  }
}
```

### Key Points
- Streaks only count on **scheduled days** (based on `daysOfWeek`)
- Missing a non-scheduled day doesn't break the streak
- Completing a routine multiple times in one day doesn't increase streak
- Previous state is saved for same-day undo functionality

## Scheduling

### Daily Reset Timing
**File:** `task_dispatcher.dart` — `BackgroundTaskManager.scheduleDailyReset()`

```dart
final now = tz.TZDateTime.now(tz.local);
tz.TZDateTime nextMidnight = tz.TZDateTime(
  tz.local, now.year, now.month, now.day + 1, 0, 0, 0,
);
final delay = nextMidnight.difference(now);

if (Platform.isIOS) {
  // BGProcessingTask with earliestBeginDate = next midnight (best effort)
  await Workmanager().registerProcessingTask(
    TaskNames.dailyReset,
    TaskNames.dailyReset,
    initialDelay: delay,
  );
} else {
  await Workmanager().registerOneOffTask(
    TaskNames.dailyReset,
    TaskNames.dailyReset,
    initialDelay: delay,
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
```

### Periodic Safety Check
**File:** `task_dispatcher.dart` — `BackgroundTaskManager.scheduleDailyResetCheck()`

A periodic task (`com.chrono.daily_reset_check`, every 6h) runs the date-guarded reset check. Almost always a no-op; it only performs the reset when the midnight task was killed and the app hasn't been opened since. If it does perform a reset, it also re-arms the midnight task.

### Self-Rescheduling
After each midnight run, `_handleDailyReset()` schedules the next reset in a `finally` block:

```dart
} finally {
  await BackgroundTaskManager.scheduleDailyReset();
}
```

This keeps the chain alive even when a run fails.

## Initialization

**File:** `main.dart` — `_deferredInitialization()`

Each init step runs in isolation (`_initStep`) so a failure in one service can never silently skip the reset catch-up. Reset-critical steps run first:

```dart
await _initStep('TimerService', ...);
await _initStep('AppLifecycleService', ...);   // arms the foreground midnight timer
await _initStep('NotificationService', ...);
await _initStep('BackgroundTaskManager', () => BackgroundTaskManager.initialize());
await _initStep('scheduleDailyReset', () => BackgroundTaskManager.scheduleDailyReset());
await _initStep('scheduleDailyResetCheck', () => BackgroundTaskManager.scheduleDailyResetCheck());
await _initStep('runDailyResetIfNeeded', ...); // catch-up if midnight was missed
```

## Testing Notes

### Verify Daily Reset
1. Check routine completion status resets at midnight
2. Verify streaks are preserved after reset
3. Confirm goals reset to 0 time spent
4. Check that completed goals can be worked on again

### Common Issues
- **Streaks resetting:** Check that `resetRoutinesDoneStatus()` is used, not `toggleRoutineDone()`
- **Reset not running:** Verify WorkManager initialization in main.dart; on iOS, verify the identifiers in AppDelegate.swift and Info.plist match the Dart `uniqueName`
- **Timezone issues:** Ensure timezone is properly set in background task dispatcher
- **iOS background tasks not firing:** BGTaskScheduler is best-effort by design; correctness is guaranteed by the catch-up paths (startup / resume / foreground midnight timer)

### Simulating on iOS
Pause the debugger in Xcode and run:
```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.chrono.daily_reset"]
```

## Related Files

- `lib/services/daily_reset_service.dart` - Reset logic, date guard, in-flight lock
- `lib/background/task_dispatcher.dart` - Dispatcher, midnight task, periodic safety check
- `lib/services/app_lifecycle_service.dart` - Resume catch-up and foreground midnight timer
- `lib/db_manager.dart` - Database methods (resetRoutinesDoneStatus, resetGoalsStatus, toggleRoutineDone, healRoutineStreaksFromRecords)
- `lib/services/routine_service.dart` - Routine service layer
- `lib/services/goal_service.dart` - Goal service layer
- `lib/services/notification_service.dart` - Reschedules routine notifications
- `ios/Runner/AppDelegate.swift` - BGTask handler registration + plugin registrant callback
- `ios/Runner/Info.plist` - BGTaskSchedulerPermittedIdentifiers

## Migration Notes

This system was migrated from AndroidAlarmManager to WorkManager to:
- Support unified background task management
- Improve reliability across different Android versions
- Simplify the background task architecture

Previous AndroidAlarmManager-based daily reset code was removed in favor of WorkManager implementation.
