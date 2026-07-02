import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/db_manager.dart';
import 'package:flutter/material.dart';

class TodoNotificationService {
  static final TodoNotificationService _instance = TodoNotificationService._internal();
  factory TodoNotificationService() => _instance;
  TodoNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const String _todoChannelId = 'todo_channel';
  static const String _todoChannelName = 'Todo Notifications';
  static const String _todoChannelDesc = 'Notifications for todo reminders';

  // Base ID for todo reminders (5000+ range, up to 50 slots per todo)
  static const int _baseNotificationId = 5000;
  static const int _slotsPerTodo = 50;

  // How many days ahead to pre-schedule deadline reminders. Kept small on
  // purpose: rescheduleAllReminders() runs on every app launch and at the daily
  // reset, so the window rolls forward automatically. Pre-scheduling further
  // ahead wastes exact alarms and, on iOS, quickly exhausts the app-wide 64
  // pending-notification limit (a few todos would silently drop reminders).
  static const int _maxDaysAhead = 14;

  bool _isInitialized = false;

  /// Notification IDs: 5000 + (todoId * 50) + offset
  /// Supports up to 50 notifications per todo, e.g. 50 daily deadline reminders
  /// (no repeat) or fewer days when per-day repeat slots are used.
  static int _getNotificationId(int todoId, int offset) {
    return _baseNotificationId + (todoId * _slotsPerTodo) + offset;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Platform.isAndroid) {
        await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                _todoChannelId,
                _todoChannelName,
                description: _todoChannelDesc,
                importance: Importance.high,
              ),
            );
      }

      _isInitialized = true;
      debugPrint('[TodoNotification] initialized');
    } catch (e, stackTrace) {
      debugPrint('[TodoNotification] ERROR initializing: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  /// Schedule reminder(s) for a todo.
  ///
  /// For **deadline** todos: schedules for the next 3 days at the reminder time.
  /// For **tomorrow** todos: schedules for tomorrow only at the reminder time.
  ///
  /// If period/interval are set, schedules multiple notifications per day.
  /// E.g. time=13:00, period=60min, interval=30min → 12:00, 12:30, 13:00.
  Future<void> scheduleTodoReminders(Todo todo) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }

    if (!todo.dailyReminderEnabled || todo.dailyReminderTime == null || todo.isDone) {
      return;
    }

    // Parse HH:mm
    final parts = todo.dailyReminderTime!.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;

    final now = tz.TZDateTime.now(tz.local);

    // Calculate repeat offsets (minutes before the main time)
    final repeatOffsets = _computeRepeatOffsets(todo);

    // Build the list of calendar days to schedule on.
    //
    // For **tomorrow** todos: schedule on the target day itself (defaults to
    // tomorrow). Computing this from the target date — instead of iterating
    // from "now" — fixes the bug where a tomorrow todo created today scheduled
    // zero notifications because the only iterated day (today) never matched
    // the target day.
    //
    // For **deadline** todos: schedule for the next few days (up to and
    // including the deadline) so a daily reminder fires each day.
    final daysToSchedule = <tz.TZDateTime>[];
    if (todo.todoType == TodoType.tomorrow) {
      final target =
          todo.targetDateTime ?? now.add(const Duration(days: 1));
      daysToSchedule.add(
        tz.TZDateTime(tz.local, target.year, target.month, target.day),
      );
    } else {
      // Deadline: schedule a reminder for EVERY day from today up to and
      // including the deadline, so reminders fire daily without depending on
      // the midnight daily reset (which is unreliable under Android Doze /
      // aggressive battery optimization). Capped by both the notification slots
      // available per todo AND a small rolling look-ahead window (_maxDaysAhead)
      // to stay within platform limits (notably iOS's 64 pending-notification cap).
      final slotCap = (_slotsPerTodo / repeatOffsets.length).floor();
      final maxDays = slotCap < _maxDaysAhead ? slotCap : _maxDaysAhead;
      for (int dayOffset = 0; dayOffset < maxDays; dayOffset++) {
        final day = now.add(Duration(days: dayOffset));
        // Stop once we pass the deadline date.
        if (todo.targetDateTime != null) {
          final deadlineDay = DateTime(
            todo.targetDateTime!.year,
            todo.targetDateTime!.month,
            todo.targetDateTime!.day,
          );
          final scheduleDay = DateTime(day.year, day.month, day.day);
          if (scheduleDay.isAfter(deadlineDay)) break;
        }
        daysToSchedule.add(
          tz.TZDateTime(tz.local, day.year, day.month, day.day),
        );
      }
    }

    int slotIndex = 0;
    tz.TZDateTime? firstScheduled;
    tz.TZDateTime? lastScheduled;

    for (final day in daysToSchedule) {
      for (final offsetMinutes in repeatOffsets) {
        final scheduledTime = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        ).subtract(Duration(minutes: offsetMinutes));

        // Skip past times
        if (scheduledTime.isBefore(now)) continue;

        try {
          final notificationId = _getNotificationId(todo.id!, slotIndex);
          slotIndex++;

          final title = todo.todoType == TodoType.tomorrow
              ? 'Tomorrow reminder'
              : 'Deadline reminder';

          if (Platform.isIOS) {
            await _notifications.zonedSchedule(
              notificationId,
              title,
              todo.title,
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
              payload: 'todo_${todo.id}',
            );
          } else if (Platform.isAndroid) {
            await _notifications.zonedSchedule(
              notificationId,
              title,
              todo.title,
              scheduledTime,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  _todoChannelId,
                  _todoChannelName,
                  channelDescription: _todoChannelDesc,
                  importance: Importance.high,
                  priority: Priority.high,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              payload: 'todo_${todo.id}',
            );
          }

          firstScheduled ??= scheduledTime;
          lastScheduled = scheduledTime;
        } catch (e) {
          debugPrint('[TodoNotification] Error scheduling: $e');
        }
      }
    }

    debugPrint(
        '[TodoNotification] Scheduled $slotIndex reminder(s) for "${todo.title}" from $firstScheduled to $lastScheduled');
  }

  /// Compute minute-offsets before the main reminder time.
  /// Returns [0] for no repeat, or e.g. [60, 30, 0] for period=60, interval=30.
  List<int> _computeRepeatOffsets(Todo todo) {
    final period = todo.reminderPeriodMinutes;
    final interval = todo.reminderIntervalMinutes;

    if (period == null || interval == null || period <= 0 || interval <= 0) {
      return [0]; // just the main notification
    }

    final offsets = <int>[];
    for (int offset = period; offset >= 0; offset -= interval) {
      offsets.add(offset);
    }
    // Ensure the main time (offset=0) is included
    if (offsets.isEmpty || offsets.last != 0) {
      offsets.add(0);
    }
    return offsets;
  }

  /// Reschedule reminders for all active todos that have reminders enabled.
  /// Called from DailyResetService after midnight.
  Future<void> rescheduleAllReminders() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }

    try {
      final db = DatabaseHelper.instance;
      final todos = await db.getTodosWithActiveReminders();

      for (final todo in todos) {
        await cancelTodoReminders(todo.id!);
        await scheduleTodoReminders(todo);
      }

      debugPrint('[TodoNotification] Rescheduled reminders for ${todos.length} todos');
    } catch (e) {
      debugPrint('[TodoNotification] Error rescheduling: $e');
    }
  }

  /// Cancel all reminder notifications for a specific todo.
  Future<void> cancelTodoReminders(int todoId) async {
    for (int i = 0; i < _slotsPerTodo; i++) {
      final notificationId = _getNotificationId(todoId, i);
      await _notifications.cancel(notificationId);
    }
    debugPrint('[TodoNotification] Cancelled reminders for todo $todoId');
  }
}
