import 'package:flutter/material.dart';
import 'package:flutter_crud/colors.dart';
import 'package:flutter_crud/homepage.dart';
import 'package:flutter_crud/models/chat-context-message.dart';
import 'package:flutter_crud/models/enums.dart';
import 'package:flutter_crud/services/gpt-note-bind.service.dart';
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
    print(widget.recordIds);
    final themeData = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor2,
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
                    child: Text("Go to Notes"),
                  )
                : Container()
          ],
        ),
      ),
    );
  }
}
