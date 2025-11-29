import 'package:chrono/db_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chrono/ai/insight_engine.dart';
import 'package:chrono/services/notification_service.dart';

class PrimaryGoalScreen extends StatefulWidget {
  const PrimaryGoalScreen({super.key});

  @override
  State<PrimaryGoalScreen> createState() => _PrimaryGoalScreenState();
}

class _PrimaryGoalScreenState extends State<PrimaryGoalScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(DatabaseTables.appSettings, limit: 1);
      if (rows.isNotEmpty && mounted) {
        final text =
            rows.first[DatabaseColumns.settingMainIntentionText] as String?;
        if (text != null) {
          _controller.text = text;
        }
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    // if (text.isEmpty) return; // Allow empty to clear
    setState(() => _saving = true);
    try {
      // Store primary intention text in app_settings
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(DatabaseTables.appSettings, limit: 1);
      if (rows.isEmpty) {
        await db.insert(DatabaseTables.appSettings, {
          DatabaseColumns.settingMainIntentionText: text,
        });
      } else {
        await db.update(
          DatabaseTables.appSettings,
          {DatabaseColumns.settingMainIntentionText: text},
          where: '${DatabaseColumns.id} = ?',
          whereArgs: [rows.first[DatabaseColumns.id]],
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);

      // Trigger immediate insight generation
      if (text.isNotEmpty) {
        try {
          final insight =
              await InsightEngine.instance.generateAndStoreInsight();
          if (insight != null && insight['should_notify'] == true) {
            await NotificationService().showInsightNotification(
              title: (insight['title'] ?? 'Chrono') as String,
              body: (insight['body'] ?? '') as String,
            );
          }
        } catch (e) {
          print('Error generating insight: $e');
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving goal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главный фокус')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Чего хочешь добиться?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Опиши кратко, чего ты хочешь достичь в целом. Это не задача, а общий вектор, который Chrono будет учитывать в инсайтах.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLength: 120,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Например: Выучить React и найти работу',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
