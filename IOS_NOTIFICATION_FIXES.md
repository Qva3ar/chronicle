# iOS Notification Fixes

## Issues Fixed

### 1. Info.plist Configuration
**Problem:** Used wrong notification permission key (`NSUserNotificationUsageDescription` is for macOS, not iOS)

**Fix:**
- Corrected to `NSUserNotificationsUsageDescription`
- Added `processing` background mode for better background task support
- Updated description to be more comprehensive

**File:** `ios/Runner/Info.plist`

### 2. AppDelegate - Missing Notification Authorization
**Problem:** iOS requires explicit notification permission request in native code

**Fix:**
- Added `UserNotifications` framework import
- Implemented `requestAuthorization` with alert, badge, and sound permissions
- Added `UNUserNotificationCenter` delegate configuration
- Implemented `willPresent` notification handler to show notifications when app is in foreground

**File:** `ios/Runner/AppDelegate.swift`

### 3. Routine Notification Scheduling
**Problem:** WorkManager has limited support on iOS - can't schedule exact-time notifications reliably

**Fix:**
- Added platform-specific logic in `scheduleRoutineNotification`
- **iOS:** Uses `flutter_local_notifications.zonedSchedule()` for exact timing
- **Android:** Continues using WorkManager for background execution
- Added `InterruptionLevel.timeSensitive` for iOS to ensure notifications appear prominently

**File:** `lib/services/notification_service.dart:327-403`

### 4. Goal Session Notifications
**Problem:**
- Running notifications had `presentAlert: false` on iOS, preventing them from showing
- iOS doesn't support persistent/ongoing notifications like Android

**Fix:**
- Changed iOS notification config to `presentAlert: true` with sound
- Added `InterruptionLevel.active` for proper notification priority
- Updated both running notification and background notification configs
- Added comments explaining iOS limitations

**Files:**
- `lib/services/timer_service.dart:1225-1233` (running notification)
- `lib/services/timer_service.dart:91-96` (background notification)
- `lib/services/notification_service.dart:529-534` (insight notification)

## iOS Limitations to Be Aware Of

### 1. No Persistent Notifications
Unlike Android, iOS doesn't support persistent/ongoing notifications that stay in the notification center and can't be dismissed. When a goal session is running:
- **Android:** Shows persistent notification that stays until session ends
- **iOS:** Shows regular notification that user can dismiss (timer continues running in background)

### 2. Background Task Constraints
- iOS limits background task execution more strictly than Android
- WorkManager on iOS can only run tasks at system-determined intervals (minimum 15 minutes)
- Routine notifications now use `zonedSchedule` for exact timing, which is more reliable

### 3. Session Completion in Background
- If app is terminated (not just backgrounded), iOS may not trigger session completion tasks
- WorkManager tasks may be delayed or not run if device is in low power mode
- Session completion notifications rely on WorkManager and may have delays

## Testing Recommendations

1. **Test Routine Notifications:**
   - Create a routine scheduled for 2-3 minutes in the future
   - Wait for notification (keep app in foreground and background)
   - Verify notification appears at exact scheduled time

2. **Test Goal Session Notifications:**
   - Start a goal session
   - Verify running notification appears
   - Test with app in foreground, background, and locked screen
   - Verify session completion notification appears

3. **Test Permissions:**
   - On first launch, verify permission prompt appears
   - If denied, check Settings > Chrono > Notifications

4. **Test Edge Cases:**
   - Device in Do Not Disturb mode
   - Device in low power mode
   - App terminated vs backgrounded
   - Multiple notifications scheduled close together

## Known iOS Behaviors

- Notifications won't appear if:
  - User denied notification permissions
  - Device is in Do Not Disturb mode (unless app is allowed)
  - Focus mode is active and app isn't allowed
  - Notification settings for app are turned off in Settings

- Background tasks may be delayed if:
  - Device is in low power mode
  - App has been force-quit by user
  - iOS decides to throttle background activity

## Next Steps

After deploying these changes:
1. Delete and reinstall the app on iOS device to ensure clean permission state
2. Grant notification permissions when prompted
3. Test all notification scenarios listed above
4. Monitor console logs for any errors (look for "iOS notification" prefix)
5. If issues persist, check:
   - Device Settings > Chrono > Notifications (all should be enabled)
   - Device Settings > Screen Time > Focus (ensure app is allowed)
   - iOS version (notifications work best on iOS 14+)
