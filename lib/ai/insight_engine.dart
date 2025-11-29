import 'dart:convert';
import 'dart:math';

import 'package:chrono/ai/ai_client.dart';
import 'package:chrono/ai/context_builder.dart';
import 'package:chrono/db_manager.dart';

class InsightEngine {
  InsightEngine._();
  static final InsightEngine instance = InsightEngine._();

  /// Build system prompt for preview/debugging
  String buildSystemPrompt(Map<String, dynamic> ctx) {
    return _buildSystemPrompt();
  }

  /// Build user prompt for preview/debugging
  String buildUserPrompt(Map<String, dynamic> ctx) {
    return _buildUserPrompt(ctx);
  }

  String _buildSystemPrompt() {
    return '''
You are Chrono, a wise and empathetic productivity companion.
Your goal is to help the user live a balanced, productive life based on their current reality.

# INSTRUCTIONS
1. Analyze the User Context provided.
2. Identify ONE meaningful thing to say. It could be:
   - A gentle nudge if they are procrastination on a primary goal.
   - A celebration of good progress (completion of routines).
   - A suggestion to rest if it's late and they've worked hard.
   - A question about a recent note/thought.
3. **TONE**: Natural, human, supportive. NOT robotic. NOT a statistician.
   - Bad: "You completed 3 out of 5 routines. Completion rate 60%."
   - Good: "You've had a solid start with routines today. Maybe finish that last one before relaxing?"
4. **FORMAT**: Return ONLY a valid JSON object.

JSON Structure:
{
  "title": "Short, catchy header (2-5 words)",
  "body": "The message to the user. Keep it under 2 sentences.",
  "tags": ["focus", "rest", "kudos", "pattern"], 
  "urgency": "low" | "medium" | "high"
}
''';
  }

  String _buildUserPrompt(Map<String, dynamic> ctx) {
    final narrative = ctx['narrative'] as String? ?? "No context available.";
    return narrative;
  }

  int _hash64(String input) {
    // Simple FNV-1a 64-bit
    const int fnvOffset = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    int hash = fnvOffset;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash;
  }

  Future<Map<String, dynamic>?> generateAndStoreInsight() async {
    final settings = await ContextBuilder.instance.loadSettings();
    if (!settings.insightEnabled) return null;

    print('[Insights] Building Organic Context...');
    final ctx = await ContextBuilder.instance.buildInsightsContext(
      contextDays: settings.contextDays,
      tokenLimitApprox: settings.tokenLimit,
      primaryGoalText: settings.mainIntentionText,
    );

    final String narrative = ctx['narrative'] as String;
    final int contextHash = _hash64(narrative);
    print('[Insights] Context hash: $contextHash');

    // De-dup: skip if we already stored an insight for this exact context snapshot in last 24h
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      DatabaseTables.aiInsights,
      where: '${DatabaseColumns.insightSourceContextHash} = ? '
          'AND ${DatabaseColumns.insightDeliveredAt} >= ?',
      whereArgs: [
        contextHash.toString(),
        DateTime.now()
            .subtract(const Duration(hours: 4))
            .millisecondsSinceEpoch // Reduced to 4h for more responsiveness
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      print('[Insights] Skipping insight, hash already processed recently.');
      return existing.first;
    }

    final sys = _buildSystemPrompt();
    final usr = _buildUserPrompt(ctx);

    String raw;
    try {
      print('[Insights] Calling AI API...');
      raw = await AiClient.instance.completeJson(
        systemPrompt: sys,
        userPrompt: usr,
        temperature: 0.7, // Slightly creative
      );
      print('[Insights] Raw response: $raw');
    } catch (e) {
      print('[Insights] ❌ API Error: $e');
      return null;
    }

    Map<String, dynamic> parsed;
    try {
      // Cleanup json if it has markdown code blocks
      String cleanRaw = raw.trim();
      if (cleanRaw.startsWith('```json')) {
        cleanRaw = cleanRaw.replaceAll('```json', '').replaceAll('```', '');
      } else if (cleanRaw.startsWith('```')) {
        cleanRaw = cleanRaw.replaceAll('```', '');
      }

      parsed = jsonDecode(cleanRaw) as Map<String, dynamic>;
    } catch (e) {
      print('[Insights] JSON Parse Error: $e');
      // Fallback
      parsed = {
        'title': 'Insight',
        'body': raw.substring(0, min(raw.length, 200)),
        'tags': ['general'],
        'urgency': 'low'
      };
    }

    final String title = (parsed['title'] ?? 'Insight').toString();
    final String body = (parsed['body'] ?? '').toString();
    final List tags = (parsed['tags'] is List) ? (parsed['tags'] as List) : <String>[];
    final String urgency = (parsed['urgency'] ?? 'low').toString();

    final now = DateTime.now();
    // Default TTL 6 hours
    final expiresAt = now.add(const Duration(hours: 6)).millisecondsSinceEpoch;
    final deliveredAt = now.millisecondsSinceEpoch;

    final id = await db.insert(DatabaseTables.aiInsights, {
      DatabaseColumns.insightTitle: title,
      DatabaseColumns.insightBody: body,
      DatabaseColumns.insightTags: jsonEncode(tags),
      DatabaseColumns.insightScore: 1.0, // Default
      DatabaseColumns.insightUrgency: urgency,
      DatabaseColumns.insightSourceContextHash: contextHash.toString(),
      DatabaseColumns.insightDeliveredAs: 'notification',
      DatabaseColumns.insightDeliveredAt: deliveredAt,
      DatabaseColumns.insightExpiresAt: expiresAt,
    });
    print('[Insights] Stored insight id=$id: "$title"');

    return {
      DatabaseColumns.id: id,
      DatabaseColumns.insightTitle: title,
      DatabaseColumns.insightBody: body,
      'should_notify': true,
    };
  }
}
