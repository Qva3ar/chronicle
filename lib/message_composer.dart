import 'package:flutter/material.dart';
import 'package:flutter_crud/colors.dart';

class MessageComposer extends StatelessWidget {
  MessageComposer({
    required this.onSubmitted,
    required this.awaitingResponse,
    super.key,
  });

  final TextEditingController _messageController = TextEditingController();

  final void Function(String) onSubmitted;
  final bool awaitingResponse;

  @override
  Widget build(BuildContext context) {
    print(Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05));
    return Container(
      padding: const EdgeInsets.all(12),
      // color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05),
      child: Card(
        color:
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05),
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
                              controller: _messageController,
                              onSubmitted: onSubmitted,
                              style: TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                  hintText: 'Write your message here...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: Colors.white,
                                  )),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Fetching response...'),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  onPressed: !awaitingResponse
                      ? () => onSubmitted(_messageController.text)
                      : null,
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
