import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/homepage.dart';
import 'package:chrono/models/chat-context-message.dart';
import 'package:chrono/models/enums.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    required this.content,
    required this.isUserMessage,
    required this.isNoteEditing,
    this.gptNoteBindService, // Add this parameter
    this.recordIds,
    super.key,
  });

  final String content;
  final bool isUserMessage;
  final bool isNoteEditing;
  final String? recordIds;
  final GPTNoteBindService? gptNoteBindService;
  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  // Add this property
  @override
  Widget build(BuildContext context) {
    //print(widget.recordIds);
    final themeData = Theme.of(context);

    // Show typing indicator for empty AI messages (streaming)
    if (!widget.isUserMessage && widget.content.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardColor3,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text(
                'AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 12),
              _TypingIndicator(),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isUserMessage ? cardColor2 : cardColor3,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isUserMessage ? 'You' : 'AI',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18),
                ),
                PopupMenuButton(
                    color: MyColors.trecondaryColor,
                    icon: Icon(Icons.more_vert,
                        color: MyColors.forthyColor), // add this line
                    itemBuilder: (_) => <PopupMenuItem<ContextActions>>[
                          new PopupMenuItem<ContextActions>(
                            child: Container(
                                width: 100,
                                // height: 30,
                                child: Text(
                                  'Insert',
                                  style: TextStyle(color: MyColors.fivyColor),
                                )),
                            value: ContextActions.paste,
                          ),
                          new PopupMenuItem<ContextActions>(
                              child: Container(
                                  // width: 100,
                                  // height: 30,
                                  child: Text(
                                'Replace',
                                style: TextStyle(color: MyColors.fivyColor),
                              )),
                              value: ContextActions.replace)
                        ],
                    onSelected: (index) async {
                      switch (index) {
                        case ContextActions.paste:
                          widget.gptNoteBindService?.sendMessage(
                              new ChatContextMessage(
                                  widget.content, ContextActions.paste));
                          break;
                        case ContextActions.replace:
                          widget.gptNoteBindService?.sendMessage(
                              new ChatContextMessage(
                                  widget.content, ContextActions.replace));
                          break;
                      }
                    })
              ],
            ),
            const SizedBox(height: 8),
            MarkdownWidget(
              data: widget.content,
              shrinkWrap: true,
              config: MarkdownConfig(configs: [
                PConfig(textStyle: TextStyle(color: Colors.white))
              ]),
            ),
            widget.recordIds != null && widget.recordIds!.isNotEmpty
                ? TextButton(
                    style: TextButton.styleFrom(
                        side:
                            BorderSide(color: Colors.greenAccent, width: 2.0)),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  HomePage(recordIds: widget.recordIds)));
                    },
                    child: Text(AppLocalizations.of(context).messageGoToNotes),
                  )
                : Container()
          ],
        ),
      ),
    );
  }
}

// Typing indicator widget
class _TypingIndicator extends StatefulWidget {
  @override
  __TypingIndicatorState createState() => __TypingIndicatorState();
}

class __TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay) % 1.0;
            final opacity = progress < 0.5
                ? progress * 2
                : (1 - progress) * 2;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white70,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
