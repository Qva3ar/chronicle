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
    return _buildSystemPrompt(ctx);
  }

  /// Build user prompt for preview/debugging
  String buildUserPrompt(Map<String, dynamic> ctx) {
    return _buildUserPrompt(ctx);
  }

  String _buildSystemPrompt(Map<String, dynamic> ctx) {
    final timeOfDay = ctx['current_time']?['time_of_day'] ?? '';
    final activeGoals = ctx['active_goals_today'] as List? ?? [];
    final routines = ctx['routines_today'] as Map? ?? {};
    final previousInsights = ctx['previous_insights'] as List? ?? [];

    // Build previous insights text
    final String previousInsightsText;
    if (previousInsights.isEmpty) {
      previousInsightsText = '- Предыдущих инсайтов нет (это первый инсайт)';
    } else {
      final insightsLines = previousInsights.map((insight) {
        final title = insight['title'] ?? '';
        final body = insight['body'] ?? '';
        return '  • "$title" - ${body.toString().substring(0, body.toString().length > 100 ? 100 : body.toString().length)}';
      }).join('\n');
      previousInsightsText = '- Предыдущие 3 инсайта (НЕ ПОВТОРЯЙ их!):\n$insightsLines';
    }

    return [
      'Ты Chrono — персональный коуч по продуктивности.',
      '',
      'КОНТЕКСТ СЕЙЧАС:',
      '- Время дня: $timeOfDay',
      '- Активных целей с прогрессом на сегодня: ${activeGoals.length}',
      '- Привычек выполнено сегодня: ${routines['completed'] ?? 0}/${routines['total'] ?? 0}',
      previousInsightsText,
      '',
      'ЗАДАЧА:',
      'Дай КОНКРЕТНУЮ рекомендацию на СЕЙЧАС с учётом:',
      '1. Текущего времени дня и контекста',
      '2. Прогресса по целям СЕГОДНЯ (сколько сделано, сколько осталось)',
      '3. Какие привычки уже выполнены, какие - нет',
      '4. Недавних заметок и интересов',
      '5. Главного фокуса пользователя',
      '6. НЕ повторяй предыдущие 3 инсайта - дай что-то НОВОЕ!',
      '',
      'ПРИНЦИПЫ:',
      '- Будь КОНКРЕТНЫМ: "Уделить 25 минут Quran reading сейчас" вместо "Почитай Коран"',
      '- Учитывай ВРЕМЯ: утром - планирование, днём - действие, вечером - рефлексия',
      '- Используй ПРОГРЕСС: если цель на 10/60 минут, скажи сколько осталось',
      '- Обращай внимание на ПАТТЕРНЫ: если привычки не выполнены - напомни',
      '- ВАРЬИРУЙ: каждый раз новый аспект, не повторяйся',
      '- НЕ ДУБЛИРУЙ предыдущие инсайты - ищи новые углы и перспективы!',
      '',
      'ВАЖНО: Ответ ТОЛЬКО в виде валидного JSON:',
      '{',
      '  "title": "Краткий заголовок (3-7 слов)",',
      '  "body": "Конкретный совет на СЕЙЧАС (макс 280 символов)",',
      '  "tags": ["тег1", "тег2"],',
      '  "score": 0.7,',
      '  "urgency": "medium",',
      '  "ttl_hours": 6',
      '}',
      '',
      'Верни только валидный JSON, без текста вокруг!',
    ].join('\n');
  }

  String _buildUserPrompt(Map<String, dynamic> ctx) {
    final primaryGoal = ctx['primary_goal'];
    final previousInsights = ctx['previous_insights'] ?? [];
    return jsonEncode({
      'primary_goal': primaryGoal,
      'active_goals_today': ctx['active_goals_today'],
      'routines_today': ctx['routines_today'],
      'recent_interest_signals': ctx['recent_interest_signals'],
      'recent_notes': ctx['recent_notes'],
      'previous_insights': previousInsights,
      'guidelines': {
        'tone': 'supportive, pragmatic',
        'length': 'short',
        'safety': 'no medical/financial/legal risky advice',
        'avoid_repetition': 'Do not repeat topics or suggestions from previous_insights',
      }
    });
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

    print(
        '[Insights] Building context window=${settings.contextDays} days, tokenLimit=${settings.tokenLimit}');
    final ctx = await ContextBuilder.instance.buildInsightsContext(
      contextDays: settings.contextDays,
      tokenLimitApprox: settings.tokenLimit,
      primaryGoalText: settings.mainIntentionText,
    );
    final String ctxJson = ctx['context_json'] as String;
    final int contextHash = _hash64(ctxJson);
    print('[Insights] Context hash: $contextHash');

    // De-dup: skip if we already stored an insight for this exact context snapshot in last 24h
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      DatabaseTables.aiInsights,
      where: '${DatabaseColumns.insightSourceContextHash} = ? '
          'AND ${DatabaseColumns.insightDeliveredAt} >= ?',
      whereArgs: [
        contextHash.toString(),
        DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      print('[Insights] Skipping insight, hash already processed in past 24h.');
      return existing.first;
    }

    final sys = _buildSystemPrompt(ctx);
    final usr = _buildUserPrompt(ctx);

    String raw;
    try {
      print('[Insights] Calling AI API...');
      raw = await AiClient.instance.completeJson(
        systemPrompt: sys,
        userPrompt: usr,
      );
      print('[Insights] Raw model response (${raw.length} chars): $raw');
    } catch (e, stack) {
      print('[Insights] ❌ AI API call failed: $e');
      print('[Insights] Stack trace: $stack');

      // Check if it's a network error
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('socketexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection');

      if (isNetworkError) {
        print('[Insights] 📡 Network error detected - skipping insight generation this time');
        // Return null to skip storing an insight when network is unavailable
        // The next scheduled run will try again
        return null;
      }

      // For other API errors, create an error insight
      print('[Insights] ⚠️ Non-network API error - creating error insight');
      raw = jsonEncode({
        'title': 'Ошибка API',
        'body': 'Не удалось сгенерировать инсайт. Проверьте настройки API.',
        'tags': ['error'],
        'score': 0.0,
        'urgency': 'low',
        'ttl_hours': 1,
      });
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
      print('[Insights] ✅ Successfully parsed JSON response');
      print('[Insights] Parsed fields: ${parsed.keys.toList()}');

      // Validate required fields
      if (!parsed.containsKey('title') || !parsed.containsKey('body')) {
        print('[Insights] ⚠️ Missing required fields (title or body)!');
        print('[Insights] Available fields: ${parsed.keys.toList()}');
        print('[Insights] Full parsed JSON: $parsed');

        // Try to extract useful content from whatever fields exist
        String extractedBody = '';
        if (parsed.containsKey('step')) {
          extractedBody = parsed['step'].toString();
        } else if (parsed.containsKey('body')) {
          extractedBody = parsed['body'].toString();
        } else if (parsed.containsKey('message')) {
          extractedBody = parsed['message'].toString();
        } else {
          // Use any non-null string value we can find
          for (var value in parsed.values) {
            if (value is String && value.isNotEmpty) {
              extractedBody = value;
              break;
            }
          }
        }

        // Create fixed structure
        parsed = {
          'title': parsed['title'] ?? 'Совет для фокуса',
          'body': extractedBody,
          'tags': parsed['tags'] ?? ['general'],
          'score': parsed['score'] ?? 0.7,
          'urgency': parsed['urgency'] ?? 'medium',
          'ttl_hours': parsed['ttl_hours'] ?? 6,
        };
        print('[Insights] ✅ Reconstructed insight with body: ${extractedBody.substring(0, extractedBody.length > 50 ? 50 : extractedBody.length)}...');
      }
    } catch (e) {
      // If model returned non-JSON, wrap it
      print('[Insights] ⚠️ Failed to parse JSON (error: $e), using fallback payload.');
      print('[Insights] Raw text that failed to parse: ${raw.substring(0, raw.length > 200 ? 200 : raw.length)}...');
      parsed = {
        'title': 'Идея для фокуса',
        'body': raw.toString().substring(0, raw.length > 280 ? 280 : raw.length),
        'tags': ['general'],
        'score': 0.5,
        'urgency': 'low',
        'ttl_hours': 6,
      };
    }

    final String title = (parsed['title'] ?? 'Идея для фокуса').toString();
    final String body = (parsed['body'] ?? '').toString();
    print('[Insights] Final insight - Title: "$title", Body length: ${body.length} chars');
    final List tags = (parsed['tags'] is List) ? (parsed['tags'] as List) : <String>[];
    final double? score = parsed['score'] is num ? (parsed['score'] as num).toDouble() : null;
    final String? urgency = parsed['urgency']?.toString();
    const bool shouldNotify = true; // Force notifications for every stored insight
    final int ttlHours = (parsed['ttl_hours'] is num) ? (parsed['ttl_hours'] as num).toInt() : 6;

    final now = DateTime.now();
    final expiresAt = now.add(Duration(hours: max(1, ttlHours))).millisecondsSinceEpoch;
    final deliveredAt = now.millisecondsSinceEpoch;

    final id = await db.insert(DatabaseTables.aiInsights, {
      DatabaseColumns.insightTitle: title,
      DatabaseColumns.insightBody: body,
      DatabaseColumns.insightTags: jsonEncode(tags),
      DatabaseColumns.insightScore: score,
      DatabaseColumns.insightUrgency: urgency,
      DatabaseColumns.insightSourceContextHash: contextHash.toString(),
      DatabaseColumns.insightDeliveredAs: 'notification',
      DatabaseColumns.insightDeliveredAt: deliveredAt,
      DatabaseColumns.insightExpiresAt: expiresAt,
    });
    print('[Insights] Stored insight id=$id notify=$shouldNotify title="$title"');

    return {
      DatabaseColumns.id: id,
      DatabaseColumns.insightTitle: title,
      DatabaseColumns.insightBody: body,
      DatabaseColumns.insightTags: jsonEncode(tags),
      DatabaseColumns.insightScore: score,
      DatabaseColumns.insightUrgency: urgency,
      DatabaseColumns.insightSourceContextHash: contextHash.toString(),
      DatabaseColumns.insightDeliveredAs: 'notification',
      DatabaseColumns.insightDeliveredAt: deliveredAt,
      DatabaseColumns.insightExpiresAt: expiresAt,
      'should_notify': shouldNotify,
    };
  }
}
