import 'package:flutter_crud/models/enums.dart';

class ChatContextMessage {
  ChatContextMessage(this.content, this.action);

  String content;
  ContextActions action;
}
