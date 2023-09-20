import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_crud/models/chat-message.dart';
import 'package:flutter_crud/models/tag.dart';
import 'package:http/http.dart' as http;

final apiKey = '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';

Future<String> generateResponse(String input, List<Tag> tags) async {
  final apiUrl = 'https://api.openai.com/v1/chat/completions';

  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "model": "gpt-3.5-turbo",
      "stream": true,
      "messages": [
        {
          "role": "system",
          "content":
              "вот тебе массив с тегами ${tags.toString()}, подбери исходя из текста пользователя"
        },
        {"role": "user", "content": input}
      ],
      'max_tokens': 50, // Максимальное количество токенов в ответе
    }),
  );

  if (response.statusCode == 200) {
    final responseData = json.decode(response.body);
    final generatedText = responseData['choices'][0]['message']['content'];

    // final generatedText = responseData['choices'][0]['text'];
    print(generatedText);
    return generatedText;
  } else {
    throw Exception('Failed to generate response');
  }
}

class GPTService {
  late StreamSubscription<http.Response> streamSubscription;

  Future<OpenAIChatCompletionModel> getCompletion(
      String input, List<Tag> tags) async {
    OpenAIChatCompletionModel chatCompletion =
        await OpenAI.instance.chat.create(
      model: "gpt-3.5-turbo",
      temperature: 0.2,
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content:
              "Here is a list of tags for you ${tags.toString()}. Choose the one that best matches the user input and give me just the id. Use the 'name' field for comparison. Try to find some similarities with the tags. You can provide multiple tags in the form of an array. Desired format should be array:[id, id]. Do not write any other words except format that I gave you!",
          role: OpenAIChatMessageRole.system,
        ),
        OpenAIChatCompletionChoiceMessageModel(
          content: input,
          role: OpenAIChatMessageRole.user,
        ),
      ],
    );
    return chatCompletion;
  }

  startStream() {
    Stream<OpenAIStreamChatCompletionModel> chatStream =
        OpenAI.instance.chat.createStream(
      model: "gpt-3.5-turbo",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: "hello",
          role: OpenAIChatMessageRole.user,
        )
      ],
    );

    chatStream.listen((streamChatCompletion) {
      final content = streamChatCompletion.choices.first.delta.content;
      print(content);
    });
  }

  Stream<OpenAIStreamChatCompletionModel> completionStream(
      List<ChatMessage> messages, List<ChatMessage> systemMessages) {
    if (systemMessages.length > 0) {
      messages = messages + systemMessages;
    }
    Stream<OpenAIStreamChatCompletionModel> chatStream =
        OpenAI.instance.chat.createStream(
            model: "gpt-3.5-turbo",
            temperature: 0.2,
            messages: messages
                .map((e) => OpenAIChatCompletionChoiceMessageModel(
                      role: e.isSystemMessage
                          ? OpenAIChatMessageRole.system
                          : e.isUserMessage
                              ? OpenAIChatMessageRole.user
                              : OpenAIChatMessageRole.assistant,
                      content: e.content,
                    ))
                .toList()
                .reversed
                .toList());

    return chatStream;
    // .listen((streamChatCompletion) {
    //   final content = streamChatCompletion.choices.first.delta.content;
    //   print(content);
    // });
  }
}
