import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    required this.onSubmitted,
    required this.onStop,
    required this.awaitingResponse,
    super.key,
    this.initialText = '',
    this.controller,
  });

  final void Function(String) onSubmitted;
  final void Function() onStop;
  final bool awaitingResponse;
  final String initialText;
  final TextEditingController? controller;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  late final TextEditingController _messageController;
  late final bool _ownsController;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _messageController = widget.controller ??
        TextEditingController(text: widget.initialText)
          ..selection = TextSelection.collapsed(offset: widget.initialText.length);
    _canSend = _messageController.text.trim().isNotEmpty;
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final canSend = _messageController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    if (_ownsController) {
      _messageController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sendEnabled = !widget.awaitingResponse && _canSend;

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
                    readOnly: widget.awaitingResponse,
                    textInputAction: TextInputAction.send,
                    controller: _messageController,
                    onSubmitted: widget.onSubmitted,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
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
                      hintText: AppLocalizations.of(context).composerHint,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Color.fromARGB(255, 108, 108, 108),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.awaitingResponse
                    ? widget.onStop
                    : (sendEnabled ? () => widget.onSubmitted(_messageController.text) : null),
                icon: Icon(widget.awaitingResponse ? Icons.stop : Icons.send),
                color: widget.awaitingResponse || sendEnabled
                    ? Colors.white
                    : const Color.fromARGB(255, 108, 108, 108),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
