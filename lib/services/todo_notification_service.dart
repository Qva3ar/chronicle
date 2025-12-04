import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/models/todo_reminder.model.dart';
import 'package:flutter/material.dart';

class TodoNotificationService {
  static final TodoNotificationService _instance = TodoNotificationService._internal();
  factory TodoNotificationService() => _instance;
  TodoNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const String _todoChannelId = 'todo_channel';
  static const String _todoChannelName = 'Todo Notifications';
  static const String _todoChannelDesc = 'Notifications for todo reminders';

  // Base ID for todo notifications (starting at 4000 to avoid conflicts)
  static const int _baseTodoNotificationId = 4000;

  bool _isInitialized = false;

  /// Get notification ID for a specific todo reminder
  static int _getNotificationId(int todoId, int reminderId) {
    return _baseTodoNotificationId + (todoId * 100) + reminderId;
  }

  /// Initialize the todo notification channel
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
      debugPrint('✅ TodoNotificationService initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR initializing TodoNotificationService: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  /// Schedule a notification for a todo reminder
  Future<void> scheduleTodoReminder({
    required Todo todo,
    required TodoReminder reminder,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }

    if (reminder.scheduledAt == null) {
      debugPrint('⚠️ Cannot schedule reminder without scheduledAt time');
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(reminder.scheduledAt!, tz.local);

    // Don't schedule notifications in the past
    if (tzScheduledTime.isBefore(now)) {
      debugPrint('⚠️ Reminder scheduled time is in the past, skipping');
      return;
    }

    try {
      final notificationId = _getNotificationId(todo.id!, reminder.id!);

      if (Platform.isIOS) {
        // iOS: Use zonedSchedule for exact timing
        await _notifications.zonedSchedule(
          notificationId,
          'Todo Reminder',
          todo.title,
          tzScheduledTime,
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
        // Android: Use zonedSchedule
        await _notifications.zonedSchedule(
          notificationId,
          'Todo Reminder',
          todo.title,
          tzScheduledTime,
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

      debugPrint('✅ Scheduled todo reminder: ${todo.title} at ${reminder.scheduledAt}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling todo reminder: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Schedule all reminders for a todo
  Future<void> scheduleAllRemindersForTodo({
    required Todo todo,
    required List<TodoReminder> reminders,
  }) async {
    for (final reminder in reminders) {
      await scheduleTodoReminder(todo: todo, reminder: reminder);
    }
  }

  /// Cancel all notifications for a specific todo
  Future<void> cancelTodoNotifications(int todoId, List<TodoReminder> reminders) async {
    for (final reminder in reminders) {
      if (reminder.id != null) {
        final notificationId = _getNotificationId(todoId, reminder.id!);
        await _notifications.cancel(notificationId);
        debugPrint('✅ Cancelled todo notification: $notificationId');
      }
    }
  }

  /// Cancel a specific reminder notification
  Future<void> cancelReminderNotification(int todoId, int reminderId) async {
    final notificationId = _getNotificationId(todoId, reminderId);
    await _notifications.cancel(notificationId);
    debugPrint('✅ Cancelled todo reminder notification: $notificationId');
  }

  /// Show an immediate notification (for testing or immediate reminders)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    int? todoId,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }

    try {
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _todoChannelId,
          _todoChannelName,
          channelDescription: _todoChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notifications.show(
        todoId ?? 0,
        title,
        body,
        notificationDetails,
        payload: todoId != null ? 'todo_$todoId' : null,
      );

      debugPrint('✅ Showed immediate notification: $title');
    } catch (e) {
      debugPrint('❌ Error showing immediate notification: $e');
    }
  }
}
