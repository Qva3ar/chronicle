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
      'id': id,
      'text': text,
      'visibility': visibility ? 1 : 0,
    };
  }

  // Create an Instruction object from a Map
  factory Instruction.fromMap(Map<String, dynamic> map) {
    return Instruction(
      id: map['_id'],
      text: map['text'],
      visibility: map['visibility'] == 1,
    );
  }
}
