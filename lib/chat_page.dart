import 'package:flutter/material.dart';
import 'package:flutter_crud/api/chat-api.dart';
import 'package:flutter_crud/colors.dart';
import 'package:flutter_crud/message_bubble.dart';
import 'package:flutter_crud/message_composer.dart';
import 'package:flutter_crud/models/record.dart';
import 'package:flutter_crud/services/gpt.service.dart';
import 'package:flutter_crud/services/messages.service.dart';
import 'package:flutter_crud/shared/instructions.dart';

import 'db_manager.dart';
import 'models/chat-message.dart';

class ChatPage extends StatefulWidget {
  final MessageService messageService; // Add this field

  ChatPage({Key? key, required this.messageService}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messages = <ChatMessage>[];
  final List<Record> allRecords = [];
  var _awaitingResponse = false;
  var includeAllNote = false;
  final TextEditingController _textController = TextEditingController();
  final dbHelper = DatabaseHelper.instance;

  GPTService gptService = GPTService();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.messageService.getLast20Messages().isNotEmpty) {
      _messages.addAll(widget.messageService.getLast20Messages());
    } else {
      _messages.add(ChatMessage('Hello, how can I help?', false, false));
    }
  }

  getUserNotes() async {
    final newRecords = await dbHelper.queryAllRecords();

    if (newRecords.isNotEmpty) {
      allRecords.addAll(newRecords);
    } else {}
    setState(() {});
  }

  String extractValue(String input) {
    RegExp regExp = RegExp(r'Found:\s*\[(.*?)\]');
    Match? match = regExp.firstMatch(input);

    if (match != null) {
      return match
          .group(1)!; // group(1) contains the value within square brackets
    } else {
      return ""; // Return an empty string if no match is found
    }
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Include Note's data"),
                      Switch(
                        value: includeAllNote,
                        onChanged: (newValue) {
                          setState(() {
                            includeAllNote = newValue;
                            if (newValue) {
                              getUserNotes();
                            }
                          });
                        },
                      ),
                    ]),
              ],
            ),
          ),
          MessageComposer(
            onSubmitted: _onSubmitted,
            awaitingResponse: _awaitingResponse,
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmitted(String message) async {
    List<ChatMessage> _systemMessages = [];
    final userMessage = ChatMessage(message, true, false);
    setState(() {
      _messages.insert(0, userMessage); // Вставка в начало списка
      _awaitingResponse = true;
    });
    widget.messageService.addMessage(userMessage);
    _textController.clear(); // Очистка текстового поля

    String accumulator = '';

    if (includeAllNote) {
      _systemMessages.add(
          ChatMessage(Instractions.useUserAllNotes(allRecords), false, true));
    }
    _systemMessages.add(ChatMessage(Instractions.findRecords(), false, true));

    try {
      _messages.insert(0, ChatMessage("", false, false));
      await gptService
          .completionStream(_messages, _systemMessages)
          .listen((event) {
        final content = event.choices.first.delta.content;
        print(content);
        accumulator += content!;

        if (event.choices.first.finishReason == 'stop') {
          final ids = extractValue(accumulator);
          _messages.first.recordIds = ids;
          widget.messageService
              .addMessage(ChatMessage(accumulator, false, false));
        }
        _messages.first.content = accumulator;
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
