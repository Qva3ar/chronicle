class ChatMessage {
  ChatMessage(this.content, this.isUserMessage, this.isSystemMessage,
      {this.recordIds, this.isMockMessage = false});

  String content;
  final bool isUserMessage;
  bool isSystemMessage;
  bool isMockMessage = false;
  String? recordIds;
}
