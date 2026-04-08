import 'dart:async';
import 'dart:math';

import 'package:dart_openai/dart_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/helpers/api-key-options.dart';

class AiClient {
  AiClient._();
  static final AiClient instance = AiClient._();

  // Simple in-memory rate limiter
  final int maxRequestsPerMinute = 20;
  final List<DateTime> _requestTimestamps = <DateTime>[];

  // Retry config
  final int _maxRetries = 3;
  final Duration _initialBackoff = const Duration(milliseconds: 500);

  final GPTNoteBindService _bind = GPTNoteBindService();

  bool get isConfigured => _bind.isKeyProvided() && _bind.getModel.isNotEmpty;

  Future<void> ensureLoaded() async {
    if (!isConfigured) {
      await _bind.loadModel();
    }
  }

  Future<String> completeJson({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
  }) async {
    await ensureLoaded();

    if (!isConfigured) {
      print('AiClient: ❌ API key or model not configured!');
      print('AiClient: API key provided: ${_bind.isKeyProvided()}');
      print('AiClient: Model: ${_bind.getModel}');
      throw Exception('API key or model not configured. Please set them in app settings.');
    }

    final selectedOption = apiKeyOptions.firstWhere((item) => item.value == _bind.getModel, orElse: () => apiKeyOptions.first);
    final isGemini = selectedOption.provider == 'gemini';

    print('AiClient: ✅ Configuration OK - Key configured: ${_bind.isKeyProvided()}, Model: ${_bind.getModel}, Provider: ${selectedOption.provider}');
    await _throttle();

    int attempt = 0;
    Duration backoff = _initialBackoff;

    while (true) {
      try {
        print('AiClient: 🔄 Attempt ${attempt + 1}/$_maxRetries - Calling API...');
        
        String content = '';

        if (isGemini) {
          final model = GenerativeModel(
            model: _bind.getModel,
            apiKey: _bind.getGeminiKey,
            systemInstruction: Content.system(systemPrompt),
            generationConfig: GenerationConfig(
              temperature: temperature,
              responseMimeType: 'application/json',
            ),
          );

          final response = await model.generateContent([
            Content.text(userPrompt),
          ]).timeout(const Duration(seconds: 120));

          content = response.text ?? '';
        } else {
          final messages = [
            OpenAIChatCompletionChoiceMessageModel(
              role: OpenAIChatMessageRole.system,
              content: [
                OpenAIChatCompletionChoiceMessageContentItemModel(
                  type: 'text',
                  text: systemPrompt,
                )
              ],
            ),
            OpenAIChatCompletionChoiceMessageModel(
              role: OpenAIChatMessageRole.user,
              content: [
                OpenAIChatCompletionChoiceMessageContentItemModel(
                  type: 'text',
                  text: userPrompt,
                )
              ],
            ),
          ];

          final OpenAIChatCompletionModel response = temperature == null
              ? await OpenAI.instance.chat.create(
                  model: _bind.getModel,
                  messages: messages,
                ).timeout(const Duration(seconds: 120))
              : await OpenAI.instance.chat.create(
                  model: _bind.getModel,
                  temperature: temperature,
                  messages: messages,
                ).timeout(const Duration(seconds: 120));

          content = response.choices.first.message.content?.first.text ?? '';
        }

        print('AiClient: ✅ API call successful! Response length: ${content.length} chars');
        _markRequest();
        return content.trim();
      } catch (e) {
        print('AiClient: ❌ API call attempt ${attempt + 1} failed: $e');
        attempt += 1;
        
        final errorString = e.toString().toLowerCase();
        final isFatalError = errorString.contains('quota') || 
                             errorString.contains('429') || 
                             errorString.contains('rate limit') ||
                             errorString.contains('api key');

        if (isFatalError || attempt >= _maxRetries) {
          print('AiClient: ❌ Stopping retries. Final error: $e');
          rethrow;
        }
        
        // Exponential backoff with jitter
        final jitterMs = Random().nextInt(250);
        final delayDuration = backoff + Duration(milliseconds: jitterMs);
        print('AiClient: ⏳ Retrying in ${delayDuration.inMilliseconds}ms...');
        await Future.delayed(delayDuration);
        backoff *= 2;
      }
    }
  }

  Future<void> _throttle() async {
    final now = DateTime.now();
    _requestTimestamps.removeWhere(
      (ts) => now.difference(ts) > const Duration(minutes: 1),
    );
    if (_requestTimestamps.length >= maxRequestsPerMinute) {
      final oldest = _requestTimestamps.first;
      final waitFor = const Duration(minutes: 1) - now.difference(oldest);
      if (waitFor > Duration.zero) {
        await Future.delayed(waitFor);
      }
    }
  }

  void _markRequest() {
    _requestTimestamps.add(DateTime.now());
  }
}
