/// Тестовый файл для отладки чекин уведомлений
/// Запустить: flutter run test_checkin_notifications.dart

import 'package:flutter/material.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/features/checkin/data/repositories/checkin_time_settings_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TestNotificationsApp());
}

class TestNotificationsApp extends StatelessWidget {
  const TestNotificationsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Checkin Notifications',
      theme: ThemeData.dark(),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _logs = <String>[];
  final _repository = CheckinTimeSettingsRepository();

  void _log(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    print('🔔 $message');
  }

  Future<void> _initializeNotifications() async {
    _log('Инициализация NotificationService...');
    try {
      await NotificationService().initialize();
      _log('✅ NotificationService инициализирован');
    } catch (e) {
      _log('❌ Ошибка инициализации: $e');
    }
  }

  Future<void> _scheduleNotifications() async {
    _log('Планирование уведомлений...');
    try {
      await NotificationService().scheduleCheckinNotifications();
      _log('✅ Уведомления запланированы');
    } catch (e) {
      _log('❌ Ошибка планирования: $e');
    }
  }

  Future<void> _checkSettings() async {
    _log('Проверка настроек времени...');
    try {
      final morningTime = await _repository.loadMorningTime();
      final eveningTime = await _repository.loadEveningTime();
      _log('⏰ Утро: ${morningTime.hour}:${morningTime.minute.toString().padLeft(2, '0')}');
      _log('⏰ Вечер: ${eveningTime.hour}:${eveningTime.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      _log('❌ Ошибка загрузки настроек: $e');
    }
  }

  Future<void> _listPendingNotifications() async {
    _log('Проверка запланированных уведомлений...');
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      final pending = await notifications.pendingNotificationRequests();
      _log('📋 Всего запланировано: ${pending.length}');

      for (final notif in pending) {
        if (notif.payload != null && notif.payload!.contains('checkin')) {
          _log('  - ID ${notif.id}: ${notif.title} (${notif.payload})');
        }
      }

      if (pending.isEmpty) {
        _log('⚠️ НЕТ запланированных уведомлений!');
      }
    } catch (e) {
      _log('❌ Ошибка получения списка: $e');
    }
  }

  Future<void> _testImmediateNotification() async {
    _log('Отправка тестового уведомления СЕЙЧАС...');
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      await notifications.show(
        99999,
        'ТЕСТ: Чекин',
        'Если видишь это уведомление - система работает!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'checkin_channel',
            'Daily Checkin Notifications',
            channelDescription: 'Notifications for morning and evening checkins',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      _log('✅ Тестовое уведомление отправлено');
    } catch (e) {
      _log('❌ Ошибка отправки: $e');
    }
  }

  Future<void> _runFullTest() async {
    _logs.clear();
    _log('=== НАЧАЛО ПОЛНОГО ТЕСТА ===');
    await _initializeNotifications();
    await _checkSettings();
    await _scheduleNotifications();
    await _listPendingNotifications();
    _log('=== КОНЕЦ ТЕСТА ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест уведомлений чекинов'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _runFullTest,
                  child: const Text('🔍 Полный тест'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _testImmediateNotification,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('🔔 Тест: показать уведомление СЕЙЧАС'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _listPendingNotifications,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('📋 Список запланированных'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _logs.clear()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('🗑️ Очистить логи'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
