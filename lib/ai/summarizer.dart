import 'dart:convert';

import 'package:chrono/ai/ai_client.dart';
import 'package:chrono/db_manager.dart';

class Summarizer {
  Summarizer._();
  static final Summarizer instance = Summarizer._();

  Future<void> runDailySummary() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final end = DateTime(now.year, now.month, now.day);

    // Collect yesterday's notes and interests
    final notes = await db.query(
      DatabaseTables.record,
      where: '${DatabaseColumns.recordCreatedAt} >= ? AND ${DatabaseColumns.recordCreatedAt} < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: '${DatabaseColumns.recordCreatedAt} ASC',
      limit: 500,
    );
    final interests = await db.query(
      DatabaseTables.aiInterestSignals,
      where: '${DatabaseColumns.aiCreatedAt} >= ? AND ${DatabaseColumns.aiCreatedAt} < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: '${DatabaseColumns.aiCreatedAt} ASC',
      limit: 200,
    );

    final payload = jsonEncode({
      'notes': notes
          .map((n) => {
                'title': n[DatabaseColumns.recordTitle],
                'text': n[DatabaseColumns.recordText],
              })
          .toList(),
      'interests': interests
          .map((i) => {
                'topic': i[DatabaseColumns.aiTopic],
                'intent': i[DatabaseColumns.aiIntent],
              })
          .toList(),
    });

    final sys =
        'Суммируй ключевые темы, прогресс и возможные микро‑шаги за прошедший день. Коротко.';
    final summary = await AiClient.instance.completeJson(
      systemPrompt: sys,
      userPrompt: payload,
    );

    await db.insert(DatabaseTables.aiContextSummaries, {
      DatabaseColumns.aiScope: 'daily',
      DatabaseColumns.aiSummary: summary,
      DatabaseColumns.aiPeriodStart: start.millisecondsSinceEpoch,
      DatabaseColumns.aiPeriodEnd: end.millisecondsSinceEpoch,
      DatabaseColumns.aiTokens: null,
      DatabaseColumns.aiCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }
}
