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
      padding: const EdgeInsets.all(12),
      // color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: !awaitingResponse
                      ? Container(
                          child: new ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 300.0,
                            ),
                            child: TextField(
                              maxLines: null,
                              autofocus: true,
                              controller: _messageController,
                              onSubmitted: onSubmitted,
                              style: TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                  hintText: 'Write your message here...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: Color.fromARGB(255, 108, 108, 108),
                                  )),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Fetching response...'),
                            ),
                            IconButton(
                                onPressed: onStop, icon: Icon(Icons.stop, color: Colors.white)),
                          ],
                        ),
                ),
                IconButton(
                  onPressed: !awaitingResponse ? () => onSubmitted(_messageController.text) : null,
                  icon: const Icon(Icons.send),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
