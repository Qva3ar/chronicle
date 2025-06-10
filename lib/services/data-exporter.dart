import 'dart:convert';
import 'dart:io';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:path_provider/path_provider.dart';

class DataExporter {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<File> exportData({
    bool includeNotes = true,
    bool includeRoutines = false,
    bool includeGoals = false,
  }) async {
    Map<String, dynamic> exportData = {};

    if (includeNotes) {
      List<Map<String, dynamic>> notes = await _dbHelper.fetchAllNotes();
      List<Map<String, dynamic>> tags = await _dbHelper.queryAllRows();
      exportData['notes'] = notes;
      exportData['tags'] = tags;
    }

    if (includeRoutines) {
      List<Map<String, dynamic>> routines = await _dbHelper.getAllRoutines();
      exportData['routines'] = routines;
    }

    if (includeGoals) {
      List<Goal> goals = await _dbHelper.getAllGoals();
      exportData['goals'] = goals.map((goal) => goal.toMap()).toList();
    }

    var exportDataJson = jsonEncode(exportData);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/chrono_backup.json');
    await file.writeAsString(exportDataJson);
    return file;
  }
}
