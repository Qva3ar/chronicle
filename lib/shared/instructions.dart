import 'package:flutter_crud/models/record.dart';

class Instractions {
  static String useUserNoteText(String noteData) {
    return "This is my note. Use it for following requests: { $noteData }";
  }

  static String useUserAllNotes(List<Record> noteData) {
    if (noteData.isEmpty) {
      return "You don't have any notes yet.";
    }

    // Build a formatted string with all user notes
    final notesString = noteData.map((note) {
      return "Note ${note.id}:\nTitle: ${note.title}\nText: ${note.text}\nCreated At: ${note.createdAt}\n\n";
    }).join('\n');

    return "Here are my notes: \n$notesString \nYou can refer to these notes for your answer.";
  }

  static String findRecords() {
    return "If user asks to find specific notes, that is given for you before, find them and give the record IDs. Desired Format: Found:[<comma_separated_list_of_ids>]";
  }
}
