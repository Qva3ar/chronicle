import 'dart:convert';
import 'dart:io';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/models/todo.model.dart';
import 'package:chrono/models/todo_reminder.model.dart';
import 'package:chrono/models/instructions.model.dart';
import 'package:chrono/record.service.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

class ImportNotesDialog extends StatefulWidget {
  @override
  _ImportNotesDialogState createState() => _ImportNotesDialogState();
}

class _ImportNotesDialogState extends State<ImportNotesDialog> {
  bool _isLoading = false;
  String _statusMessage = "Press the button to import data.";
  RecordService dataController = RecordService();
  NotificationService _notificationService = NotificationService();

  Future<Map<String, int>> _getCurrentDataCounts() async {
    final db = DatabaseHelper.instance;

    final notesCount = await db.database.then((d) =>
      d.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.record}')
    ).then((result) => Sqflite.firstIntValue(result) ?? 0);

    final routinesCount = await db.database.then((d) =>
      d.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.routines}')
    ).then((result) => Sqflite.firstIntValue(result) ?? 0);

    final goalsCount = await db.database.then((d) =>
      d.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.goals}')
    ).then((result) => Sqflite.firstIntValue(result) ?? 0);

    final todosCount = await db.database.then((d) =>
      d.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.todos}')
    ).then((result) => Sqflite.firstIntValue(result) ?? 0);

    final tagsCount = await db.database.then((d) =>
      d.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.category}')
    ).then((result) => Sqflite.firstIntValue(result) ?? 0);

    return {
      'notes': notesCount,
      'routines': routinesCount,
      'goals': goalsCount,
      'todos': todosCount,
      'tags': tagsCount,
    };
  }

  Future<void> _importData() async {
    try {
      // Step 1: Pick file first
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        setState(() {
          _statusMessage = "No file selected.";
        });
        return;
      }

      File file = File(result.files.single.path!);
      String fileContent = await file.readAsString();
      Map<String, dynamic> importData = jsonDecode(fileContent);

      // Step 2: Get current data counts
      final currentCounts = await _getCurrentDataCounts();
      final totalCurrent = currentCounts.values.reduce((a, b) => a + b);

      // Step 3: Show confirmation dialog
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Replace All Data?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import will DELETE all current data and replace it with backup.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Current data to be deleted:'),
              SizedBox(height: 8),
              _buildDataRow('Notes', currentCounts['notes']!),
              _buildDataRow('Tags', currentCounts['tags']!),
              _buildDataRow('Routines', currentCounts['routines']!),
              _buildDataRow('Goals', currentCounts['goals']!),
              _buildDataRow('Todos', currentCounts['todos']!),
              Divider(),
              Text(
                'Total: $totalCurrent items will be deleted',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (totalCurrent > 0) ...[
                SizedBox(height: 16),
                Text(
                  '⚠️ Make sure you have a backup before proceeding!',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete & Import'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() {
          _statusMessage = "Import cancelled.";
        });
        return;
      }

      // Step 4: Proceed with import
      setState(() {
        _isLoading = true;
        _statusMessage = "Deleting current data...";
      });

      await _deleteAllData();

      setState(() {
        _statusMessage = "Importing...";
      });

        int importedItems = 0;

        // Maps to track old ID -> new ID for routines, goals, and todos
        Map<int, int> routineIdMap = {};
        Map<int, int> goalIdMap = {};
        Map<int, int> todoIdMap = {};

        // Import routines FIRST (before notes, so we can remap IDs)
        if (importData.containsKey('routines')) {
          setState(() {
            _statusMessage = "Importing routines...";
          });

          List<dynamic> routines = importData['routines'];
          for (var routineData in routines) {
            routineData = Map<String, dynamic>.from(routineData);

            // Store old ID before removing it
            int? oldRoutineId = routineData['_id'];
            routineData.remove('_id');

            // Insert routine and get new ID
            int newRoutineId = await DatabaseHelper.instance.insertRoutine(routineData);

            // Track the ID mapping
            if (oldRoutineId != null) {
              routineIdMap[oldRoutineId] = newRoutineId;
            }

            // Schedule notifications for the imported routine
            try {
              Routine routine = Routine.fromMap({...routineData, '_id': newRoutineId});
              DateTime nextOccurrence = routine.getNextOccurrence();
              await _notificationService.scheduleRoutineNotification(
                routineId: newRoutineId,
                routineName: routine.name,
                scheduledTime: nextOccurrence,
                periodAfter: routine.periodAfter,
                interval: routine.interval,
              );
            } catch (e) {
              print('Failed to schedule notification for routine ${routineData['name']}: $e');
            }
          }
          importedItems += routines.length;
        }

        // Import goals SECOND (before notes, so we can remap IDs)
        if (importData.containsKey('goals')) {
          setState(() {
            _statusMessage = "Importing goals...";
          });

          List<dynamic> goals = importData['goals'];
          for (var goalData in goals) {
            goalData = Map<String, dynamic>.from(goalData);

            // Store old ID before removing it
            int? oldGoalId = goalData['_id'];
            goalData.remove('_id');

            // Clear daily fields that should be reset (completedAt, timeSpent, session state)
            // This ensures imported goals start fresh for today
            goalData[DatabaseColumns.goalCompletedAt] = null;
            goalData[DatabaseColumns.goalTimeSpentSeconds] = 0;
            goalData[DatabaseColumns.goalIsActive] = 0;
            goalData[DatabaseColumns.goalSessionResumedTimestampSeconds] = null;

            // Insert goal and get new ID
            Goal goal = Goal.fromMap(goalData);
            int newGoalId = await DatabaseHelper.instance.insertGoal(goal);

            // Track the ID mapping
            if (oldGoalId != null) {
              goalIdMap[oldGoalId] = newGoalId;
            }
          }
          importedItems += goals.length;
          print('✅ Imported ${goals.length} goals with reset daily fields');
        }

        // Import todos THIRD (before todo_reminders and notes)
        if (importData.containsKey('todos')) {
          setState(() {
            _statusMessage = "Importing todos...";
          });

          List<dynamic> todos = importData['todos'];
          for (var todoData in todos) {
            todoData = Map<String, dynamic>.from(todoData);

            // Store old ID before removing it
            int? oldTodoId = todoData['_id'];
            todoData.remove('_id');

            // Insert todo and get new ID
            int newTodoId = await DatabaseHelper.instance.insertTodo(Todo.fromMap(todoData));

            // Track the ID mapping
            if (oldTodoId != null) {
              todoIdMap[oldTodoId] = newTodoId;
            }
          }
          importedItems += todos.length;
          print('✅ Imported ${todos.length} todos');
        }

        // Import todo reminders FOURTH (after todos, so we can remap todo IDs)
        if (importData.containsKey('todo_reminders')) {
          setState(() {
            _statusMessage = "Importing todo reminders...";
          });

          List<dynamic> reminders = importData['todo_reminders'];
          for (var reminderData in reminders) {
            reminderData = Map<String, dynamic>.from(reminderData);

            // Remove old ID
            reminderData.remove('_id');

            // Remap todo_id if it exists in our mapping
            if (reminderData.containsKey('todo_id') && reminderData['todo_id'] != null) {
              int oldTodoId = reminderData['todo_id'];
              if (todoIdMap.containsKey(oldTodoId)) {
                reminderData['todo_id'] = todoIdMap[oldTodoId];
              }
            }

            // Insert reminder
            await DatabaseHelper.instance.insertTodoReminder(TodoReminder.fromMap(reminderData));
          }
          importedItems += reminders.length;
          print('✅ Imported ${reminders.length} todo reminders');
        }

        // Import instructions (no ID remapping needed)
        if (importData.containsKey('instructions')) {
          setState(() {
            _statusMessage = "Importing instructions...";
          });

          List<dynamic> instructions = importData['instructions'];
          for (var instructionData in instructions) {
            instructionData = Map<String, dynamic>.from(instructionData);
            instructionData.remove('_id');
            await DatabaseHelper.instance.insertInstruction(Instruction.fromMap(instructionData));
          }
          importedItems += instructions.length;
          print('✅ Imported ${instructions.length} instructions');
        }

        // Import notes and tags LAST (so we can update routine_id and goal_id references)
        if (importData.containsKey('notes') || importData.containsKey('tags')) {
          setState(() {
            _statusMessage = "Importing notes and tags...";
          });

          // Update routine_id and goal_id in notes to use new IDs
          if (importData.containsKey('notes')) {
            List<dynamic> notes = importData['notes'];
            for (var note in notes) {
              if (note is Map<String, dynamic>) {
                // Remap routine_id if it exists
                if (note.containsKey('routine_id') && note['routine_id'] != null) {
                  int oldRoutineId = note['routine_id'];
                  if (routineIdMap.containsKey(oldRoutineId)) {
                    note['routine_id'] = routineIdMap[oldRoutineId];
                  }
                }
                // Remap goal_id if it exists
                if (note.containsKey('goal_id') && note['goal_id'] != null) {
                  int oldGoalId = note['goal_id'];
                  if (goalIdMap.containsKey(oldGoalId)) {
                    note['goal_id'] = goalIdMap[oldGoalId];
                  }
                }
              }
            }
          }

          // Create a filtered data object with only notes and tags for the importRecords method
          Map<String, dynamic> notesAndTagsData = {};
          if (importData.containsKey('notes')) {
            notesAndTagsData['notes'] = importData['notes'];
          }
          if (importData.containsKey('tags')) {
            notesAndTagsData['tags'] = importData['tags'];
          }

          await DatabaseHelper.instance.importRecords(notesAndTagsData);
          if (importData.containsKey('notes')) {
            importedItems += (importData['notes'] as List).length;
          }
          if (importData.containsKey('workspaces')) {
            final ws = importData['workspaces'];
            if (ws is List && ws.isNotEmpty) {
              setState(() {
                _statusMessage = "Importing workspaces...";
              });
              await DatabaseHelper.instance.importWorkspacesFromBackup(ws);
              importedItems += ws.length;
            }
          }
          dataController.importSuccess();
        }

        // Reset all goals to ensure they're ready for today
        // (in case any stale completedAt values slipped through)
        if (importData.containsKey('goals')) {
          final goalService = GoalService(DatabaseHelper.instance);
          await goalService.resetAllGoals();
          print('✅ Reset all goals after import to clear any stale completion states');
        }

        setState(() {
          _statusMessage = "Import successful! Imported $importedItems items.";
        });
    } catch (e) {
      setState(() {
        _statusMessage = "Import failed: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAllData() async {
    final db = await DatabaseHelper.instance.database;

    print('🗑️ Deleting all data before import...');

    await db.transaction((txn) async {
      // Delete in correct order (respecting foreign key constraints)
      await txn.delete(DatabaseTables.workspaceRecord);
      await txn.delete(DatabaseTables.workspace);
      await txn.delete(DatabaseTables.recordTag);
      await txn.delete(DatabaseTables.record);
      await txn.delete(DatabaseTables.category);
      await txn.delete(DatabaseTables.routines);
      await txn.delete(DatabaseTables.goals);
      await txn.delete(DatabaseTables.todoReminders);
      await txn.delete(DatabaseTables.todos);
      await txn.delete(DatabaseTables.instructions);
    });

    print('✅ All data deleted successfully');
  }

  Widget _buildDataRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('• $label:'),
          Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Import Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isLoading) CircularProgressIndicator() else Text(_statusMessage),
          SizedBox(height: 16),
          if (!_isLoading)
            Text(
              'Select a JSON backup file to import.\n\n⚠️ WARNING: Import will DELETE all current data and replace it with the backup.\n\nYou will see a confirmation screen before deletion.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
        ],
      ),
      actions: <Widget>[
        if (!_isLoading)
          TextButton(
            onPressed: _importData,
            child: Text('Select File & Import'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}
