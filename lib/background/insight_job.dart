import 'dart:io' show Platform;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:chrono/ai/insight_engine.dart';
import 'package:chrono/ai/context_builder.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> _insightJobCallback(int id) async {
  InsightsSettings? settings;
  try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    print('[InsightJob] Callback fired (alarmId=$id) at ${DateTime.now()}');

    settings = await ContextBuilder.instance.loadSettings();
    if (!settings.insightEnabled) {
      print('[InsightJob] Insights disabled, skipping run.');
      return;
    }

    print('[InsightJob] Running insight generation with interval ${settings.intervalMinutes} min');
    final result = await InsightEngine.instance.generateAndStoreInsight();

    if (result != null && result['should_notify'] == true) {
      print('[InsightJob] Insight requested notification, sending...');
      try {
        final notif = NotificationService();
        await notif.showInsightNotification(
          title: (result['title'] ?? 'Chrono') as String,
          body: (result['body'] ?? '') as String,
        );
        print('[InsightJob] ✅ Notification sent successfully');
      } catch (e) {
        print('[InsightJob] ⚠️ Failed to send notification: $e');
      }
    } else {
      print('[InsightJob] Insight generated without notification or no insight was produced.');
    }
  } catch (e, stack) {
    print('[InsightJob] ❌ ERROR during insight generation: $e');
    print('[InsightJob] Stack trace: $stack');

    // Check if it's a network error (expected in background)
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('socketexception') || errorStr.contains('failed host lookup')) {
      print('[InsightJob] 📡 Network unavailable - will retry on next scheduled run');
    }
  } finally {
    // IMPORTANT: Always schedule the next run, even if there was an error
    try {
      // Re-load settings in case of error, use defaults if necessary
      settings ??= await ContextBuilder.instance.loadSettings();

      if (settings.insightEnabled) {
        final next = tz.TZDateTime.now(tz.local).add(
          Duration(minutes: settings.intervalMinutes),
        );
        final localNext = next.toLocal();
        print('[InsightJob] Scheduling next run at $localNext (local), tz=$next');

        final scheduled = await AndroidAlarmManager.oneShotAt(
          next,
          id,
          _insightJobCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          allowWhileIdle: true, // Allow alarm to fire during Doze mode with network access
        );

        if (scheduled) {
          print('[InsightJob] ✅ Next run scheduled successfully');
        } else {
          print('[InsightJob] ❌ Failed to schedule next run');
        }
      }
    } catch (e, stack) {
      print('[InsightJob] ❌ CRITICAL: Failed to schedule next run: $e');
      print('[InsightJob] Stack trace: $stack');
    }
  }
}

class InsightJob {
  static const int _jobId = 424242;

  static Future<void> registerIfEnabled() async {
    try {
      if (!Platform.isAndroid) {
        // iOS: Will rely on foreground triggers for now
        print('[InsightJob] registerIfEnabled skipped (not Android)');
        return;
      }

      // CRITICAL: Initialize AndroidAlarmManager first
      print('[InsightJob] Initializing AndroidAlarmManager...');
      await AndroidAlarmManager.initialize();
      print('[InsightJob] ✅ AndroidAlarmManager initialized');

      // Initialize timezone data
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC')); // Default to UTC if local not available

      final settings = await ContextBuilder.instance.loadSettings();
      print('[InsightJob] Loaded settings: enabled=${settings.insightEnabled}, interval=${settings.intervalMinutes}min');

      if (!settings.insightEnabled) {
        print('[InsightJob] Insights disabled, canceling job.');
        await cancel();
        return;
      }

      // Cancel any existing alarms first
      await AndroidAlarmManager.cancel(_jobId);
      print('[InsightJob] Cancelled any existing alarms');

      final first = tz.TZDateTime.now(tz.local).add(
        Duration(minutes: settings.intervalMinutes),
      );

      print('[InsightJob] Scheduling first run at ${first.toLocal()} (local), tz=$first');

      final scheduled = await AndroidAlarmManager.oneShotAt(
        first,
        _jobId,
        _insightJobCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true, // Allow alarm to fire during Doze mode with network access
      );

      if (scheduled) {
        print('[InsightJob] ✅ Successfully scheduled alarm for ${first.toLocal()}');
        print('[InsightJob] ⏰ Next insight generation in ${settings.intervalMinutes} minutes');
      } else {
        print('[InsightJob] ❌ Failed to schedule alarm');
      }
    } catch (e, stack) {
      print('[InsightJob] ❌ ERROR in registerIfEnabled: $e');
      print('[InsightJob] Stack trace: $stack');
    }
  }

  /// Manual test function - call this to trigger insight generation immediately
  static Future<void> generateNow() async {
    print('[InsightJob] 🧪 Manual insight generation triggered');
    try {
      final settings = await ContextBuilder.instance.loadSettings();
      if (!settings.insightEnabled) {
        print('[InsightJob] ❌ Insights are disabled in settings');
        return;
      }

      print('[InsightJob] Building context...');
      final result = await InsightEngine.instance.generateAndStoreInsight();

      if (result != null) {
        print('[InsightJob] ✅ Insight generated successfully!');
        print('[InsightJob]   Title: ${result['title']}');
        print('[InsightJob]   Body: ${result['body']}');
        print('[InsightJob]   Should notify: ${result['should_notify']}');

        if (result['should_notify'] == true) {
          print('[InsightJob] Sending notification...');
          try {
            final notif = NotificationService();
            await notif.showInsightNotification(
              title: (result['title'] ?? 'Chrono') as String,
              body: (result['body'] ?? '') as String,
            );
            print('[InsightJob] ✅ Notification sent');
          } catch (e) {
            print('[InsightJob] ❌ Notification failed: $e');
          }
        }
      } else {
        print('[InsightJob] ⚠️ No insight generated (context might be duplicate)');
      }
    } catch (e, stack) {
      print('[InsightJob] ❌ Manual generation failed: $e');
      print('[InsightJob] Stack trace: $stack');
    }
  }

  static Future<void> cancel() async {
    if (Platform.isAndroid) {
      print('[InsightJob] Cancelling scheduled job');
      await AndroidAlarmManager.cancel(_jobId);
    }
  }
}
