import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
// Assuming these are your project's files
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/routine_service.dart';
import 'package:chrono/services/routine_widget_service.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/main.dart';
import 'package:chrono/screens/goals_screen.dart';
import 'package:chrono/screens/routine_manager_screen.dart';
import 'package:chrono/screens/todo_list_screen.dart';
import 'package:chrono/ai/summarizer.dart';
import 'package:chrono/background/task_dispatcher.dart';
import 'package:chrono/services/timer_service.dart' show backgroundNotificationActionHandler, ROUTINE_DONE_ACTION_ID;
import 'package:chrono/services/productivity_service.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/features/checkin/presentation/widgets/checkin_dialog.dart';
import 'package:chrono/features/checkin/data/repositories/checkin_time_settings_repository.dart';

@pragma('vm:entry-point') // vm:entry-point should be on the callback itself
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const String _routineChannelId = 'routine_channel';
  static const String _routineChannelName = 'Routine Notifications';
  static const String _routineChannelDesc = 'Notifications for daily routines';

  static const String _checkinChannelId = 'checkin_channel';
  static const String _checkinChannelName = 'Daily Checkin Notifications';
  static const String _checkinChannelDesc = 'Notifications for morning and evening checkins';

  bool _isInitialized = false;
  bool _isInitializing = false; // Guard against re-entrant initialization
  bool _isBottomSheetOpen = false; // Track if bottom sheet is currently open

  // Constants for notification IDs
  static const int _baseNotificationId = 1000;
  static const int _baseRetryId = 2000;
  /// ID slot allocation per routine — must be large enough to cover max(periodAfter/interval).
  /// Not a scheduling cap: all retries derived from periodAfter/interval are scheduled.
  static const int _idSlotsPerRoutine = 200;

  // Checkin notification IDs
  static const int _morningCheckinNotificationId = 3000;
  static const int _eveningCheckinNotificationId = 3001;

  @pragma('vm:entry-point')
  static int _getMainNotificationId(int routineId) => _baseNotificationId + routineId;

  @pragma('vm:entry-point')
  static int _getRetryNotificationId(int routineId, int retryCount) =>
      _baseRetryId + (routineId * _idSlotsPerRoutine) + retryCount;

  @pragma('vm:entry-point')
  Future<void> initialize({bool calledFromBackgroundTask = false}) async {
    if (_isInitialized && !calledFromBackgroundTask) return;
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      tz.initializeTimeZones();
      // Set local timezone - this is critical for daily reset scheduling
      // Try to detect local timezone from system, fallback to common timezones
      try {
        final String localTimezoneName = DateTime.now().timeZoneName;
        debugPrint('📍 Device timezone: $localTimezoneName');

        // Try common timezone mappings
        String tzLocation = 'Europe/Moscow'; // Default fallback
        if (localTimezoneName.contains('MSK')) {
          tzLocation = 'Europe/Moscow';
        } else if (localTimezoneName.contains('GMT') || localTimezoneName.contains('UTC')) {
          tzLocation = 'UTC';
        } else if (localTimezoneName.contains('EST') || localTimezoneName.contains('EDT')) {
          tzLocation = 'America/New_York';
        } else if (localTimezoneName.contains('PST') || localTimezoneName.contains('PDT')) {
          tzLocation = 'America/Los_Angeles';
        }

        tz.setLocalLocation(tz.getLocation(tzLocation));
        debugPrint('✅ Timezone set to: $tzLocation (from $localTimezoneName)');
      } catch (e) {
        debugPrint('⚠️ Failed to set timezone: $e, using UTC');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      if (Platform.isAndroid) {
        if (!calledFromBackgroundTask) {
          await Permission.scheduleExactAlarm.request();
          await Permission.notification.request();
        }
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: !calledFromBackgroundTask,
        requestBadgePermission: !calledFromBackgroundTask,
        requestSoundPermission: !calledFromBackgroundTask,
        notificationCategories: [
          DarwinNotificationCategory(
            'routine_category',
            actions: [
              DarwinNotificationAction.plain(
                ROUTINE_DONE_ACTION_ID,
                'Done ✓',
              ),
            ],
          ),
        ],
      );
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
        onDidReceiveBackgroundNotificationResponse: backgroundNotificationActionHandler,
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

        await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                _checkinChannelId,
                _checkinChannelName,
                description: _checkinChannelDesc,
                importance: Importance.high,
              ),
            );
      }

      // Daily reset is now handled by BackgroundTaskManager (initialized in main.dart)
      // if (!calledFromBackgroundTask) {
      //   await _scheduleDailyReset();
      // }

      _isInitialized = true;
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR initializing NotificationService: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  // Handle notification tap to navigate to appropriate screen
  void _handleNotificationTap(NotificationResponse response) {
    if (response.actionId == ROUTINE_DONE_ACTION_ID && response.payload != null) {
      debugPrint('✅ Routine Done action tapped in foreground: ${response.payload}');
      _handleRoutineDoneForeground(response.payload!);
      return;
    }

    if (response.payload == null || response.payload!.isEmpty) {
      debugPrint('Notification tapped but no payload provided');
      return;
    }

    debugPrint('📱 Notification tapped with payload: ${response.payload}');

    try {
      final payload = response.payload!;

      // Handle daily reset notification (iOS)
      if (payload == 'daily_reset') {
        debugPrint('🌅 Daily reset notification tapped (iOS)');
        _performDailyResetIOS();
        return;
      }

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

      // Check if a bottom sheet is already open using our flag
      if (_isBottomSheetOpen) {
        debugPrint('⚠️ Bottom sheet already open, skipping duplicate');
        return;
      }

      // Navigate based on notification type
      if (type == 'routine') {
        _showRoutineBottomSheet(context);
      } else if (type == 'goal' || type == 'running' || type == 'session') {
        _showGoalBottomSheet(context);
      } else if (type == 'checkin') {
        // payload format: "checkin_morning" or "checkin_evening"
        final checkinTypeStr = parts.length > 1 ? parts[1] : null;
        if (checkinTypeStr == 'morning') {
          _showCheckinDialog(context, CheckinType.morning);
        } else if (checkinTypeStr == 'evening') {
          _showCheckinDialog(context, CheckinType.evening);
        } else {
          debugPrint('⚠️ Unknown checkin type: $checkinTypeStr');
        }
      } else if (type == 'todo') {
        // payload format: "todo_<id>"
        final todoIdStr = parts.length > 1 ? parts[1] : null;
        if (todoIdStr != null) {
          _showTodoBottomSheet(context, int.tryParse(todoIdStr));
        }
      } else {
        debugPrint('⚠️ Unknown notification type: $type');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling notification tap: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _handleRoutineDoneForeground(String payload) async {
    try {
      final parts = payload.split('_');
      if (parts.length < 2 || parts[0] != 'routine') return;

      final routineId = int.tryParse(parts[1]);
      if (routineId == null) return;

      debugPrint('✅ Marking routine $routineId as done from foreground notification');

      final db = DatabaseHelper.instance;

      final routinesData = await db.getAllRoutines();
      final routines = routinesData.map((r) => Routine.fromMap(r)).toList();
      final routine = routines.where((r) => r.id == routineId).firstOrNull;

      if (routine == null || routine.isDone) return;

      await db.toggleRoutineDone(routineId, true);

      final record = {
        DatabaseColumns.recordText: 'Completed routine: ${routine.name}',
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'routine',
        DatabaseColumns.recordRoutineId: routine.id,
      };
      await db.insertRecord(record, []);

      await markRoutineDone(routineId);
      await _notifications.cancel(1000 + routineId);

      try {
        final routineWidgetService = RoutineWidgetService(db);
        await routineWidgetService.updateWidget();
      } catch (e) {
        debugPrint('⚠️ Failed to update widget after routine done: $e');
      }

      try {
        await ProductivityService.instance.createOrUpdateDailyRecord();
      } catch (e) {
        debugPrint('⚠️ Failed to update productivity after routine done: $e');
      }

      debugPrint('✅ Routine "${routine.name}" marked as done from notification');
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling routine done action: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Handle daily reset for iOS
  Future<void> _performDailyResetIOS() async {
    try {
      debugPrint('🌅 iOS DAILY RESET: Starting daily reset at ${DateTime.now()}');

      // Add tolerance check to prevent multiple resets on the same day
      final prefs = await SharedPreferences.getInstance();
      final lastResetDateStr = prefs.getString('last_daily_reset_date');
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      if (lastResetDateStr == todayStr) {
        debugPrint('⚠️ iOS DAILY RESET: Already performed today ($todayStr), skipping');
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
      debugPrint('✅ iOS DAILY RESET: Completed successfully for $todayStr');

      await checkAndRescheduleRoutines(fromBackgroundTask: false);

      // Schedule next reset - now handled by BackgroundTaskManager
      // await _scheduleDailyReset();

      // Run optional summarization rollup
      await Summarizer.instance.runDailySummary();
    } catch (e, stackTrace) {
      debugPrint('❌ iOS DAILY RESET ERROR: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showRoutineBottomSheet(BuildContext context) {
    _isBottomSheetOpen = true;
    debugPrint('🔓 Bottom sheet opened (routine)');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RoutineManagerScreen(),
    ).whenComplete(() {
      _isBottomSheetOpen = false;
      debugPrint('🔒 Bottom sheet closed (routine)');
    });
  }

  void _showGoalBottomSheet(BuildContext context) {
    _isBottomSheetOpen = true;
    debugPrint('🔓 Bottom sheet opened (goal)');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GoalsScreen(),
    ).whenComplete(() {
      _isBottomSheetOpen = false;
      debugPrint('🔒 Bottom sheet closed (goal)');
    });
  }

  void _showTodoBottomSheet(BuildContext context, int? todoId) {
    _isBottomSheetOpen = true;
    debugPrint('🔓 Bottom sheet opened (todo: $todoId)');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoListScreen(highlightTodoId: todoId),
    ).whenComplete(() {
      _isBottomSheetOpen = false;
      debugPrint('🔒 Bottom sheet closed (todo)');
    });
  }

  void _showCheckinDialog(BuildContext context, CheckinType checkinType) {
    _isBottomSheetOpen = true;
    debugPrint('🔓 Bottom sheet opened (checkin: ${checkinType.name})');

    CheckinDialog.show(context, checkinType).whenComplete(() {
      _isBottomSheetOpen = false;
      debugPrint('🔒 Bottom sheet closed (checkin)');
    });
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
      if (Platform.isIOS) {
        // iOS: Use flutter_local_notifications zonedSchedule for exact timing
        // Schedule main notification
        await _notifications.zonedSchedule(
          _getMainNotificationId(routineId),
          'Time for: $routineName',
          'Tap to mark as done',
          tzScheduledTime,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
              categoryIdentifier: 'routine_category',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'routine_$routineId',
        );

        // Schedule retry notifications if needed
        if (numberOfRetries > 0) {
          for (int retry = 1; retry <= numberOfRetries; retry++) {
            final retryTime = tz.TZDateTime.from(
              scheduledTime.add(Duration(minutes: retry * interval)),
              tz.local,
            );
            if (retryTime.isAfter(now)) {
              await _notifications.zonedSchedule(
                _getRetryNotificationId(routineId, retry),
                'Reminder: $routineName',
                'Reminder $retry/$numberOfRetries',
                retryTime,
                const NotificationDetails(
                  iOS: DarwinNotificationDetails(
                    presentAlert: true,
                    presentBadge: true,
                    presentSound: true,
                    interruptionLevel: InterruptionLevel.timeSensitive,
                    categoryIdentifier: 'routine_category',
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                payload: 'routine_${routineId}_retry_$retry',
              );
            }
          }
        }
        debugPrint('✅ iOS: Scheduled routine notifications for $routineName at $scheduledTime with $numberOfRetries retries');
      } else {
        // Android: Use WorkManager for background execution
        await BackgroundTaskManager.scheduleRoutineNotification(
          routineId: routineId,
          routineName: routineName,
          scheduledTime: scheduledTime,
          currentRetry: 0,
          numberOfRetries: numberOfRetries,
        );

        // Schedule retry notifications if needed
        if (numberOfRetries > 0) {
          for (int retry = 1; retry <= numberOfRetries; retry++) {
            final retryTime = scheduledTime.add(Duration(minutes: retry * interval));
            await BackgroundTaskManager.scheduleRoutineNotification(
              routineId: routineId,
              routineName: routineName,
              scheduledTime: retryTime,
              currentRetry: retry,
              numberOfRetries: numberOfRetries,
            );
          }
        }
        debugPrint('✅ Android: Scheduled routine notification for $routineName at $scheduledTime with $numberOfRetries retries');
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

    // Cancel displayed notifications
    await _notifications.cancel(_getMainNotificationId(routineId));
    for (int i = 0; i < _idSlotsPerRoutine; i++) {
      await _notifications.cancel(_getRetryNotificationId(routineId, i));
    }

    // Cancel scheduled WorkManager tasks
    await BackgroundTaskManager.cancelRoutineNotification(routineId, maxRetries: _idSlotsPerRoutine);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('routine_${routineId}_done');
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
        for (int i = 0; i < _idSlotsPerRoutine; i++) {
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

  Future<void> showInsightNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }
    try {
      // Quiet hours check via app settings
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings', limit: 1);
      if (rows.isNotEmpty) {
        final s = rows.first;
        final start = s['quiet_hours_start'] as String?;
        final end = s['quiet_hours_end'] as String?;
        if (start != null && end != null && start.isNotEmpty && end.isNotEmpty) {
          final now = DateTime.now();
          final partsStart = start.split(':');
          final partsEnd = end.split(':');
          if (partsStart.length == 2 && partsEnd.length == 2) {
            final startDt = DateTime(now.year, now.month, now.day,
                int.parse(partsStart[0]), int.parse(partsStart[1]));
            final endDt = DateTime(now.year, now.month, now.day,
                int.parse(partsEnd[0]), int.parse(partsEnd[1]));
            bool inQuiet;
            if (endDt.isAfter(startDt)) {
              inQuiet = now.isAfter(startDt) && now.isBefore(endDt);
            } else {
              // Overnight window (e.g., 22:00 - 07:00)
              inQuiet = now.isAfter(startDt) || now.isBefore(endDt);
            }
            if (inQuiet) {
              debugPrint('🔕 Quiet hours active, skipping insight notification');
              return;
            }
          }
        }
      }

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 1000000,
        title,
        body,
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
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: 'insight',
      );
    } catch (e) {
      debugPrint('❌ Error showing insight notification: $e');
    }
  }

  /// Schedule daily checkin notifications
  Future<void> scheduleCheckinNotifications() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }

    try {
      final timeSettingsRepo = CheckinTimeSettingsRepository();
      final morningTime = await timeSettingsRepo.loadMorningTime();
      final eveningTime = await timeSettingsRepo.loadEveningTime();

      await _scheduleCheckinNotification(
        CheckinType.morning,
        morningTime,
        _morningCheckinNotificationId,
      );

      await _scheduleCheckinNotification(
        CheckinType.evening,
        eveningTime,
        _eveningCheckinNotificationId,
      );

      debugPrint('✅ Scheduled checkin notifications: Morning ${morningTime.hour}:${morningTime.minute}, Evening ${eveningTime.hour}:${eveningTime.minute}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling checkin notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Schedule a single checkin notification
  Future<void> _scheduleCheckinNotification(
    CheckinType checkinType,
    TimeOfDay time,
    int notificationId,
  ) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final title = checkinType == CheckinType.morning
        ? 'Утренний чекин'
        : 'Вечерний чекин';
    final body = checkinType == CheckinType.morning
        ? 'Доброе утро! Время для утреннего чекина'
        : 'Добрый вечер! Время для вечернего чекина';
    final payload = 'checkin_${checkinType.name}';

    try {
      if (Platform.isIOS) {
        // iOS: Use flutter_local_notifications zonedSchedule for exact timing
        await _notifications.cancel(notificationId);

        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledTime,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );

        debugPrint('✅ iOS: Scheduled $title at $scheduledTime');
      } else {
        // Android: Use WorkManager for reliable background execution
        await BackgroundTaskManager.scheduleCheckinNotification(
          checkinType: checkinType.name,
          notificationId: notificationId,
          scheduledTime: scheduledTime.toLocal(),
        );

        debugPrint('✅ Android: Scheduled $title at $scheduledTime via WorkManager');
      }

      debugPrint('   Current time: $now');
      debugPrint('   Time until notification: ${scheduledTime.difference(now).inMinutes} minutes');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling $title: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Cancel all checkin notifications
  Future<void> cancelCheckinNotifications() async {
    await _notifications.cancel(_morningCheckinNotificationId);
    await _notifications.cancel(_eveningCheckinNotificationId);

    // Also cancel WorkManager tasks on Android
    if (!Platform.isIOS) {
      await BackgroundTaskManager.cancelCheckinNotification('morning');
      await BackgroundTaskManager.cancelCheckinNotification('evening');
    }

    debugPrint('🚫 Cancelled all checkin notifications');
  }

  /// Reschedule checkin notifications (call after time settings change)
  Future<void> rescheduleCheckinNotifications() async {
    await cancelCheckinNotifications();
    await scheduleCheckinNotifications();
    debugPrint('♻️ Rescheduled checkin notifications');
  }
}
