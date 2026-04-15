import 'package:chrono/db_manager.dart';

class Instruction {
  int? id; // Auto-incremented id
  String text;
  bool visibility;
  bool autoSend; // true = send immediately, false = insert into input

  Instruction({
    this.id,
    required this.text,
    required this.visibility,
    this.autoSend = true,
  });

  // Convert the object to a Map
  Map<String, dynamic> toMap() {
    return {
      DatabaseColumns.id: id,
      DatabaseColumns.instructionText: text,
      DatabaseColumns.visibility: visibility ? 1 : 0,
      DatabaseColumns.instructionAutoSend: autoSend ? 1 : 0,
    };
  }

  // Create an Instruction object from a Map
  factory Instruction.fromMap(Map<String, dynamic> map) {
    return Instruction(
      id: map[DatabaseColumns.id],
      text: map[DatabaseColumns.instructionText],
      visibility: map[DatabaseColumns.visibility] == 1,
      autoSend: (map[DatabaseColumns.instructionAutoSend] ?? 1) == 1,
    );
  }
}
