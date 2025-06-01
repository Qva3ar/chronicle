# Timer Bug Fix Verification Test Plan

## 🐛 **Bug Description:**
- **Issue**: Timer was running twice as fast (1-hour goal completing in ~30 minutes)
- **Root Cause**: `savedRemaining` was being updated every 30 seconds but `startTime` wasn't reset
- **Result**: Timer accumulated errors, making it run faster than real time

## 🔧 **Fix Applied:**
```dart
// BEFORE (buggy):
await prefs.setInt(_lastSavedRemainingKey, remainingTime.inSeconds);
// startTime stayed the same, causing drift

// AFTER (fixed):
final now = DateTime.now().millisecondsSinceEpoch;
await prefs.setInt(_lastSavedRemainingKey, remainingTime.inSeconds);
await prefs.setInt(_timerStartTimeKey, now); // Reset baseline!
```

## ✅ **Testing Steps:**

### 1. **Quick Test (5 minutes)**
1. Create a new goal with 5 minutes duration
2. Start the timer
3. Wait exactly 1 minute (use stopwatch)
4. Check remaining time should be ~4 minutes
5. Wait another minute → should be ~3 minutes
6. Verify timer accuracy ±5 seconds

### 2. **Extended Test (30 minutes)**
1. Create a goal with 30 minutes duration
2. Start timer and minimize app
3. Check every 5 minutes:
   - 5 min → ~25 min remaining
   - 10 min → ~20 min remaining
   - 15 min → ~15 min remaining
   - 20 min → ~10 min remaining
   - 25 min → ~5 min remaining
   - 30 min → Timer completes

### 3. **Background Test**
1. Start a 10-minute timer
2. Put app in background for 3 minutes
3. Return to app
4. Verify remaining time is accurate (~7 minutes)
5. Check notification shows correct time

### 4. **Database Sync Test**
1. Start a 15-minute timer
2. Let it run for 2 minutes
3. Force close and restart app
4. Verify remaining time persists correctly (~13 minutes)

## 🔍 **Debug Logs to Monitor:**
```
BackgroundTimerService: Time calculation:
  - Start time: [timestamp]
  - Current time: [timestamp]
  - Elapsed: [seconds]s
  - Saved remaining: [seconds]s
  - Calculated remaining: [seconds]s

BackgroundTimerService: Database updated - remaining: [seconds]s, baseline reset
```

## ✅ **Expected Results:**
- Timer runs at exactly 1:1 real time ratio
- No drift over extended periods
- Accurate time display in UI and notifications
- Proper persistence across app restarts
- Clean debug logs showing time calculations

## 🚨 **Previous Bug Symptoms (should NOT occur):**
- Timer completing faster than expected
- Remaining time decreasing too quickly
- 1-hour timer finishing in ~30-40 minutes
- Time jumping backward unexpectedly 