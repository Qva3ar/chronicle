import 'dart:async';
import 'dart:developer';

import 'package:Chrono/colors.dart';
import 'package:Chrono/features/notes/data/db/record.service.dart';
import 'package:Chrono/helpers/api-key-options.dart';
import 'package:Chrono/helpers/token.helper.dart';
import 'package:Chrono/message_bubble.dart';
import 'package:Chrono/message_composer.dart';
import 'package:Chrono/models/record.dart';
import 'package:Chrono/models/tag.dart';
import 'package:Chrono/services/gpt-note-bind.service.dart';
import 'package:Chrono/services/gpt.service.dart';
import 'package:Chrono/services/messages.service.dart';
import 'package:Chrono/shared/instructions-block.dart';
import 'package:Chrono/shared/instructions.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';

import 'core/db/db_manager.dart';
import 'models/chat-message.dart';

class ChatPage extends StatefulWidget {
  MessageService messageService = MessageService();

  ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messages = <ChatMessage>[];
  final List<Record> allRecords = [];
  List<Tag> allTags = [];
  // List<ChatMessage> _tokenMessages = [];

  var _awaitingResponse = false;
  var includeAllNote = false;
  final TextEditingController _textController = TextEditingController();
  final dbHelper = DatabaseHelper();
  late StreamSubscription<OpenAIStreamChatCompletionModel> stream;

  double tokenCount = 0;
  bool isTokenCounting = false;

  GPTService gptService = GPTService();
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();
  RecordService recordService = RecordService();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.messageService.getLast20Messages().isNotEmpty) {
      _messages.addAll(widget.messageService.getLast20Messages());
    } else {
      _messages.add(ChatMessage('Hello, how can I help?', false, false));
    }

    getAllTags();
  }

  void getAllTags() async {
    allTags = await recordService.queryAllTagsJust();
    // allTags = await recordService.queryAllTagsJust();
  }

  getUserNotes() async {
    final newRecords = await recordService.queryRecords();
    allRecords.clear();
    if (newRecords.isNotEmpty) {
      allRecords.addAll(newRecords);
    } else {}
    final count = await processMessages(allRecords);
    //find model from apitokenoptions and get price
    final model =
        apiKeyOptions.firstWhere((element) => element.value == gptNoteBindService.getModel);
    //round to 2 digits
    String inString = (count / 1000 * model.price).toStringAsFixed(8);

    setState(() {
      isTokenCounting = false;
      tokenCount = double.parse(inString);
    });
    setState(() {});
  }

  String extractValue(String input) {
    RegExp regExp = RegExp(r'Found:\s*\[(.*?)\]');
    Match? match = regExp.firstMatch(input);

    if (match != null) {
      return match.group(1)!; // group(1) contains the value within square brackets
    } else {
      return ""; // Return an empty string if no match is found
    }
  }

  showErrorDialog(String errorMessage) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Unexpected Error'),
            content: Text(
              'Error: $errorMessage',
              style: TextStyle(color: Colors.black),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardColor,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Color(0x0d2196f3),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Опция reverse
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return MessageBubble(
                  content: msg.content,
                  isNoteEditing: false,
                  isUserMessage: msg.isUserMessage,
                  recordIds: msg.recordIds,
                );
              },
            ),
          ),
          InstructionsBlockWidget(onSubmitted: _onSubmitted),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    "Include all user data",
                    style: TextStyle(color: Colors.white),
                  ),
                  Switch(
                    value: includeAllNote,
                    onChanged: (newValue) {
                      setState(() {
                        includeAllNote = newValue;
                        if (newValue) {
                          getUserNotes();
                        } else {
                          tokenCount = 0;
                        }
                      });
                    },
                  ),
                ]),
              ],
            ),
          ),
          Visibility(
              visible: includeAllNote,
              child: isTokenCounting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 10),
                        Text('Counting tokens...'),
                      ],
                    )
                  : Text(
                      'Approximate cost of next query: ~\$${tokenCount}',
                      style: TextStyle(color: Colors.white),
                    )),
          MessageComposer(
            onSubmitted: _onSubmitted,
            onStop: onStop,
            awaitingResponse: _awaitingResponse,
          ),
        ],
      ),
    );
  }

  onStop() {
    stream.cancel();
    setState(() {
      _awaitingResponse = false;
    });
  }

  Future<double> processMessages(List<Record> messages) async {
    setState(() {
      isTokenCounting = true;
    });
    // Concatenate messages into a single string
    final combinedMessages = messages.map((message) => message.text).join(' ');
    // //print(combinedMessages);
    // Count tokens asynchronously
    return await countTokensAsync(combinedMessages);
  }

  Future<void> _onSubmitted(String message) async {
    List<ChatMessage> _systemMessages = [];
    final userMessage = ChatMessage(message, true, false);
    setState(() {
      _messages.insert(0, userMessage); // Вставка в начало спискаs
      _awaitingResponse = true;
    });
    widget.messageService.addMessage(userMessage);
    _textController.clear(); // Очистка текстового поля

    String accumulator = '';

    if (includeAllNote) {
      _systemMessages
          .add(ChatMessage(Instractions.useUserAllNotes(allRecords, allTags), false, true));
      log(Instractions.useUserAllNotes(allRecords, allTags));
    }
    // _systemMessages.add(ChatMessage(Instractions.findRecords(), false, true));

    try {
      //_messages as string

      _messages.insert(0, ChatMessage("", false, false));
      stream = await gptService.completionStream(_messages, _systemMessages).listen((event) {
        final content = event.choices.first.delta.content;
        //print(content);
        accumulator += content![0].text ?? '';

        if (event.choices.first.finishReason == 'stop') {}
        _messages.first.content = accumulator;
        setState(() {});
      }, onError: (err) {
        if (err is RequestFailedException) {
          // Handle 400 status code
          final errorMessage = err.message;
          //print('Error: $errorMessage');

          // Display the error message to the user (you can use a Snackbar or any other UI element)
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Error: $errorMessage')),
          // );
          showErrorDialog(errorMessage);
        } else {
          // Handle other exceptions
          //print('An unexpected error occurred: $err');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An unexpected error occurred. Please try again.')),
          );
        }

        setState(() {
          _awaitingResponse = false;
        });
      }, onDone: () {
        final ids = extractValue(accumulator);
        _messages.first.recordIds = ids;
        widget.messageService.addMessage(ChatMessage(accumulator, false, false));
        setState(() {
          _awaitingResponse = false;
        });
      });
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
      setState(() {
        _awaitingResponse = false;
      });
    }
  }
}
