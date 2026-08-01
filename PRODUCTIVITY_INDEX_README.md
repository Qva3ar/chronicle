# Productivity Index System Documentation

## Overview

The Productivity Index is a daily score (0–10) based on completed routines and goal progress. It is displayed in the top banner and stored as a special record in the notes list. Both views must stay in sync.

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/productivity_service.dart` | Core calculation, storage, streams |
| `lib/widgets/productivity_banner.dart` | Top circular indicator |
| `lib/widgets/record_list_item.dart` | Productivity card in notes list |
| `lib/screens/productivity_screen.dart` | Full productivity screen with chart |

## Data Flow

### Calculation Logic (`_calculateScoreForDate`)

- **Today:** Uses live data:
  - Routines: `routine.isDone` from DB
  - Goals: `goal.timeSpentSeconds / goal.totalSeconds`
- **Past dates:** Uses records:
  - Routines: completion records for that date (`recordRoutineId` + `createdAt`)
  - Goals: goal records for that date, sum `time_minutes` from JSON
- **`forceLiveState`:** credits live state (`isDone`, `timeSpentSeconds`) even for a
  non-today date. Used only by midnight finalization (see below).

### Midnight Finalization (⚠️ important)

At the daily reset, `DailyResetService` finalizes YESTERDAY with
`createOrUpdateDailyRecord(forDate: yesterday, useLiveState: true, preserveHigherScore: true)`
**before** routines/goals are reset. At that moment yesterday's `isDone` /
`timeSpentSeconds` still hold its end-of-day state, so we snapshot from that LIVE
state. A records-only recompute would under-credit goal time that never reached a
goal record (e.g. resumed/background sessions where `timeSpentSeconds` outran the
recorded `time_minutes`) and overwrite the correct value the live updates already
stored during the day. `preserveHigherScore` is a safety net so a partially-reset
live state can never lower an already-stored score.

### Formula

- Routines: weight = `priority × 0.6` (routineWeightFactor)
- Goals: weight = `priority`
- Score = `10 × completedWeight / totalWeight`
- `goalsProgress` = average progress across active goals

## Sync: Banner vs Note

**Issue:** Banner and note must show the same value; they use different sources.

**Solution:** Two streams in `ProductivityService`:

1. **`onProductivityUpdated`** — emits `recordId` when a productivity record is created/updated  
   - HomePage listens → fetches updated record → replaces in `allRecords` → note updates
2. **`onProductivityScoreUpdated`** — emits `ProductivityScore` for the same event  
   - ProductivityBanner listens → updates `_currentScore` → banner updates

Both streams emit when `createOrUpdateDailyRecord()` finishes. Banner also refreshes every 30 seconds and on daily reset.

## When `createOrUpdateDailyRecord` Is Called

Call it whenever routines or goals change:

| Location | Trigger |
|----------|---------|
| `RoutineManagerScreen` | Routine check/uncheck |
| `NotificationService` | Routine done from notification |
| `RoutineWidgetService` | Routine toggle from home widget |
| `TimerService` | Goal session completion (several call sites) |
| `DailyResetService` | Midnight reset (for yesterday) |
| `RoutineCalendarScreen` | Backdated routine completion |
| `GoalCalendarScreen` | Backdated goal work session |

## UI Display Rules

### RecordListItem (productivity note)

- **Always show** routines and goals stats (even when 0/0 and 0%)
- Use `item.text` JSON: `score`, `routines_done`, `routines_total`, `goals_progress`
- For past days: stored data is correct
- For today: data comes from the last `createOrUpdateDailyRecord` run (via stream update)

### ProductivityBanner

- Uses `ProductivityService.calculateCurrentScore()` (live)
- Hides when `totalWeight == 0` (no routines/goals for today)
- Subscribes to `onProductivityScoreUpdated` to stay in sync with the note

## Historical Dates (Backdating)

When users add routine completions or goal sessions for past dates:

1. **RoutineCalendarScreen:** `backdateRoutineCompletion` → `createOrUpdateDailyRecord(forDate: dateStr)`
2. **GoalCalendarScreen:** creates record → `createOrUpdateDailyRecord(forDate: dateStr)`

`forDate` uses record-based calculation (completion records, goal records for that date).

## HomePage List Refresh (No Blink)

- When a productivity record is updated, HomePage replaces that record in `allRecords` by id
- No full `loadRecords(refresh: true)`, so no list flicker
- Uses `onProductivityUpdated` stream subscription

## Routine Check/Uncheck: Optimistic UI

In `RoutineManagerScreen._toggleRoutineDone`:

1. Call `toggleRoutineDone` in DB
2. **Immediately** `setState` with `routine.copyWith(isDone: isDone)` — checkbox updates at once
3. Then run: insert record, notifications, `_loadRoutines`, `_updateWidget`, `createOrUpdateDailyRecord`

**Trade-off:** Streak and sort order may lag briefly until `_loadRoutines` completes.

## Creating/Updating Productivity Records

- **Create:** `totalWeight > 0` → new Record with `RecordType.productivity`
- **Update:** existing record for that date → update title and text
- **Skip:** `totalWeight == 0` → return -1, no record
- Lookup by: `recordType = 'productivity'` AND `text LIKE '%"date":"YYYY-MM-DD"%'`

## Important Notes

1. **Routines vs goals:** Routines use `routineWeightFactor` (0.6) so they contribute less than goals.
2. **Past dates:** For historical dates, only record-based data is used (no live `isDone` or `timeSpentSeconds`).
3. **Sync:** Any code path that affects routines or goals should call `createOrUpdateDailyRecord()` so Banner and note stay consistent.
4. **Streams:** Both `onProductivityUpdated` and `onProductivityScoreUpdated` must emit on create and update.
