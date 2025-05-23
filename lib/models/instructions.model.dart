import 'package:chrono/db_manager.dart';

class Instruction {
  int? id; // Auto-incremented id
  String text;
  bool visibility;

  Instruction({
    this.id,
    required this.text,
    required this.visibility,
  });

  // Convert the object to a Map
  Map<String, dynamic> toMap() {
    return {
      DatabaseColumns.id: id,
      DatabaseColumns.instructionText: text,
      DatabaseColumns.visibility: visibility ? 1 : 0,
    };
  }

  // Create an Instruction object from a Map
  factory Instruction.fromMap(Map<String, dynamic> map) {
    return Instruction(
      id: map[DatabaseColumns.id],
      text: map[DatabaseColumns.instructionText],
      visibility: map[DatabaseColumns.visibility] == 1,
    );
  }
}
