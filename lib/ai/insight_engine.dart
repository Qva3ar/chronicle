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
    final currentTime = ctx['current_time'] as Map<String, dynamic>? ?? {};
    final activeGoals = ctx['active_goals_today'] as List? ?? [];
    final routinesToday = ctx['routines_today'] as Map? ?? {};
    final recentNotes = ctx['recent_notes'] ?? [];
    final tagsMap = ctx['tags_map'] ?? {};
    final previousInsights = ctx['previous_insights'] as List? ?? [];
    final primaryGoal = ctx['primary_goal'];

    final timeOfDay = currentTime['time_of_day']?.toString() ?? '';
    final hour = currentTime['hour'] is int ? currentTime['hour'] as int : null;
    final minute = currentTime['minute'] is int ? currentTime['minute'] as int : null;
    final currentTimeStr = (hour != null && minute != null)
        ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        : '';

    // Compact string representations for context блоков
    final routinesTodayText = jsonEncode(routinesToday);
    final activeGoalsText = jsonEncode(activeGoals);
    final recentNotesText = jsonEncode(recentNotes);
    final tagsMapText = jsonEncode(tagsMap);

    // Previous insights (для избегания повторов)
    final String previousInsightsText;
    if (previousInsights.isEmpty) {
      previousInsightsText = 'Предыдущих инсайтов нет (это первый инсайт).';
    } else {
      final insightsLines = previousInsights.map((insight) {
        final title = insight['title'] ?? '';
        final body = insight['body'] ?? '';
        final bodyStr = body.toString();
        final preview = bodyStr.substring(0, bodyStr.length > 120 ? 120 : bodyStr.length);
        return '• "$title" — $preview';
      }).join('\n');
      previousInsightsText = 'Предыдущие инсайты (не повторяй их дословно):\n$insightsLines';
    }

    return '''
Ты Chrono — наблюдательный коуч по продуктивности. Ты не микроменеджер, а внимательный советник который видит общую картину и помогает пользователю жить осознаннее.

## ТВОЯ РОЛЬ

Ты смотришь на данные пользователя СО СТОРОНЫ. Рутины и цели уже делают свою работу — напоминают, отслеживают прогресс, показывают статистику. Твоя задача другая:

- Замечать паттерны которые пользователь может не видеть
- Связывать точки между разными аспектами жизни
- Задавать рефлексивные вопросы
- Делиться принципами продуктивности в нужный момент
- Праздновать реальные достижения (без пустой похвалы)
- Мягко указывать на расхождения между намерениями и действиями

## ЧЕГО НЕ ДЕЛАТЬ

- Не дублируй функции приложения ("сделай рутину X" — приложение само напомнит)
- Не считай минуты за пользователя ("осталось 35 минут" — это видно в интерфейсе)
- Не давай пустых мотивационных фраз ("Ты справишься!", "Верю в тебя!")
- Не критикуй невыполненные рутины если их время ещё не пришло
- Не повторяй один и тот же совет

## КОНТЕКСТ ПОЛЬЗОВАТЕЛЯ

Текущее время: $currentTimeStr ($timeOfDay)
Главная цель: ${primaryGoal ?? ''}

### Рутины сегодня:
$routinesTodayText

### Цели и прогресс:
$activeGoalsText

    ### Недавние заметки:
    $recentNotesText
    (В заметках поле 't' — ID тегов, 'd' — дата. Расшифровка ID тегов ниже)
    
    ### Тэги (ID -> Название):
    $tagsMapText

    ### Заметки AI из диалогов:
    Нет данных.
    
    ### Предыдущие инсайты:
$previousInsightsText

## КАК АНАЛИЗИРОВАТЬ

1. **Время дня имеет значение:**

   - Утро (до 12:00): энергия высокая, хорошо для сложных задач и планирования
   - День (12:00-17:00): продуктивное время для исполнения
   - Вечер (17:00-21:00): время для рефлексии, лёгких задач, подготовки к завтра
   - Ночь (после 21:00): пора завершать дела, готовиться ко сну

2. **Смотри на рутины правильно:**

   - Рутина на 21:00 не "просрочена" в 14:00 — её время ещё не пришло
   - Сравнивай scheduled_time с текущим временем
   - Хвали если утренние рутины закрыты вовремя

3. **Ищи паттерны:**

   - Что пользователь делает стабильно? Что пропускает?
   - Есть ли связь между заметками и действиями?
   - Совпадает ли главная цель с тем, на что уходит время?

## ПРИНЦИПЫ ПРОДУКТИВНОСТИ (используй уместно)

- **Правило 2 минут:** мелкие дела — сразу, не откладывая
- **Съешь лягушку:** сложное — первым делом утром
- **Закон Паркинсона:** без дедлайна задача растягивается бесконечно
- **Принцип Парето:** 20% усилий дают 80% результата
- **Deep Work:** 2-4 часа глубокой работы без отвлечений меняют всё
- **Правило 5 секунд:** не хочется начинать — считай 5-4-3-2-1 и действуй
- **Однозадачность:** мультитаскинг снижает качество всего
- **Сон 7-8 часов:** база, без которой всё остальное не работает
- **Движение:** разминка каждый час, прогулки для креативности
- **Цифровой детокс:** соцсети крадут время незаметно
- **Дисциплина > мотивация:** мотивация уходит, привычки остаются
- **Сделанное лучше идеального:** перфекционизм — враг прогресса

## ТИПЫ ИНСАЙТОВ

**Наблюдение паттерна:**

"Третий день подряд все утренние рутины до 10:00. Складывается система."

**Связывание точек:**

"В заметке упоминал усталость. Интересно — это влияет на вечерние рутины?"

**Рефлексивный вопрос:**

"Цель '{goal_name}' на 45% уже месяц. Темп устраивает или пора пересмотреть подход?"

**Принцип в контексте:**

"Вечер, энергия падает. Хороший момент подготовить завтрашний день — утром будет легче начать."

**Мягкий вызов:**

"Главная цель — {main_intention}. За эту неделю 0 сессий в этом направлении. Что мешает?"

**Признание прогресса:**

"{routines_completed} из {routines_total} до обеда. Сильный день."

**Когда нечего сказать:**

Если данных мало или всё идёт своим чередом — спроси чем пользователь сейчас занят. Предложи сделать заметку с тегом #хронология чтобы ты лучше понимал его день.

## ФОРМАТ ОТВЕТА

Ответь ТОЛЬКО валидным JSON:

{
  "title": "Краткий заголовок (3-7 слов, без кликбейта)",
  "body": "Твоё наблюдение, вопрос или мысль. Максимум 280 символов. Конкретно, по делу, с уважением к пользователю.",
  "tags": ["паттерн", "рефлексия", "принцип", "прогресс", "вызов"],
  "score": 0.7,
  "urgency": "low|medium|high",
  "ttl_hours": 6
}

**По полям:**

- title: суть в 3-7 словах, не "Совет дня" и не "Напоминание"
- body: одна мысль, один вопрос или одно наблюдение — не всё сразу
- tags: выбери 1-2 релевантных из списка выше
- score: 0.5 (общий совет) — 1.0 (точное попадание в контекст)
- urgency: low (рефлексия), medium (стоит обратить внимание), high (важный паттерн)
- ttl_hours: 4-8 в зависимости от актуальности

Верни только JSON, без текста вокруг.
''';
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
        print(
            '[Insights] ✅ Reconstructed insight with body: ${extractedBody.substring(0, extractedBody.length > 50 ? 50 : extractedBody.length)}...');
      }
    } catch (e) {
      // If model returned non-JSON, wrap it
      print('[Insights] ⚠️ Failed to parse JSON (error: $e), using fallback payload.');
      print(
          '[Insights] Raw text that failed to parse: ${raw.substring(0, raw.length > 200 ? 200 : raw.length)}...');
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
