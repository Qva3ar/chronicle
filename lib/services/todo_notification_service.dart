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

  bool _isInitialized = false;

  /// Notification IDs: 5000 + (todoId * 50) + offset
  /// Supports up to 50 notifications per todo (3 days × ~16 repeat slots).
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

    // How many days to schedule ahead
    final daysAhead = todo.todoType == TodoType.tomorrow ? 1 : 3;

    // Calculate repeat offsets (minutes before the main time)
    final repeatOffsets = _computeRepeatOffsets(todo);

    int slotIndex = 0;

    for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));

      // For tomorrow type, only schedule on the actual tomorrow day
      if (todo.todoType == TodoType.tomorrow && todo.targetDateTime != null) {
        final targetDay = DateTime(
          todo.targetDateTime!.year,
          todo.targetDateTime!.month,
          todo.targetDateTime!.day,
        );
        final scheduleDay = DateTime(day.year, day.month, day.day);
        if (scheduleDay != targetDay) continue;
      }

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

          debugPrint('[TodoNotification] Scheduled "${todo.title}" at $scheduledTime (slot $slotIndex)');
        } catch (e) {
          debugPrint('[TodoNotification] Error scheduling: $e');
        }
      }
    }
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
