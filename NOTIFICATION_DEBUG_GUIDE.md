# Session Notification Debugging Guide

## Issue: Session end notifications not showing

This guide will help you debug why session completion notifications aren't appearing.

## Quick Fixes Applied

1. **Removed non-existent sound file** - Your notification was trying to play `notification_sound` which doesn't exist
2. **Added error logging** - Enhanced debug output to track notification flow
3. **Added fallback notification** - If the main notification fails, a simpler one is attempted

## Step-by-Step Debugging

### Step 1: Check Android Battery Optimization

Android may be killing background processes. To test:

1. Go to **Settings > Apps > Chrono > Battery**
2. Set to **Unrestricted** or **Not optimized**
3. Test again

### Step 2: Check Notification Permissions

1. Go to **Settings > Apps > Chrono > Notifications**
2. Ensure notifications are enabled
3. Check that "Session Completed" channel is enabled with sound

### Step 3: Monitor Logs

Run the app with logging to see if the alarm is firing:

```bash
flutter run
```

Then in another terminal:

```bash
# Watch for background callbacks
adb logcat | grep -E "BACKGROUND|BG NOTIF|ALARM"
```

### Step 4: Test Alarm Manager

The session uses `AndroidAlarmManager`. Check if it's working:

1. Start a test goal session
2. Look for these logs:
   - `⏰ SCHEDULE: Alarm scheduled successfully`
   - `🔔 BACKGROUND CALLBACK: Session completion alarm fired`
   - `💡 BG NOTIF: Attempting to show session completion notification`
   - `✅ BACKGROUND: Session completion notification sent successfully`

### Step 5: Check for Errors

Look for these error patterns in logs:

```bash
# Check for alarm failures
adb logcat | grep "❌ BACKGROUND"

# Check for notification failures
adb logcat | grep "Failed to show completion notification"
```

## Common Issues & Solutions

### Issue 1: Alarm Not Firing

**Symptoms**: No "BACKGROUND CALLBACK" logs when session should complete

**Solution**:
- Check that `SCHEDULE_EXACT_ALARM` permission is granted
- Verify alarm was scheduled (look for "⏰ SCHEDULE" log)
- Android 12+ may require user to explicitly allow exact alarms in Settings

**Fix**:
```bash
# Check if permission is granted
adb shell dumpsys package com.your.app | grep SCHEDULE_EXACT_ALARM
```

### Issue 2: Notification Not Showing

**Symptoms**: "BACKGROUND CALLBACK" logs appear but no notification

**Solution**:
- Check notification channel is created (look for "All notification channels created" log)
- Verify notification wasn't cancelled immediately
- Check Do Not Disturb settings

**Test manually**:
```dart
// Add this to test notifications manually (in your UI somewhere):
final plugin = FlutterLocalNotificationsPlugin();
await plugin.show(
  999,
  'Test Notification',
  'If you see this, notifications work!',
  const NotificationDetails(
    android: AndroidNotificationDetails(
      'test_channel',
      'Test',
      importance: Importance.max,
      priority: Priority.max,
    ),
  ),
);
```

### Issue 3: MIUI-Specific Issues

MIUI (Xiaomi) has aggressive battery optimization:

1. Go to **Security > Permissions > Autostart**
2. Enable autostart for Chrono
3. Go to **Settings > Battery & Performance > App battery saver**
4. Set Chrono to "No restrictions"

### Issue 4: Background Execution Killed

**Symptoms**: Works when app is open, fails when app is closed

**Solution**:
```kotlin
// In MainActivity.kt, add this to request battery optimization exemption
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

// Add method to request exemption
private fun requestBatteryOptimizationExemption() {
    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
    if (!pm.isIgnoringBatteryOptimizations(packageName)) {
        val intent = Intent().apply {
            action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}
```

## Testing Checklist

- [ ] Battery optimization disabled for app
- [ ] Notification permissions granted
- [ ] "Session Completed" notification channel enabled
- [ ] Do Not Disturb is off (or app is allowed)
- [ ] App has SCHEDULE_EXACT_ALARM permission
- [ ] Logs show "⏰ SCHEDULE: Alarm scheduled successfully"
- [ ] Logs show "🔔 BACKGROUND CALLBACK" when session ends
- [ ] Logs show "✅ BACKGROUND: Session completion notification sent"
- [ ] No "❌ BACKGROUND" errors in logs

## Advanced Debugging

### Enable Verbose Alarm Logs

Add to AndroidManifest.xml:
```xml
<application android:debuggable="true">
  <!-- ... -->
</application>
```

Then check system alarm logs:
```bash
adb shell dumpsys alarm | grep chrono
```

### Check Notification History

Android 11+ has notification history:
```bash
adb shell cmd notification dump | grep -A 20 "notification.*chrono"
```

## If Nothing Works

1. Create a minimal test:
   - Create a 10-second test goal
   - Watch logs continuously
   - Compare with routine notifications (which work)

2. Compare with working notifications:
   - Your routine notifications work
   - Check what's different in implementation
   - Timer notifications use AndroidAlarmManager, routines use flutter_local_notifications scheduled

3. Consider alternative approach:
   - Use scheduled notifications like routines do
   - Or use WorkManager instead of AndroidAlarmManager

## Next Steps

After applying fixes:

1. Rebuild the app: `flutter clean && flutter build apk`
2. Uninstall old version completely
3. Install new version
4. Disable battery optimization
5. Test with a short goal (10 seconds)
6. Watch logs in real-time

## Contact

If issue persists after following this guide, collect:
- Full logcat output during a test session
- Screenshots of notification settings
- Android version and device model
