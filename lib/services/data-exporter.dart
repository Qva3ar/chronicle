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
    bool includeTodos = true,
    bool includeInstructions = true,
    bool includeWorkspaces = true,
  }) async {
    Map<String, dynamic> exportData = {};

    if (includeNotes) {
      List<Map<String, dynamic>> notes = await _dbHelper.fetchAllNotes();
      List<Map<String, dynamic>> tags = await _dbHelper.queryAllRows();
      exportData['notes'] = notes;
      exportData['tags'] = tags;
    }

    if (includeWorkspaces) {
      final workspaces = await _dbHelper.fetchAllWorkspacesForExport();
      if (workspaces.isNotEmpty) {
        exportData['workspaces'] = workspaces;
      }
    }

    if (includeRoutines) {
      List<Map<String, dynamic>> routines = await _dbHelper.getAllRoutines();
      // Reset routine state: set is_done to false and clear lastCompletedDate
      exportData['routines'] = routines.map((routine) {
        return {
          ...routine,
          'is_done': 0, // false in SQLite
          'last_completed_date': null,
        };
      }).toList();
    }

    if (includeGoals) {
      List<Goal> goals = await _dbHelper.getAllGoals();
      // Reset goal state to initial values (excluding daily state)
      exportData['goals'] = goals.map((goal) {
        return goal
            .copyWith(
              isActive: false,
              timeSpentSeconds: 0,
              completedAt: null,
              clearSessionResumedTimestamp: true,
            )
            .toMap();
      }).toList();
    }

    if (includeTodos) {
      var todos = await _dbHelper.getAllTodos();
      // Export todos with their structure
      exportData['todos'] = todos.map((todo) => todo.toMap()).toList();

      // Export todo reminders for all todos
      List<Map<String, dynamic>> allReminders = [];
      for (var todo in todos) {
        if (todo.id != null) {
          var reminders = await _dbHelper.getTodoReminders(todo.id!);
          allReminders.addAll(reminders.map((r) => r.toMap()).toList());
        }
      }
      if (allReminders.isNotEmpty) {
        exportData['todo_reminders'] = allReminders;
      }
    }

    if (includeInstructions) {
      var instructions = await _dbHelper.queryAllInstructions();
      if (instructions.isNotEmpty) {
        exportData['instructions'] = instructions.map((i) => i.toMap()).toList();
      }
    }

    var exportDataJson = jsonEncode(exportData);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/chrono_backup.json');
    await file.writeAsString(exportDataJson);
    return file;
  }
}
