# Daily Reset System Documentation

## Overview

The Daily Reset system manages the automatic resetting of routines and goals at midnight each day. It uses WorkManager for reliable background execution and carefully preserves user progress (like routine streaks) while resetting daily completion status.

## Architecture

### Background Task Dispatcher
**File:** `lib/background/task_dispatcher.dart`

The unified WorkManager dispatcher handles all background tasks including:
- Session completion timers
- **Daily reset (at midnight)**
- Routine notifications
- Insight generation

### Daily Reset Handler
**Function:** `_handleDailyReset()`

Executes at midnight (00:00) local time and performs:
1. Reset routine `isDone` status to `false`
2. Reset goal progress to `0`
3. Reschedule routine notifications for the new day
4. Schedule next daily reset (for tomorrow's midnight)
5. Run daily summary generation (optional)

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
**File:** `task_dispatcher.dart:551-584`

```dart
static Future<void> scheduleDailyReset() async {
  final now = tz.TZDateTime.now(tz.local);

  // Calculate next midnight
  tz.TZDateTime nextMidnight = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day + 1,
    0, 0, 0,  // 00:00:00
  );

  if (nextMidnight.isBefore(now) || nextMidnight.isAtSameMomentAs(now)) {
    nextMidnight = nextMidnight.add(const Duration(days: 1));
  }

  final delay = nextMidnight.difference(now);

  await Workmanager().registerOneOffTask(
    'daily_reset',
    TaskNames.dailyReset,
    initialDelay: delay,
  );
}
```

### Self-Rescheduling
After each reset completes, it automatically schedules the next reset:

```dart
// Schedule next reset
await BackgroundTaskManager.scheduleDailyReset();
```

This ensures the daily reset continues to run even if the app is never opened.

## Initialization

**File:** `main.dart`

```dart
void main() async {
  // Initialize WorkManager with unified dispatcher
  await BackgroundTaskManager.initialize();

  // Schedule first daily reset
  await BackgroundTaskManager.scheduleDailyReset();

  runApp(MyApp());
}
```

## Testing Notes

### Verify Daily Reset
1. Check routine completion status resets at midnight
2. Verify streaks are preserved after reset
3. Confirm goals reset to 0 time spent
4. Check that completed goals can be worked on again

### Common Issues
- **Streaks resetting:** Check that `resetRoutinesDoneStatus()` is used, not `toggleRoutineDone()`
- **Reset not running:** Verify WorkManager initialization in main.dart
- **Timezone issues:** Ensure timezone is properly set in background task dispatcher

## Related Files

- `lib/background/task_dispatcher.dart` - Main dispatcher and daily reset handler
- `lib/db_manager.dart` - Database methods (resetRoutinesDoneStatus, resetGoalsStatus, toggleRoutineDone)
- `lib/services/routine_service.dart` - Routine service layer
- `lib/services/goal_service.dart` - Goal service layer
- `lib/services/notification_service.dart` - Reschedules routine notifications

## Migration Notes

This system was migrated from AndroidAlarmManager to WorkManager to:
- Support unified background task management
- Improve reliability across different Android versions
- Simplify the background task architecture

Previous AndroidAlarmManager-based daily reset code was removed in favor of WorkManager implementation.
