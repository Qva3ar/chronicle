import 'package:chrono/models/enums.dart';

class ChatContextMessage {
  ChatContextMessage(this.content, this.action);

  String content;
  ContextActions action;
}
