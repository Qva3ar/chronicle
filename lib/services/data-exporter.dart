import 'dart:convert';
import 'dart:io';

import 'package:Chrono/core/db/db_manager.dart';
import 'package:path_provider/path_provider.dart';

class DataExporter {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<File> exportData() async {
    List<Map<String, dynamic>> notes = await _dbHelper.fetchAllNotes();
    List<Map<String, dynamic>> tags = await _dbHelper.queryAllRows();

    var exportData = jsonEncode({
      'notes': notes,
      'tags': tags,
    });

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/notes_backup.json');
    await file.writeAsString(exportData);
    return file;
  }
}
