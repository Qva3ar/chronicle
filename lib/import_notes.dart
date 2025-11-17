import 'dart:convert';
import 'dart:io';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/record.service.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ImportNotesDialog extends StatefulWidget {
  @override
  _ImportNotesDialogState createState() => _ImportNotesDialogState();
}

class _ImportNotesDialogState extends State<ImportNotesDialog> {
  bool _isLoading = false;
  String _statusMessage = "Press the button to import data.";
  RecordService dataController = RecordService();
  NotificationService _notificationService = NotificationService();

  Future<void> _importData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Importing...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileContent = await file.readAsString();
        Map<String, dynamic> importData = jsonDecode(fileContent);

        int importedItems = 0;

        // Maps to track old ID -> new ID for routines and goals
        Map<int, int> routineIdMap = {};
        Map<int, int> goalIdMap = {};

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

            // Insert goal and get new ID
            Goal goal = Goal.fromMap(goalData);
            int newGoalId = await DatabaseHelper.instance.insertGoal(goal);

            // Track the ID mapping
            if (oldGoalId != null) {
              goalIdMap[oldGoalId] = newGoalId;
            }
          }
          importedItems += goals.length;
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
          dataController.importSuccess();
        }

        setState(() {
          _statusMessage = "Import successful! Imported $importedItems items.";
        });
      } else {
        setState(() {
          _statusMessage = "No file selected.";
        });
      }
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
              'Select a JSON backup file to import notes, routines, and goals.\n\nRoutines will be automatically activated with notifications.',
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
