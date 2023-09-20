class ChatMessage {
  ChatMessage(this.content, this.isUserMessage, this.isSystemMessage,
      {this.recordIds});

  String content;
  final bool isUserMessage;
  bool isSystemMessage;
  String? recordIds;
}
