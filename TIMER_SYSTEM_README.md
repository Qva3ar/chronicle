# Background Timer System Documentation

## Overview

This project includes a robust background timer system that serves as the single source of truth for all timer operations. The system is designed to work reliably in the background with simple active status notifications.

## Key Features

### 🎯 Single Source of Truth
- All timer operations are handled by `BackgroundTimerService`
- No timer conflicts or synchronization issues
- Consistent state across app lifecycle

### 🔔 Background Operation
- Timer continues running when app is in background
- Android AlarmManager ensures reliability
- Automatic restart after device reboot
- Works even when app is completely closed

### 📱 Simple Status Notifications
- Shows active goal name and status
- Pause button directly in notification
- Battery-efficient updates (every 60 seconds)
- Reliable across all Android versions

### 💾 Database Updates
- Goal state automatically saved every 30 seconds
- Persistent timer state across app restarts
- Accurate remaining time calculation

### 🔄 App Lifecycle Management
- Seamless transitions between foreground/background
- Proper timer synchronization when app resumes
- Real-time UI updates when app is active

## How It Works

### 1. Timer Architecture

```
BackgroundTimerService (Single Source of Truth)
├── Background Timer (60 second intervals via AlarmManager)
│   ├── Checks for timer completion
│   └── Maintains active status notification
├── Database Update Timer (30 second intervals)
│   ├── Saves goal state to SQL
│   └── Persists remaining time
└── Foreground Timer (when app is active)
    ├── Updates UI streams every second
    └── Real-time display updates
```

### 2. State Management

The timer system uses SharedPreferences to store:
- Active goal ID
- Timer start timestamp
- Last saved remaining time

This ensures perfect accuracy even after app restarts.

### 3. Background Execution

Uses Android AlarmManager with these callbacks:
- `_backgroundTimerCallback`: Updates notification every second
- `_databaseUpdateCallback`: Saves to database every 5 seconds

## Usage Guide

### Starting a Timer

```dart
final goalService = GoalService();
await goalService.startGoal(goal);
```

This will:
1. Stop any existing timer
2. Set up background alarms
3. Start foreground monitoring
4. Show persistent notification

### Pausing from App

```dart
await goalService.pauseGoal(goal);
```

### Pausing from Notification

User can tap the "Pause" action in the notification to pause the timer without opening the app.

### Monitoring Timer State

```dart
// Listen to remaining time updates
goalService.remainingTimeStream.listen((duration) {
  // Update UI with remaining time
});

// Listen to active goal changes
goalService.activeGoalStream.listen((goal) {
  // Update UI with current active goal
});
```

## Key Components

### BackgroundTimerService
- Main timer service class
- Handles all background operations
- Manages notification updates
- Provides streams for UI updates

### GoalService
- Wrapper around BackgroundTimerService
- Provides clean API for UI
- Handles goal CRUD operations
- Manages app lifecycle integration

### Goal Model
- Represents timer goals
- Tracks remaining time
- Stores active state

## Permissions Required

The app requires these Android permissions (already configured):
- `SCHEDULE_EXACT_ALARM` - For precise background timers
- `USE_EXACT_ALARM` - Alternative alarm permission
- `RECEIVE_BOOT_COMPLETED` - Restart timers after reboot
- `WAKE_LOCK` - Keep device awake for timer operations

## Notification Features

### Ongoing Notification
- Shows current goal title with "Timer Active" status
- Simple message: "Goal is currently running. Tap to open app."
- Persistent while timer is running
- Cannot be dismissed while timer is running
- Battery-efficient (updates only every 60 seconds)

### Actions
- **Pause**: Stops timer and updates goal state
- **Show App**: Opens the app to view detailed progress
- Future: Could add "Add 5 minutes", "Stop", etc.

### Completion Notification
- Shows when timer reaches zero
- Can be dismissed
- Different from ongoing notification

## Database Schema

Goals are stored with these fields:
- `title`: Goal name
- `daily_hours`: Total duration in hours
- `is_active`: Whether timer is currently running
- `last_started_at`: When timer was last started
- `remaining_time`: Seconds remaining

## Error Handling

The system includes comprehensive error handling:
- Graceful degradation if permissions are denied
- Automatic retry on failure
- Logging for debugging
- Safe cleanup on errors

## Testing the System

1. **Start a timer** and minimize the app
2. **Check notification** updates every second
3. **Restart the app** - timer should continue seamlessly
4. **Reboot device** - timer should restart automatically
5. **Pause from notification** - should update app state

## Performance Considerations

- Background alarms are scheduled efficiently
- Database updates are batched (5-second intervals)
- Foreground timer only runs when app is active
- Minimal battery impact
- No memory leaks or timer accumulation

## Future Enhancements

- [ ] Multiple simultaneous timers
- [ ] Timer categories/groups
- [ ] Statistics and analytics
- [ ] Custom notification sounds
- [ ] Widget support
- [ ] Apple Watch integration

## Recent Updates - Notification Timing Fix

### Problem Solved: Frozen Notification Updates

**Issue**: Notifications were updating every 1-2 minutes instead of every second.

**Root Cause**: Android AlarmManager throttles frequent (1-second) alarms for battery optimization.

**Solution Implemented**:
1. **Background Updates**: Changed from 1-second to 15-second intervals for background notifications
2. **Foreground Updates**: When app is active, notifications update every 5 seconds
3. **Hybrid Approach**: More frequent updates when app is foreground, battery-efficient when background
4. **Better Error Handling**: Added comprehensive debugging to identify issues

### New Timing Strategy

```
App State          | Notification Updates | UI Updates
-------------------|---------------------|------------
Foreground Active  | Only on status change| Every 1 second
Background         | Every 60 seconds    | N/A
Database Saves     | Every 30 seconds    | Every 30 seconds
```

This provides excellent battery life while maintaining reliable timer operation. The notification shows a simple "Timer Active" status instead of live countdown, which is more reliable across all Android versions and doesn't depend on precise background timing.

## Troubleshooting

### Timer Not Working in Background
1. Check if exact alarm permissions are granted
2. Verify battery optimization is disabled for the app
3. Ensure AlarmManager initialization succeeded
4. **NEW**: Check debug logs for background callback execution

### Notification Not Updating
1. Check notification permissions
2. Verify notification channel creation
3. Look for errors in background callbacks
4. **NEW**: Monitor debug logs for update frequency
5. **NEW**: Verify the timestamp in notification title changes

### State Not Persisting
1. Check SharedPreferences access
2. Verify database write permissions
3. Ensure proper error handling in callbacks

### Debug Tools Added

1. **Enhanced Logging**: All timer operations now log detailed debug information
2. **Notification Timestamps**: Notifications show update time in title during debugging
3. **Debug Widget**: Added `TimerDebugWidget` for real-time monitoring (temporary)

### Performance Monitoring

To monitor the timer system:
1. Watch Android logs for "BackgroundTimerService" messages
2. Check notification updates by looking at the timestamp in the title
3. Use the debug widget temporarily for real-time status

## Technical Notes

- Uses `@pragma('vm:entry-point')` for background callbacks
- Static methods for isolate-safe background execution
- Singleton pattern for service instances
- Stream-based UI updates for reactive programming
- Comprehensive lifecycle management

This timer system provides a robust, reliable foundation for time tracking that works seamlessly across all app states and device conditions. 