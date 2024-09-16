import 'package:dart_openai/dart_openai.dart';
import 'package:Chrono/models/chat-context-message.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import RxDart

class GPTNoteBindService {
  // Private constructor
  GPTNoteBindService._();

  // Static instance variable to hold the singleton instance
  static final GPTNoteBindService _instance = GPTNoteBindService._();

  // Factory constructor to return the singleton instance
  factory GPTNoteBindService() {
    return _instance;
  }

  String key = '';
  String model = '';

  //getter setter for key
  String get getKey => key;
  setKey(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    OpenAI.apiKey = key;
    await prefs.setString('key', key); // Save the model to SharedPreferences
    this.key = key;
  }

  bool isKeyProvided() {
    return key.isNotEmpty;
  }

  //getter setter for model
  String get getModel => model;
  setModel(String model) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('model', model); // Save the model to SharedPreferences
    this.model = model;
  }

  Future<void> loadModel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    this.model = prefs.getString('model') ?? ''; // Load the model from SharedPreferences
    this.key = prefs.getString('key') ?? ''; // Load the model from SharedPreferences
    OpenAI.apiKey = this.key;
  }

  // Create a Subject to manage the communication
  final PublishSubject<ChatContextMessage> _messageSubject = PublishSubject<ChatContextMessage>();

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
