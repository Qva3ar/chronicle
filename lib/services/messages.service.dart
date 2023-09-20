import '../models/chat-message.dart';

class MessageService {
  List<ChatMessage> _messageList = [];

  // Add a message to the list
  void addMessage(ChatMessage message) {
    _messageList.add(message);
    // Keep only the last 20 messages
    if (_messageList.length > 20) {
      _messageList.removeRange(0, _messageList.length - 20);
    }
  }

  // Get the last 20 messages
  List<ChatMessage> getLast20Messages() {
    return List<ChatMessage>.from(_messageList.reversed);
  }
}
