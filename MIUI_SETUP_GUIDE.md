# MIUI/HyperOS Setup Guide for Chrono Timer Notifications

## What Was Fixed

### 1. Session Timeout Bug
- Added fallback check to stop sessions at the duration limit (e.g., 5 minutes)
- Sessions will now ALWAYS stop at the configured duration, even if background alarms fail

### 2. Notification System Improvements
- Created proper notification icon (`ic_notification.xml`)
- Increased notification importance to HIGH for MIUI/HyperOS compatibility
- Added `POST_NOTIFICATIONS` permission (Android 13+)
- Added `FOREGROUND_SERVICE` permission for persistent notifications
- Enabled notification LED and timestamp display

## CRITICAL: MIUI/HyperOS Device Setup

Redmi/Xiaomi devices with MIUI/HyperOS are extremely aggressive with battery optimization. You MUST configure the following settings manually:

### Step 1: Enable Notifications
1. Long-press the Chrono app icon
2. Tap **App info**
3. Tap **Notifications**
4. Enable **Show notifications**
5. Find **Timer Notifications** channel
6. Set importance to **High** or **Urgent**

### Step 2: Disable Battery Optimization
1. Go to **Settings** → **Apps** → **Manage apps**
2. Find and tap **Chrono**
3. Tap **Battery saver**
4. Select **No restrictions**

### Step 3: Enable Autostart
1. Go to **Settings** → **Apps** → **Manage apps**
2. Find and tap **Chrono**
3. Tap **Autostart**
4. Enable the toggle

### Step 4: Lock App in Recents
1. Open **Recent apps** (square button)
2. Find the Chrono app
3. Pull down on the app card
4. Tap the **lock icon** to prevent it from being killed

### Step 5: Allow Background Activity
1. Go to **Settings** → **Apps** → **Manage apps**
2. Find and tap **Chrono**
3. Tap **Other permissions**
4. Enable **Display pop-up windows while running in the background**
5. Enable **Run in background**

## Testing the Fixes

1. **Stop the app completely** (don't just hot reload)
2. Run `flutter run` to rebuild and install
3. Start a new goal session with 5-minute duration
4. Verify:
   - Notification appears immediately
   - Timer updates every 30 seconds
   - Session stops automatically at exactly 5 minutes
5. Test with the screen off and app in background

## Troubleshooting

### Notification Still Not Showing?
1. Check notification channel settings in Android Settings
2. Verify battery saver is set to "No restrictions"
3. Try uninstalling and reinstalling the app
4. Clear app data and cache

### Session Not Stopping at 5 Minutes?
1. Check the logs for "SESSION TIMEOUT" message
2. Verify the session duration is set correctly
3. Make sure you did a full restart, not hot reload

### Background Timer Issues?
1. Ensure autostart is enabled
2. Lock the app in recents
3. Disable battery optimization
4. Grant all requested permissions

## Additional MIUI Settings

For best results, also configure these system-wide settings:

1. **Settings** → **Battery & performance** → **Battery**
   - Set to **Performance** mode when using timers

2. **Settings** → **Additional settings** → **Privacy**
   - **Special permissions** → **Display pop-up windows**
   - Enable for Chrono

3. **Security app** → **Permissions** → **Autostart**
   - Enable Chrono

## Need More Help?

If notifications still don't work after all these steps:
1. Check which HyperOS/MIUI version you're running
2. Search for "[Your MIUI version] notification issues"
3. Some MIUI versions have additional hidden battery saving features
