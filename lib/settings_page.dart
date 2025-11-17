import 'package:chrono/dialogs/confirmation-dialog.dart';
import 'package:chrono/dialogs/export_dialog.dart';
import 'package:chrono/import_notes.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/services/routine_service.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/onboarding/primary_goal_screen.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final NotificationService _notificationService = NotificationService();
  String _mainIntentionText = '';

  @override
  void initState() {
    super.initState();
    _loadMainIntention();
  }

  Future<void> _loadMainIntention() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.appSettings, limit: 1);
    if (rows.isNotEmpty && mounted) {
      setState(() {
        _mainIntentionText = rows.first[DatabaseColumns.settingMainIntentionText] as String? ?? '';
      });
    }
  }

  Future<void> _editMainIntention() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrimaryGoalScreen(),
      ),
    );
    if (result == true) {
      _loadMainIntention();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Main intention updated successfully')),
        );
      }
    }
  }

  Future<void> _importRecords() async {
    showDialog(
      context: context,
      builder: (context) => ImportNotesDialog(),
    );
  }

  Future<void> _exportRecords() async {
    showDialog(
      context: context,
      builder: (context) => ExportDialog(),
    );
  }

  Future<void> _deleteAllRecords(context) async {
    showDeleteConfirmationDialog(context);
  }

  Future<void> _deleteAllGoals() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete All Goals'),
          content: Text('Are you sure you want to delete all goals? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await DatabaseHelper.instance.deleteAllGoals();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('All goals deleted successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting goals: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete All', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllRoutines() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete All Routines'),
          content: Text(
              'Are you sure you want to delete all routines? This will also cancel all routine notifications. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // First get all routines to cancel their notifications
                  List<Map<String, dynamic>> routines =
                      await DatabaseHelper.instance.getAllRoutines();

                  // Cancel notifications for each routine
                  for (var routine in routines) {
                    try {
                      await _notificationService.cancelRoutineNotification(routine['_id']);
                    } catch (e) {
                      print('Error canceling notification for routine ${routine['_id']}: $e');
                    }
                  }

                  // Delete all routines from database
                  await DatabaseHelper.instance.deleteAllRoutines();

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('All routines deleted successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting routines: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete All', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetDailyData() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Routines & Goals'),
          content: Text(
              'Are you sure you want to reset all routines and goals for a new day? This will:\n\n'
              '• Mark all routines as not done\n'
              '• Reset all goal completion status\n'
              '• Reschedule all notifications\n\n'
              'This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final dbManager = DatabaseHelper.instance;
                  final routineService = RoutineService(dbManager);
                  final goalService = GoalService(dbManager);

                  // Reset all routines
                  final routines = await routineService.getAllRoutines();
                  for (final routine in routines) {
                    await routineService.resetRoutine(routine.id);
                  }

                  // Reset all goals
                  await goalService.resetAllGoals();

                  // Reschedule notifications
                  await _notificationService.checkAndRescheduleRoutines();

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Daily data reset successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error resetting daily data: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('Reset', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Records'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
                child: Column(
              children: [
                SizedBox(height: 100),
                ElevatedButton(
                  onPressed: _editMainIntention,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Edit Main Intention'),
                      if (_mainIntentionText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _mainIntentionText,
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 60),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _importRecords,
                  child: Text('Import Records'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _exportRecords,
                  child: Text('Export Records'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _deleteAllGoals,
                  child: Text('Delete All Goals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _deleteAllRoutines,
                  child: Text('Delete All Routines'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _resetDailyData,
                  child: Text('Reset Routines & Goals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 20),
              ],
            )),
            ElevatedButton(
              onPressed: () {
                _deleteAllRecords(context);
              },
              child: Text('Delete All Records'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
