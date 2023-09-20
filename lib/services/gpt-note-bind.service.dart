import 'package:flutter_crud/models/chat-context-message.dart';
import 'package:rxdart/rxdart.dart'; // Import RxDart

class GPTNoteBindService {
  // Private constructor
  GPTNoteBindService._();

  // Static instance variable to hold the singleton instance
  static final GPTNoteBindService _instance = GPTNoteBindService._();

  // Factory constructor to return the singleton instance
  factory GPTNoteBindService() {
    return _instance;
  }

  // Create a Subject to manage the communication
  final PublishSubject<ChatContextMessage> _messageSubject =
      PublishSubject<ChatContextMessage>();

  // Stream for receiving messages from one widget to another
  Stream<ChatContextMessage> get messageStream => _messageSubject.stream;

  // Function to send a message from one widget to another
  void sendMessage(ChatContextMessage message) {
    _messageSubject.add(message);
  }

  // Dispose the subject when it's no longer needed
  void dispose() {
    _messageSubject.close();
  }
}
