import 'package:flutter/material.dart';
import 'package:flutter_crud/api/chat-api.dart';
import 'package:flutter_crud/colors.dart';
import 'package:flutter_crud/message_bubble.dart';
import 'package:flutter_crud/message_composer.dart';
import 'package:flutter_crud/services/gpt-note-bind.service.dart';
import 'package:flutter_crud/services/gpt.service.dart';
import 'package:flutter_crud/services/messages.service.dart';
import 'package:flutter_crud/shared/instructions.dart';

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
    ChatMessage('Hello, how can I help?', false, false),
  ];
  var _awaitingResponse = false;
  var includeNoteText = false;

  final TextEditingController _textController = TextEditingController();
  GPTService gptService = GPTService();
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();

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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Include Note's data"),
                Switch(
                  value: includeNoteText,
                  onChanged: (newValue) {
                    setState(() {
                      includeNoteText = newValue;
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
    try {
      if (includeNoteText) {
        _systemMessages.add(ChatMessage(
            Instractions.useUserNoteText(widget.noteText ?? ''), false, true));
      }

      _messages.insert(0, ChatMessage("", false, false));
      await gptService
          .completionStream(_messages, _systemMessages)
          .listen((event) {
        final content = event.choices.first.delta.content;
        print(content);
        accumulator += content!;

        if (event.choices.first.finishReason == 'stop') {
          widget.messageService
              .addMessage(ChatMessage(accumulator, false, false));
        }
        setState(() {
          _messages.first.content = accumulator; // Вставка в начало списка
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
