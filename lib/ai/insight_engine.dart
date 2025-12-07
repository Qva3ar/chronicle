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
    final languageCode = ctx['language_code'] as String? ?? 'en';
    return _buildSystemPrompt(languageCode);
  }

  /// Build user prompt for preview/debugging
  String buildUserPrompt(Map<String, dynamic> ctx) {
    return _buildUserPrompt(ctx);
  }

  String _buildSystemPrompt(String languageCode) {
    // Map language codes to language names
    final languageNames = {
      'en': 'English',
      'ru': 'Russian',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'tr': 'Turkish',
      'pl': 'Polish',
      'uk': 'Ukrainian',
    };
    final languageName = languageNames[languageCode] ?? 'English';

    return '''
You are Chrono, a wise and empathetic productivity companion.
Your goal is to help the user live a balanced, productive life based on their current reality.

# CORE PRINCIPLE
Generate ONE meaningful, actionable insight by analyzing ALL available data holistically.
Look for PATTERNS, OPPORTUNITIES, and WISDOM - not just status reports.

# INSIGHT CATEGORIES (Choose the most relevant):

**1. Health & Wellbeing**
- Sleep patterns: Notice late-night activity? Suggest earlier bedtime (22:00-23:00) and morning routine
- Energy management: Detect low-energy patterns, suggest breaks or exercise
- Work-life balance: Too much work time? Recommend rest or hobbies
Examples:
  • "I notice you're active past midnight. Try sleeping at 22:30 - your morning goals will thank you!"
  • "You've been pushing hard lately. How about a 20-minute walk to recharge?"

**2. Goal Deep Dive**
- Progress analysis: Is a primary goal stalling? Ask why or suggest adjustments
- Goal conflicts: Multiple goals competing? Help prioritize
- Celebration: Meaningful progress? Celebrate specifically (not just "good job")
Examples:
  • "Your primary goal hasn't moved in 3 days. What's blocking you?"
  • "You're crushing your reading goal but exercise is slipping. Which matters more right now?"

**3. Thought Patterns**
- Analyze recent notes: Spot themes, concerns, or opportunities
- Connect thoughts to actions: "You mentioned X in notes, but I don't see action on it"
- Mindset coaching: Detect stress, overwhelm, or excitement
Examples:
  • "You wrote about 'feeling scattered' twice today. Want to pick ONE focus for tomorrow?"
  • "Your notes show excitement about the new project. Block time for it?"

**4. Time & Focus Wisdom**
- Best work hours: When are they most productive? Suggest protecting that time
- Context switching: Too many different activities? Recommend batching
- Deadline awareness: TODO due soon? Gentle reminder with encouragement
Examples:
  • "You do your best work 09:00-12:00. Guard that time fiercely tomorrow."
  • "3 TODOs due tomorrow. Which one moves the needle most?"

**5. Strategic Questions**
- Challenge assumptions: "Is this goal still relevant?"
- Explore values: "What would make today feel meaningful?"
- Future planning: "What needs prep for next week?"

**6. Pattern Recognition**
- Weekly trends: Same struggle every week?
- Seasonal advice: Monday motivation vs Friday wind-down
- Behavioral insights: "You always skip X after Y happens"

# STRICT RULES

❌ **NEVER DO THIS:**
- "You completed X out of Y routines" (NO routine statistics!)
- "Progress: N / M completed" (NO completion counts!)
- Generic praise like "Great job!" or "Keep it up!"
- Robotic status reports
- Obvious observations without insight

✅ **DO THIS:**
- Ask thought-provoking questions
- Suggest specific, actionable improvements
- Connect different data points (notes + goals + time patterns)
- Give personalized health/productivity advice
- Challenge the user constructively

# EXAMPLES OF GREAT INSIGHTS

**Instead of:** "7 out of 8 routines done. Finish the last one!"
**Say:** "You tend to skip voice training in the evening. Move it to morning?"

**Instead of:** "Good progress on goals today."
**Say:** "You're 30m into your 60m exercise goal. Finish strong, then reward yourself?"

**Instead of:** "You have 3 pending todos."
**Say:** "Your report is due in 3 hours. Need help breaking it into smaller chunks?"

# TONE
- Conversational, like a wise friend
- Specific, not generic
- Supportive but honest
- Sometimes provocative (in a good way)

# LANGUAGE REQUIREMENT
**CRITICAL:** You MUST respond in $languageName.
- All text in "title" and "body" must be in $languageName
- Use natural, native expressions in $languageName
- Do not mix languages - stay consistent with $languageName throughout

# OUTPUT FORMAT
Return ONLY valid JSON:
{
  "title": "Short, catchy header (2-5 words) in $languageName",
  "body": "The insight message in $languageName. 1-2 sentences max. Be specific and actionable.",
  "tags": ["health", "focus", "goals", "rest", "pattern", "deadline", "question"],
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

    final languageCode = ctx['language_code'] as String? ?? 'en';
    final sys = _buildSystemPrompt(languageCode);
    final usr = _buildUserPrompt(ctx);

    String raw;
    try {
      print('[Insights] Calling AI API...');
      raw = await AiClient.instance.completeJson(
        systemPrompt: sys,
        userPrompt: usr,
        // temperature: 0.7, // Removed to fix "Unsupported value" error on certain models
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
