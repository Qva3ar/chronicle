import 'dart:async';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:Chrono/db_manager.dart';
import 'package:Chrono/message_bubble.dart';
import 'package:Chrono/message_composer.dart';
import 'package:Chrono/models/instructions.model.dart';
import 'package:Chrono/services/gpt-note-bind.service.dart';
import 'package:Chrono/services/gpt.service.dart';
import 'package:Chrono/services/messages.service.dart';
import 'package:Chrono/shared/instructions-block.dart';
import 'package:Chrono/shared/instructions.dart';

import 'models/chat-message.dart';

class ChatPageNote extends StatefulWidget {
  final MessageService messageService; // Add this field

  const ChatPageNote({
    required this.messageService,
    this.noteText,
    Key? key,
  }) : super(key: key);

  final String? noteText;

  @override
  State<ChatPageNote> createState() => _ChatPageNoteState();
}

class _ChatPageNoteState extends State<ChatPageNote> {
  final _messages = <ChatMessage>[
    // ChatMessage('Hello, how can I help?', false, false),
  ];
  var _awaitingResponse = false;
  var includeNoteText = true;
  late StreamSubscription<OpenAIStreamChatCompletionModel> stream;

  final TextEditingController _textController = TextEditingController();
  GPTService gptService = GPTService();
  DatabaseHelper dbHelper = DatabaseHelper();
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();
  List<Instruction> instructions = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.messageService.getLast20Messages().isNotEmpty) {
      _messages.addAll(widget.messageService.getLast20Messages());
    } else {
      _messages.add(ChatMessage('Hello, how can I help?', false, false, isMockMessage: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            // height: 200,
            child: ListView.builder(
              shrinkWrap: true,
              // physics: NeverScrollableScrollPhysics(),

              reverse: true, // Опция reverse
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return MessageBubble(
                  content: msg.content,
                  isNoteEditing: true,
                  gptNoteBindService: gptNoteBindService,
                  isUserMessage: msg.isUserMessage,
                );
              },
            ),
          ),
        ),
        InstructionsBlockWidget(onSubmitted: (String instruction) {
          _textController.text = instruction;
          setState(() {});
        }),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16),
        //   child: Column(
        //     children: [
        //       Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        //         Text(
        //           "Include Note's data",
        //           style: TextStyle(color: Colors.white),
        //         ),
        //         Switch(
        //           value: includeNoteText,
        //           onChanged: (newValue) {
        //             setState(() {
        //               includeNoteText = newValue;
        //             });
        //           },
        //         ),
        //       ]),
        //     ],
        //   ),
        // ),
        MessageComposer(
          onSubmitted: _onSubmitted,
          onStop: _onStop,
          awaitingResponse: _awaitingResponse,
          initialText: _textController.text,
        ),
      ],
    );
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

  _onStop() {
    stream.cancel();
  }

  Future<void> _onSubmitted(String message) async {
    List<ChatMessage> _systemMessages = [];
    final userMessage = ChatMessage(message, true, false);
    //remove item from messages where isMockMessage == true
    _messages.removeWhere((element) => element.isMockMessage == true);
    setState(() {
      _messages.insert(0, userMessage); // Вставка в начало списка
      _awaitingResponse = true;
    });
    widget.messageService.addMessage(userMessage);
    _textController.clear(); // Очистка текстового поля

    String accumulator = '';
    try {
      if (includeNoteText) {
        _systemMessages
            .add(ChatMessage(Instractions.useUserNoteText(widget.noteText ?? ''), false, true));
      }

      _messages.insert(0, ChatMessage("", false, false));
      stream = await gptService.completionStream(_messages, _systemMessages).listen((event) {
        final content = event.choices.first.delta.content;
        // //print(content);
        accumulator += content![0].text ?? '';

        if (event.choices.first.finishReason == 'stop') {
          widget.messageService.addMessage(ChatMessage(accumulator, false, false));
        }
        setState(() {
          _messages.first.content = accumulator; // Вставка в начало списка
          _awaitingResponse = false;
        });
      }, onDone: () {
        setState(() {
          _awaitingResponse = false;
        });
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
