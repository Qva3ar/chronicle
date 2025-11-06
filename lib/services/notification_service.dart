import 'dart:io' show Platform;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
// Assuming these are your project's files
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/routine_service.dart'; // Ensure this path is correct
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/main.dart';
import 'package:chrono/screens/goals_screen.dart';
import 'package:chrono/screens/routine_manager_screen.dart';

// Top-level or static callback function for the daily reset alarm
@pragma('vm:entry-point')
Future<void> _dailyResetAlarmCallback(int id) async {
  // This function runs in a separate isolate.
  tz.initializeTimeZones();
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);
  await notificationsPlugin.initialize(initSettings);

  final notificationService = NotificationService();

  try {
    debugPrint('🌅 DAILY RESET: Starting daily reset at ${DateTime.now()}');
    
    // Add tolerance check to prevent multiple resets on the same day
    final prefs = await SharedPreferences.getInstance();
    final lastResetDateStr = prefs.getString('last_daily_reset_date');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    if (lastResetDateStr == todayStr) {
      debugPrint('⚠️ DAILY RESET: Already performed today ($todayStr), skipping');
      return;
    }
    
    final dbManager = DatabaseHelper.instance;
    final routineService = RoutineService(dbManager);
    final goalService = GoalService(dbManager);

    // Reset routines and goals
    final routines = await routineService.getAllRoutines();
    for (final routine in routines) {
      await routineService.resetRoutine(routine.id);
    }
    await goalService.resetAllGoals();
    
    // Mark that we've done the reset for today
    await prefs.setString('last_daily_reset_date', todayStr);
    debugPrint('✅ DAILY RESET: Completed successfully for $todayStr');

    await notificationService.checkAndRescheduleRoutines(fromBackgroundTask: true);

    // Schedule next reset with improved timing
    await _scheduleNextDailyReset();
  } catch (e, stackTrace) {
    debugPrint('❌ DAILY RESET ERROR: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

@pragma('vm:entry-point')
Future<void> _scheduleNextDailyReset() async {
  try {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // Calculate next midnight with timezone awareness
    tz.TZDateTime nextMidnight = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      0, // hour
      0, // minute
      0, // second
    );
    
    // Ensure we're scheduling for the future
    if (nextMidnight.isBefore(now) || nextMidnight.isAtSameMomentAs(now)) {
      nextMidnight = nextMidnight.add(const Duration(days: 1));
    }
    
    debugPrint('⏰ DAILY RESET: Scheduling next reset for $nextMidnight (local timezone: ${tz.local.name})');
    
    // Cancel existing alarm first
    await AndroidAlarmManager.cancel(NotificationService._dailyResetAlarmId);
    
    // Use setExactAndAllowWhileIdle for critical timing
    await AndroidAlarmManager.oneShotAt(
      nextMidnight,
      NotificationService._dailyResetAlarmId,
      _dailyResetAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    
    debugPrint('✅ DAILY RESET: Next reset scheduled successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ DAILY RESET SCHEDULE ERROR: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

@pragma('vm:entry-point') // vm:entry-point should be on the callback itself
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const String _routineChannelId = 'routine_channel';
  static const String _routineChannelName = 'Routine Notifications';
  static const String _routineChannelDesc = 'Notifications for daily routines';
  bool _isInitialized = false;
  bool _isInitializing = false; // Guard against re-entrant initialization

  // Constants for notification IDs
  static const int _baseNotificationId = 1000;
  static const int _baseRetryId = 2000;
  static const int _maxRetries = 5;
  static const int _dailyResetAlarmId = 999; // Static and accessible by the callback

  @pragma('vm:entry-point')
  static int _getMainNotificationId(int routineId) => _baseNotificationId + routineId;

  @pragma('vm:entry-point')
  static int _getRetryNotificationId(int routineId, int retryCount) =>
      _baseRetryId + (routineId * _maxRetries) + retryCount;

  @pragma('vm:entry-point')
  Future<void> initialize({bool calledFromBackgroundTask = false}) async {
    if (_isInitialized && !calledFromBackgroundTask) return;
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      tz.initializeTimeZones();

      if (Platform.isAndroid) {
        if (!calledFromBackgroundTask) {
          await Permission.scheduleExactAlarm.request();
          await Permission.notification.request();
        }
        await AndroidAlarmManager.initialize();
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: !calledFromBackgroundTask,
        requestBadgePermission: !calledFromBackgroundTask,
        requestSoundPermission: !calledFromBackgroundTask,
      );
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );

      if (Platform.isAndroid) {
        await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                _routineChannelId,
                _routineChannelName,
                description: _routineChannelDesc,
                importance: Importance.high,
              ),
            );
      }

      if (!calledFromBackgroundTask) {
        await _scheduleDailyReset();
      }

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  // Handle notification tap to navigate to appropriate screen
  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) {
      debugPrint('Notification tapped but no payload provided');
      return;
    }

    debugPrint('📱 Notification tapped with payload: ${response.payload}');

    try {
      final payload = response.payload!;
      final parts = payload.split('_');

      if (parts.length < 2) {
        debugPrint('⚠️ Invalid payload format: $payload');
        return;
      }

      final type = parts[0];
      final id = int.tryParse(parts[parts.length - 1]);

      if (id == null) {
        debugPrint('⚠️ Could not parse ID from payload: $payload');
        return;
      }

      // Use the global navigator key to show bottom sheet
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('⚠️ No navigation context available');
        return;
      }

      debugPrint('🚀 Navigating to $type details for ID: $id');

      // Check if a bottom sheet is already open
      final isBottomSheetOpen = _isBottomSheetAlreadyOpen(context);

      if (isBottomSheetOpen) {
        debugPrint('⚠️ Bottom sheet already open, skipping duplicate');
        return;
      }

      // Navigate based on notification type
      if (type == 'routine') {
        _showRoutineBottomSheet(context);
      } else if (type == 'goal' || type == 'running' || type == 'session') {
        _showGoalBottomSheet(context);
      } else {
        debugPrint('⚠️ Unknown notification type: $type');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling notification tap: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  bool _isBottomSheetAlreadyOpen(BuildContext context) {
    // Check if the current route is a modal bottom sheet
    final ModalRoute? currentRoute = ModalRoute.of(context);
    if (currentRoute == null) return false;

    // Check if there's a modal route being presented
    return currentRoute.isCurrent &&
           Navigator.of(context).canPop() &&
           currentRoute is! PageRoute;
  }

  void _showRoutineBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RoutineManagerScreen(),
    );
  }

  void _showGoalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GoalsScreen(),
    );
  }

  @pragma('vm:entry-point')
  Future<void> _scheduleDailyReset() async {
    if (!Platform.isAndroid) return;

    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      
      // Calculate next midnight with precise timezone handling
      tz.TZDateTime nextMidnight = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        0, // hour = 0 (midnight)
        0, // minute = 0
        0, // second = 0
        0, // millisecond = 0
      );
      
      // Handle edge cases where we might be exactly at midnight
      if (nextMidnight.isBefore(now) || nextMidnight.isAtSameMomentAs(now)) {
        nextMidnight = nextMidnight.add(const Duration(days: 1));
      }
      
      debugPrint('⏰ INITIAL DAILY RESET: Scheduling first reset for $nextMidnight (timezone: ${tz.local.name})');

      await AndroidAlarmManager.cancel(_dailyResetAlarmId);

      await AndroidAlarmManager.oneShotAt(
        nextMidnight,
        _dailyResetAlarmId,
        _dailyResetAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      
      debugPrint('✅ INITIAL DAILY RESET: Scheduled successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ INITIAL DAILY RESET ERROR: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @pragma('vm:entry-point')
  Future<void> checkAndRescheduleRoutines({bool fromBackgroundTask = false}) async {
    if (!_isInitialized) {
      await initialize(calledFromBackgroundTask: fromBackgroundTask);
      if (!_isInitialized) return;
    }

    try {
      final dbManager = DatabaseHelper.instance;
      final routineService = RoutineService(dbManager);
      final routines = await routineService.getAllRoutines();

      // First, clear all done statuses from SharedPreferences
      await resetAllRoutineDoneStatuses();

      // Then reschedule each routine
      for (final routine in routines) {
        final nextOccurrence = routine.getNextOccurrence();
        await scheduleRoutineNotification(
          routineId: routine.id!,
          routineName: routine.name,
          scheduledTime: nextOccurrence,
          periodAfter: routine.periodAfter,
          interval: routine.interval,
          calledFromBackgroundTask: fromBackgroundTask,
        );
      }

      debugPrint('✅ Successfully rescheduled all routines');
    } catch (e, stackTrace) {
      debugPrint('❌ Error rescheduling routines: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @pragma('vm:entry-point')
  Future<void> scheduleRoutineNotification({
    required int routineId,
    required String routineName,
    required DateTime scheduledTime,
    required int periodAfter,
    required int interval,
    bool calledFromBackgroundTask = false, // To prevent re-init loops
  }) async {
    // If called from a background task, ensure minimal initialization is done
    // without triggering the full sequence that schedules daily reset.
    if (!_isInitialized) {
      await initialize(calledFromBackgroundTask: calledFromBackgroundTask);
      if (!_isInitialized) return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    if (tzScheduledTime.isBefore(now)) return;

    final numberOfRetries =
        (periodAfter > 0 && interval > 0) ? (periodAfter / interval).floor() : 0;

    try {
      await _notifications.zonedSchedule(
        _getMainNotificationId(routineId),
        'Routine Reminder',
        'Time for: $routineName',
        tzScheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _routineChannelId,
            _routineChannelName,
            channelDescription: _routineChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'routine_$routineId',
      );

      if (Platform.isAndroid && numberOfRetries > 0) {
        final retryData = {
          'routineId': routineId,
          'routineName': routineName,
          'scheduledTime': scheduledTime.toIso8601String(), // Original scheduled time
          'periodAfter': periodAfter,
          'interval': interval,
          'numberOfRetries': numberOfRetries,
          'currentRetry': 0,
        };

        // The first retry alarm should be scheduled relative to the *original* scheduledTime + interval,
        // or the _handleRoutineRetry should be triggered by the main notification's alarm.
        // The current code schedules an alarm at `scheduledTime` for `_handleRoutineRetry`.
        // This means `_handleRoutineRetry` will fire at the same time as the main notification.
        // It should then decide if a *visual* notification is needed immediately or if it just schedules the *next* retry.

        // Let's make _handleRoutineRetry responsible for the first actual retry notification
        // if the main one is missed or not acted upon.
        // The alarm for _handleRoutineRetry will start checking from scheduledTime.
        await AndroidAlarmManager.oneShotAt(
          tzScheduledTime, // Start checking for retries at the scheduled time
          _getMainNotificationId(routineId), // Using main ID for the initial trigger of retry logic
          _handleRoutineRetry,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          params: retryData,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error scheduling notification for $routineName: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @pragma('vm:entry-point')
  Future<void> cancelRoutineNotification(int routineId) async {
    if (!_isInitialized) {
      // Light initialization if needed, but cancel should ideally work without full init
      return;
    }

    await _notifications.cancel(_getMainNotificationId(routineId));
    for (int i = 0; i < _maxRetries; i++) {
      await _notifications.cancel(_getRetryNotificationId(routineId, i));
    }

    if (Platform.isAndroid) {
      // The retry logic uses _getMainNotificationId for the first alarm, then _getRetryNotificationId for subsequent ones.
      await AndroidAlarmManager.cancel(
          _getMainNotificationId(routineId)); // Cancel initial retry trigger
      for (int i = 0; i < _maxRetries; i++) {
        // Cancel subsequent retry alarms
        await AndroidAlarmManager.cancel(_getRetryNotificationId(routineId, i));
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('routine_${routineId}_done');
  }

  @pragma('vm:entry-point') // This pragma is correctly on the static method
  static Future<void> _handleRoutineRetry(int id, Map<String, dynamic>? params) async {
    if (params == null) return;

    tz.initializeTimeZones();

    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await localNotifications.initialize(initSettings);

    try {
      final routineId = params['routineId'] as int?;
      final routineName = params['routineName'] as String?;
      final scheduledTimeStr =
          params['scheduledTime'] as String?; // This is the original main schedule time
      final periodAfter = params['periodAfter'] as int?;
      final interval = params['interval'] as int?;
      final numberOfRetries = params['numberOfRetries'] as int?;
      int currentRetry = params['currentRetry'] as int? ?? 0; // Default to 0 if null

      if (routineId == null ||
          routineName == null ||
          scheduledTimeStr == null ||
          periodAfter == null ||
          interval == null ||
          numberOfRetries == null) {
        debugPrint('❌ Missing required parameters for routine retry. Params: $params');
        return;
      }

      final DateTime originalScheduledTime = DateTime.parse(scheduledTimeStr);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isDone = prefs.getBool('routine_${routineId}_done') ?? false;

      if (isDone) {
        debugPrint('✅ Routine $routineId ($routineName) already marked done. Cancelling all remaining notifications and alarms.');

        // Extra safety: Cancel all related alarms and notifications when we discover routine is done
        final notifications = NotificationService();
        await notifications.cancelRoutineNotification(routineId);
        return;
      }

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime tzOriginalScheduledTime =
          tz.TZDateTime.from(originalScheduledTime, tz.local);

      // Calculate time since the *original* scheduled time
      final Duration timeSinceOriginalScheduled = now.difference(tzOriginalScheduledTime);

      // Check if we are outside the total retry period OR have exhausted retries
      if (timeSinceOriginalScheduled.inMinutes > periodAfter || currentRetry >= numberOfRetries) {
        debugPrint(
            '⏩ Routine $routineId ($routineName): Retry period ended or max retries reached. No more retries.');
        return;
      }

      // Only show notification if current time is at or after (originalScheduledTime + currentRetry * interval)
      // This ensures we don't show retry notifications prematurely.
      // The first call (currentRetry = 0) is triggered at originalScheduledTime.
      // If it's the first check (currentRetry == 0) and now is very close to originalScheduledTime,
      // this notification might be redundant with the main zonedSchedule notification.
      // However, this retry mechanism is primarily for Android background execution reliability.

      // For currentRetry > 0, this is a follow-up.
      // For currentRetry = 0, this is the first "retry" check, happening around originalScheduledTime.
      // We can decide to show a notification here *if* the main one might have been missed or as a reminder.
      // The main notification is scheduled via zonedSchedule. This one is via AndroidAlarmManager -> localNotifications.show.

      // Let's assume this is a distinct reminder.
      await localNotifications.show(
        _getRetryNotificationId(routineId, currentRetry), // Unique ID for this retry notification
        'Reminder: $routineName',
        'It\'s time for your routine: $routineName (Retry ${currentRetry + 1}/$numberOfRetries)',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _routineChannelId,
            _routineChannelName,
            channelDescription: _routineChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            // iOS retries are not managed by AndroidAlarmManager
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'routine_$routineId',
      );

      // Schedule the NEXT retry if applicable
      currentRetry++;
      if (currentRetry < numberOfRetries) {
        final tz.TZDateTime nextRetryTime =
            tzOriginalScheduledTime.add(Duration(minutes: currentRetry * interval));
        // Ensure nextRetryTime is in the future
        if (nextRetryTime.isAfter(now)) {
          final Map<String, dynamic> nextRetryData = Map<String, dynamic>.from(params);
          nextRetryData['currentRetry'] = currentRetry;

          await AndroidAlarmManager.oneShotAt(
            nextRetryTime,
            _getRetryNotificationId(routineId, currentRetry), // Unique ID for the alarm task
            _handleRoutineRetry,
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
            params: nextRetryData,
          );
        } else {
          debugPrint(
              '⏩ Next calculated retry time ($nextRetryTime) for $routineName is in the past. Skipping scheduling further retries this way.');
          // Potentially schedule immediately if interval is very short and processing took time
          // Or rely on the next check if the overall periodAfter hasn't passed.
          // For simplicity, if calculated time is past, we might miss one if processing is slow.
          // A more robust way would be to schedule `now.add(Duration(minutes: interval))` if `nextRetryTime` is past.
        }
      } else {
        debugPrint('🏁 Max retries reached for $routineName.');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling routine retry for $params: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> markRoutineDone(int routineId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('routine_${routineId}_done', true);

    // Cancel future notifications and alarms for this routine as it's now done
    await cancelRoutineNotification(routineId);

    // Additional safety: Cancel any pending notifications in the system
    await _cancelAllPendingNotificationsForRoutine(routineId);
  }

  // This method is not called by the daily reset in the provided snippet.
  // The daily reset logic in _dailyResetAlarmCallback resets routines via RoutineService
  // and then calls checkAndRescheduleRoutines.
  // If you need a global "clear all done statuses", this is it.
  Future<void> resetAllRoutineDoneStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('routine_') && key.endsWith('_done')) {
        await prefs.remove(key);
      }
    }
  }

  Future<void> _cancelAllPendingNotificationsForRoutine(int routineId) async {
    try {
      // Get all pending notification requests
      final pendingRequests = await _notifications.pendingNotificationRequests();

      // Find and cancel any notifications related to this routine
      for (final request in pendingRequests) {
        // Check if this notification belongs to our routine
        if (request.id == _getMainNotificationId(routineId)) {
          await _notifications.cancel(request.id);
          debugPrint('🚫 Cancelled pending main notification ${request.id} for routine $routineId');
        }

        // Check retry notifications
        for (int i = 0; i < _maxRetries; i++) {
          if (request.id == _getRetryNotificationId(routineId, i)) {
            await _notifications.cancel(request.id);
            debugPrint('🚫 Cancelled pending retry notification ${request.id} for routine $routineId (retry $i)');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cancelling pending notifications for routine $routineId: $e');
    }
  }
}
