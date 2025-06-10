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

        // Import notes and tags
        if (importData.containsKey('notes') || importData.containsKey('tags')) {
          setState(() {
            _statusMessage = "Importing notes and tags...";
          });

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

        // Import routines
        if (importData.containsKey('routines')) {
          setState(() {
            _statusMessage = "Importing routines...";
          });

          List<dynamic> routines = importData['routines'];
          for (var routineData in routines) {
            // Remove the id to allow auto-increment
            routineData = Map<String, dynamic>.from(routineData);
            routineData.remove('_id');

            int routineId = await DatabaseHelper.instance.insertRoutine(routineData);

            // Schedule notifications for the imported routine
            try {
              Routine routine = Routine.fromMap({...routineData, '_id': routineId});
              DateTime nextOccurrence = routine.getNextOccurrence();
              await _notificationService.scheduleRoutineNotification(
                routineId: routineId,
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

        // Import goals
        if (importData.containsKey('goals')) {
          setState(() {
            _statusMessage = "Importing goals...";
          });

          List<dynamic> goals = importData['goals'];
          for (var goalData in goals) {
            // Remove the id to allow auto-increment and create Goal object
            goalData = Map<String, dynamic>.from(goalData);
            goalData.remove('_id');

            Goal goal = Goal.fromMap(goalData);
            await DatabaseHelper.instance.insertGoal(goal);
          }
          importedItems += goals.length;
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
