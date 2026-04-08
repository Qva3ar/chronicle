import 'dart:async';
import 'package:dart_openai/dart_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:chrono/models/chat-message.dart';
import 'package:chrono/models/tag.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/helpers/api-key-options.dart';
import 'package:http/http.dart' as http;

class GPTService {
  late StreamSubscription<http.Response> streamSubscription;
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();

  Future<String> getCompletion(String input, List<Tag> tags) async {
    final selectedOption = apiKeyOptions.firstWhere((item) => item.value == gptNoteBindService.getModel, orElse: () => apiKeyOptions.first);
    final isGemini = selectedOption.provider == 'gemini';
    final sysPrompt = "Here is a list of tags for you ${tags.toString()}. Choose the one that best matches the user input and give me just the id. Use the 'name' field for comparison. Try to find some similarities with the tags. You can provide multiple tags in the form of an array. Desired format should be array:[id, id]. Do not write any other words except format that I gave you!";

    if (isGemini) {
      final model = GenerativeModel(
        model: gptNoteBindService.getModel,
        apiKey: gptNoteBindService.getGeminiKey,
        systemInstruction: Content.system(sysPrompt),
        generationConfig: GenerationConfig(temperature: 0.2),
      );
      final response = await model.generateContent([Content.text(input)]);
      return response.text ?? '';
    } else {
      OpenAIChatCompletionModel chatCompletion = await OpenAI.instance.chat.create(
        model: gptNoteBindService.getModel,
        temperature: 0.2,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [OpenAIChatCompletionChoiceMessageContentItemModel(text: sysPrompt, type: 'text')],
            role: OpenAIChatMessageRole.system,
          ),
          OpenAIChatCompletionChoiceMessageModel(
            content: [OpenAIChatCompletionChoiceMessageContentItemModel(text: input, type: 'text')],
            role: OpenAIChatMessageRole.user,
          ),
        ],
      );
      return chatCompletion.choices.first.message.content?.first.text ?? '';
    }
  }

  Stream<String> completionStream(List<ChatMessage> messages, List<ChatMessage> systemMessages) {
    if (systemMessages.isNotEmpty) {
      messages = messages + systemMessages;
    }
    
    final selectedOption = apiKeyOptions.firstWhere((item) => item.value == gptNoteBindService.getModel, orElse: () => apiKeyOptions.first);
    final isGemini = selectedOption.provider == 'gemini';

    if (isGemini) {
      final sysMsg = messages.where((e) => e.isSystemMessage).map((e) => e.content).join('\n');
      final userMsgs = messages.where((e) => !e.isSystemMessage).toList().reversed.toList();
      
      final geminiContents = userMsgs.map((e) {
        return Content(e.isUserMessage ? 'user' : 'model', [TextPart(e.content)]);
      }).toList();

      final model = GenerativeModel(
        model: gptNoteBindService.getModel,
        apiKey: gptNoteBindService.getGeminiKey,
        systemInstruction: sysMsg.isNotEmpty ? Content.system(sysMsg) : null,
        generationConfig: GenerationConfig(temperature: 1.0),
      );

      return model.generateContentStream(geminiContents).map((response) => response.text ?? '');
    } else {
      Stream<OpenAIStreamChatCompletionModel> chatStream = OpenAI.instance.chat.createStream(
        model: gptNoteBindService.getModel,
        temperature: 1,
        messages: messages.map((e) => OpenAIChatCompletionChoiceMessageModel(
          role: e.isSystemMessage
              ? OpenAIChatMessageRole.system
              : e.isUserMessage
                  ? OpenAIChatMessageRole.user
                  : OpenAIChatMessageRole.assistant,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel(text: e.content, type: 'text')
          ],
        )).toList().reversed.toList()
      );

      return chatStream.map((event) {
        final content = event.choices.first.delta.content;
        if (content != null && content.isNotEmpty) {
          return content[0].text ?? '';
        }
        return '';
      });
    }
  }
}
