import 'package:chrono/dialogs/confirmation-dialog.dart';
import 'package:chrono/dialogs/export_dialog.dart';
import 'package:chrono/import_notes.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/services/routine_service.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/onboarding/primary_goal_screen.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/shared/chrono_ui.dart';
import 'package:flutter/foundation.dart';
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
          backgroundColor: cardColor,
          title: const Text('Delete All Goals', style: TextStyle(color: textPrimary)),
          content: const Text('Are you sure you want to delete all goals? This action cannot be undone.',
              style: TextStyle(color: textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await DatabaseHelper.instance.deleteAllGoals();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All goals deleted successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting goals: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: MyColors.remove),
              child: const Text('Delete All', style: TextStyle(color: Colors.white)),
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
          backgroundColor: cardColor,
          title: const Text('Delete All Routines', style: TextStyle(color: textPrimary)),
          content: const Text(
              'Are you sure you want to delete all routines? This will also cancel all routine notifications. This action cannot be undone.',
              style: TextStyle(color: textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  List<Map<String, dynamic>> routines =
                      await DatabaseHelper.instance.getAllRoutines();
                  for (var routine in routines) {
                    try {
                      await _notificationService.cancelRoutineNotification(routine['_id']);
                    } catch (e) {
                      print('Error canceling notification for routine ${routine['_id']}: $e');
                    }
                  }
                  await DatabaseHelper.instance.deleteAllRoutines();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All routines deleted successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting routines: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: MyColors.remove),
              child: const Text('Delete All', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetRoutines() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text('Reset Routines', style: TextStyle(color: textPrimary)),
          content: const Text(
              'Are you sure you want to reset all routines? This will:\n\n'
              '• Mark all routines as not done\n'
              '• Reschedule all notifications\n\n'
              'This action cannot be undone.',
              style: TextStyle(color: textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final dbManager = DatabaseHelper.instance;
                  final routineService = RoutineService(dbManager);
                  final routines = await routineService.getAllRoutines();
                  for (final routine in routines) {
                    await routineService.resetRoutine(routine.id);
                  }
                  await _notificationService.checkAndRescheduleRoutines();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Routines reset successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error resetting routines: $e'), backgroundColor: MyColors.remove),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: warningColor),
              child: const Text('Reset', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetGoals() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text('Reset Goals', style: TextStyle(color: textPrimary)),
          content: const Text(
              'Are you sure you want to reset all goals? This will:\n\n'
              '• Reset all goal completion status\n'
              '• Reset time spent to 0\n'
              '• Stop all active sessions\n\n'
              'This action cannot be undone.',
              style: TextStyle(color: textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final dbManager = DatabaseHelper.instance;
                  final goalService = GoalService(dbManager);
                  await goalService.resetAllGoals();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goals reset successfully')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error resetting goals: $e'), backgroundColor: MyColors.remove),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: infoColor),
              child: const Text('Reset', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text('Settings', style: TextStyle(color: textPrimary)),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Main Intention ──
          ChronoSettingsGroup(
            title: 'Main Intention',
            children: [
              ChronoSettingsRow(
                icon: Icons.flag_rounded,
                iconColor: Colors.purple,
                label: 'Edit Main Intention',
                subtitle: _mainIntentionText.isNotEmpty ? _mainIntentionText : null,
                onTap: _editMainIntention,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Data ──
          ChronoSettingsGroup(
            title: 'Data',
            children: [
              ChronoSettingsRow(
                icon: Icons.file_download_outlined,
                iconColor: infoColor,
                label: 'Import Records',
                onTap: _importRecords,
              ),
              ChronoSettingsRow(
                icon: Icons.file_upload_outlined,
                iconColor: infoColor,
                label: 'Export Records',
                onTap: _exportRecords,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Reset ──
          ChronoSettingsGroup(
            title: 'Reset',
            children: [
              ChronoSettingsRow(
                icon: Icons.refresh,
                iconColor: warningColor,
                label: 'Reset Routines',
                subtitle: 'Mark all as not done, reschedule notifications',
                onTap: _resetRoutines,
              ),
              ChronoSettingsRow(
                icon: Icons.restart_alt,
                iconColor: infoColor,
                label: 'Reset Goals',
                subtitle: 'Reset completion status and time spent',
                onTap: _resetGoals,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Danger Zone ──
          ChronoSettingsGroup(
            title: 'Danger Zone',
            children: [
              ChronoSettingsRow(
                icon: Icons.delete_outline,
                iconColor: warningColor,
                label: 'Delete All Goals',
                onTap: _deleteAllGoals,
              ),
              ChronoSettingsRow(
                icon: Icons.delete_outline,
                iconColor: warningColor,
                label: 'Delete All Routines',
                onTap: _deleteAllRoutines,
              ),
              ChronoSettingsRow(
                icon: Icons.delete_forever,
                iconColor: MyColors.remove,
                label: 'Delete All Records',
                subtitle: 'This cannot be undone',
                onTap: () => _deleteAllRecords(context),
              ),
            ],
          ),

          if (kDebugMode) ...[
            const SizedBox(height: 20),
            ChronoSettingsGroup(
              title: 'Debug',
              children: [
                ChronoSettingsRow(
                  icon: Icons.bug_report_outlined,
                  iconColor: textMuted,
                  label: 'Print Tags to Console',
                  onTap: () async {
                    await DatabaseHelper.instance.debugPrintTagsDumpToConsole();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tags printed to debug console (flutter run / Logcat)'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
