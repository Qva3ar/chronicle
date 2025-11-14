import 'package:flutter/material.dart';

class MessageComposer extends StatelessWidget {
  MessageComposer({
    required this.onSubmitted,
    required this.onStop,
    required this.awaitingResponse,
    super.key,
    this.initialText = '',
  }) : _messageController = TextEditingController(text: initialText)
          ..selection = TextSelection.collapsed(offset: initialText.length);

  // final TextEditingController _messageController = TextEditingController();
  final TextEditingController _messageController;
  final void Function(String) onSubmitted;
  final void Function() onStop;
  final bool awaitingResponse;
  final String initialText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.05),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300.0,
                  ),
                  child: TextField(
                    maxLines: null,
                    autofocus: true,
                    readOnly: awaitingResponse,
                    textInputAction: TextInputAction.send,
                    controller: _messageController,
                    onSubmitted: onSubmitted,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Colors.transparent, width: 0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Colors.transparent, width: 0),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Colors.transparent, width: 0),
                      ),
                      hintText: 'Write your message here...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Color.fromARGB(255, 108, 108, 108),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: awaitingResponse ? onStop : () => onSubmitted(_messageController.text),
                icon: Icon(awaitingResponse ? Icons.stop : Icons.send),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
