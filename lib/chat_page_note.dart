import 'dart:async';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/message_bubble.dart';
import 'package:chrono/message_composer.dart';
import 'package:chrono/models/instructions.model.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/services/gpt.service.dart';
import 'package:chrono/services/messages.service.dart';
import 'package:chrono/shared/instructions-block.dart';
import 'package:chrono/shared/instructions.dart';

import 'models/chat-message.dart';

class ChatPageNote extends StatefulWidget {
  final MessageService messageService;

  const ChatPageNote({
    required this.messageService,
    this.noteText,
    this.linkedContext,
    this.linkedCount = 0,
    this.initialDraftText,
    this.onDraftChanged,
    Key? key,
  }) : super(key: key);

  final String? noteText;

  /// Full context including linked notes. When non-null and [linkedCount] > 0,
  /// a selector is shown letting the user choose whether the AI sees only the
  /// document ([noteText]) or the document plus linked notes ([linkedContext]).
  final String? linkedContext;
  final int linkedCount;
  final String? initialDraftText;
  final ValueChanged<String>? onDraftChanged;

  @override
  State<ChatPageNote> createState() => _ChatPageNoteState();
}

class _ChatPageNoteState extends State<ChatPageNote> {
  final _messages = <ChatMessage>[
    // ChatMessage('Hello, how can I help?', false, false),
  ];
  var _awaitingResponse = false;
  var includeNoteText = true;

  /// Whether linked notes are included in the AI context. Only relevant when
  /// [widget.linkedContext] is available. Defaults to document-only.
  bool _includeLinked = false;
  late StreamSubscription<String> stream;

  bool get _hasLinkedOption => widget.linkedContext != null && widget.linkedCount > 0;

  late final TextEditingController _textController;
  GPTService gptService = GPTService();
  DatabaseHelper dbHelper = DatabaseHelper.instance;
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();
  List<Instruction> instructions = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialDraftText ?? '');
    if (widget.messageService.getLast20Messages().isNotEmpty) {
      _messages.addAll(widget.messageService.getLast20Messages());
    } else {
      _messages.add(ChatMessage('Hello, how can I help?', false, false, isMockMessage: true));
    }
  }

  @override
  void dispose() {
    // Persist draft text back to parent
    widget.onDraftChanged?.call(_textController.text);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasLinkedOption) _contextSelector(),
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
        InstructionsBlockWidget(
          onSubmitted: _onSubmitted,
          textController: _textController,
        ),
        MessageComposer(
          onSubmitted: _onSubmitted,
          onStop: _onStop,
          awaitingResponse: _awaitingResponse,
          controller: _textController,
        ),
      ],
    );
  }

  Widget _contextSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 15, color: textMuted),
          const SizedBox(width: 6),
          Text(
            'AI context',
            style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: MyColors.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _contextTab(
                    label: 'Document',
                    selected: !_includeLinked,
                    onTap: () => setState(() => _includeLinked = false),
                  ),
                  _contextTab(
                    label: '+ Notes (${widget.linkedCount})',
                    selected: _includeLinked,
                    onTap: () => setState(() => _includeLinked = true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? MyColors.orangeDivider : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? MyColors.primaryColor : textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
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
    _textController.clear();
    widget.onDraftChanged?.call('');

    String accumulator = '';
    try {
      if (includeNoteText) {
        final noteContent = (_includeLinked && widget.linkedContext != null)
            ? widget.linkedContext!
            : (widget.noteText ?? '');
        _systemMessages.add(ChatMessage(Instractions.useUserNoteText(noteContent), false, true));
      }

      _messages.insert(0, ChatMessage("", false, false));
      stream = gptService.completionStream(_messages, _systemMessages).listen((textChunk) {
        accumulator += textChunk;

        setState(() {
          _messages.first.content = accumulator; // Вставка в начало списка
          _awaitingResponse = false;
        });
      }, onDone: () {
        widget.messageService.addMessage(ChatMessage(accumulator, false, false));
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
