import 'package:workmanager/workmanager.dart';
import 'package:chrono/ai/insight_engine.dart';
import 'package:chrono/ai/context_builder.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/db_manager.dart';

/// WorkManager callback - runs in background isolate
@pragma('vm:entry-point')
void insightCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final startTime = DateTime.now();
    print('[InsightWorker] 🔄 Background task started: $task at ${startTime.toIso8601String()}');

    try {
      // Initialize database
      final db = await DatabaseHelper.instance.database;

      // Store execution timestamp
      await db.update(
        DatabaseTables.appSettings,
        {DatabaseColumns.settingLastBackgroundRunAt: startTime.millisecondsSinceEpoch},
        where: '${DatabaseColumns.id} = 1',
      );
      print('[InsightWorker] ⏰ Stored execution timestamp');

      // Load settings
      final settings = await ContextBuilder.instance.loadSettings();

      if (!settings.insightEnabled) {
        print('[InsightWorker] ⚠️ Insights disabled, skipping execution');
        return Future.value(true);
      }

      print('[InsightWorker] ✅ Settings loaded - generating insight...');

      // Generate and store insight
      final result = await InsightEngine.instance.generateAndStoreInsight();

      if (result != null && result['should_notify'] == true) {
        print('[InsightWorker] 📢 Insight generated, sending notification...');

        try {
          final notif = NotificationService();
          await notif.initialize(calledFromBackgroundTask: true);
          await notif.showInsightNotification(
            title: (result['title'] ?? 'Chrono') as String,
            body: (result['body'] ?? '') as String,
          );
          print('[InsightWorker] ✅ Notification sent successfully');
        } catch (e) {
          print('[InsightWorker] ⚠️ Failed to send notification: $e');
        }
      } else {
        print('[InsightWorker] ℹ️ No insight generated or notification not requested');
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('[InsightWorker] ✅ Task completed in ${duration.inSeconds}s');

      return Future.value(true);
    } catch (e, stack) {
      print('[InsightWorker] ❌ Error during insight generation: $e');
      print('[InsightWorker] Stack trace: $stack');

      // Check if it's a network error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('network')) {
        print('[InsightWorker] 📡 Network error - task will retry automatically');
      }

      // Return false to indicate failure - WorkManager will retry
      return Future.value(false);
    }
  });
}

/// InsightWorker - manages periodic background insight generation
class InsightWorker {
  static const String _taskName = 'com.chrono.insight_generation';
  static const String _uniqueName = 'insight_periodic_task';
  static const bool _temporarilyDisabled = false;
  static bool _pluginInitialized = false;

  static Future<bool> _initializePluginIfNeeded({required bool forCleanup}) async {
    if (_pluginInitialized) {
      return true;
    }

    try {
      if (forCleanup) {
        print('[InsightWorker] ℹ️ Initializing WorkManager plugin to cancel stale tasks...');
      } else {
        print('[InsightWorker] Initializing WorkManager...');
      }
      await Workmanager().initialize(
        insightCallbackDispatcher,
        isInDebugMode: false,
      );
      _pluginInitialized = true;
      if (forCleanup) {
        print('[InsightWorker] ℹ️ WorkManager plugin initialized (cleanup context)');
      } else {
        print('[InsightWorker] ✅ WorkManager initialized');
      }
      return true;
    } catch (e) {
      final context = forCleanup ? ' for cleanup' : '';
      print('[InsightWorker] ❌ Failed to initialize WorkManager$context: $e');
      return false;
    }
  }

  /// Initialize WorkManager (call once at app startup)
  static Future<void> initialize() async {
    if (_temporarilyDisabled) {
      print('[InsightWorker] ⛔ WorkManager temporarily disabled (AlarmManager conflict). Skipping initialization.');
      await disableDueToAlarmManagerConflict();
      return;
    }

    final initialized = await _initializePluginIfNeeded(forCleanup: false);
    if (!initialized) {
      print('[InsightWorker] ❌ Unable to initialize WorkManager (see logs above).');
    }
  }

  /// Register periodic insight generation task
  static Future<void> registerIfEnabled() async {
    if (_temporarilyDisabled) {
      print('[InsightWorker] ⛔ WorkManager scheduling disabled. Canceling any existing tasks to avoid AlarmManager conflicts.');
      await cancel(cancelAll: true);
      return;
    }

    try {
      final initialized = await _initializePluginIfNeeded(forCleanup: false);
      if (!initialized) {
        print('[InsightWorker] ❌ Aborting task registration because WorkManager failed to initialize.');
        return;
      }

      final settings = await ContextBuilder.instance.loadSettings();

      print('[InsightWorker] Loaded settings: enabled=${settings.insightEnabled}, interval=${settings.intervalMinutes}min');

      if (!settings.insightEnabled) {
        print('[InsightWorker] Insights disabled, canceling all tasks');
        await cancel();
        return;
      }

      // Cancel existing task first
      await Workmanager().cancelByUniqueName(_uniqueName);
      print('[InsightWorker] Cancelled previous tasks');

      // Register new periodic task
      // Note: Minimum frequency is 15 minutes on both platforms
      // IMPORTANT: Android may batch tasks for battery optimization, so actual execution
      // interval may be longer than requested (especially on Android 12+)
      final intervalMinutes = settings.intervalMinutes < 15 ? 15 : settings.intervalMinutes;

      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: Duration(minutes: intervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.connected, // Require internet connection
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        initialDelay: Duration(minutes: intervalMinutes), // Wait one interval before first run
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 5),
      );

      print('[InsightWorker] ✅ Periodic task registered');
      print('[InsightWorker] ⏰ Requested interval: $intervalMinutes minutes');
      print('[InsightWorker] ⚠️  Actual interval may be longer due to Android battery optimization');
      print('[InsightWorker] 📡 Requires network connection: Yes');
      print('[InsightWorker] 🔄 First run in: ~$intervalMinutes minutes (then repeating every ~$intervalMinutes min)');
    } catch (e, stack) {
      print('[InsightWorker] ❌ Failed to register task: $e');
      print('[InsightWorker] Stack trace: $stack');
    }
  }

  /// Temporarily disable WorkManager-backed insights (AlarmManager conflict workaround)
  static Future<void> disableDueToAlarmManagerConflict() async {
    if (!_temporarilyDisabled) {
      return;
    }

    print('[InsightWorker] ⚠️ Disabling WorkManager tasks due to AlarmManager conflict (session timers hanging).');
    await cancel(cancelAll: true);
  }

  /// Run insight generation immediately (for testing/manual trigger)
  static Future<void> generateNow() async {
    final startTime = DateTime.now();
    print('[InsightWorker] 🧪 Manual insight generation triggered at ${startTime.toIso8601String()}');

    try {
      // Store execution timestamp
      final db = await DatabaseHelper.instance.database;
      await db.update(
        DatabaseTables.appSettings,
        {DatabaseColumns.settingLastBackgroundRunAt: startTime.millisecondsSinceEpoch},
        where: '${DatabaseColumns.id} = 1',
      );

      final settings = await ContextBuilder.instance.loadSettings();

      if (!settings.insightEnabled) {
        print('[InsightWorker] ❌ Insights are disabled in settings');
        return;
      }

      print('[InsightWorker] Building context...');
      final result = await InsightEngine.instance.generateAndStoreInsight();

      if (result != null) {
        print('[InsightWorker] ✅ Insight generated successfully!');
        print('[InsightWorker]   Title: ${result['title']}');
        print('[InsightWorker]   Body: ${result['body']}');
        print('[InsightWorker]   Should notify: ${result['should_notify']}');

        if (result['should_notify'] == true) {
          print('[InsightWorker] Sending notification...');
          try {
            final notif = NotificationService();
            await notif.showInsightNotification(
              title: (result['title'] ?? 'Chrono') as String,
              body: (result['body'] ?? '') as String,
            );
            print('[InsightWorker] ✅ Notification sent');
          } catch (e) {
            print('[InsightWorker] ❌ Notification failed: $e');
          }
        }
      } else {
        print('[InsightWorker] ⚠️ No insight generated (context might be duplicate)');
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('[InsightWorker] ✅ Manual generation completed in ${duration.inSeconds}s');
    } catch (e, stack) {
      print('[InsightWorker] ❌ Manual generation failed: $e');
      print('[InsightWorker] Stack trace: $stack');
      rethrow;
    }
  }

  /// Cancel all insight generation tasks
  static Future<void> cancel({bool cancelAll = false}) async {
    try {
      final initialized = await _initializePluginIfNeeded(forCleanup: true);
      if (!initialized) {
        print('[InsightWorker] ❌ Skipping cancel because WorkManager failed to initialize.');
        return;
      }

      if (cancelAll) {
        await Workmanager().cancelAll();
        print('[InsightWorker] ✅ All WorkManager tasks cancelled');
      } else {
        await Workmanager().cancelByUniqueName(_uniqueName);
        print('[InsightWorker] ✅ Insight tasks cancelled');
      }
    } catch (e) {
      print('[InsightWorker] ❌ Failed to cancel tasks: $e');
    }
  }

  /// Check if the worker is currently registered
  static Future<bool> isRegistered() async {
    try {
      // WorkManager doesn't provide a direct way to check registration
      // We'll rely on our settings
      final settings = await ContextBuilder.instance.loadSettings();
      return settings.insightEnabled;
    } catch (e) {
      print('[InsightWorker] ❌ Failed to check registration: $e');
      return false;
    }
  }
}
