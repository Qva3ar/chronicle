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
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/services/locale_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        _mainIntentionText =
            rows.first[DatabaseColumns.settingMainIntentionText] as String? ??
                '';
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
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).settingsMainIntentionUpdated)),
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

  // ── Confirmation helper ──

  Future<bool?> _showConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = MyColors.remove,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: textPrimary, fontSize: 17)),
        content: Text(message, style: const TextStyle(color: textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel,
                style: const TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _resetRoutines() async {
    final l = AppLocalizations.of(context);
    final confirmed = await _showConfirmation(
      title: l.settingsResetRoutines,
      message: l.settingsResetRoutinesMessage,
      confirmLabel: l.commonReset,
      confirmColor: warningColor,
    );
    if (confirmed != true) return;

    try {
      final dbManager = DatabaseHelper.instance;
      final routineService = RoutineService(dbManager);
      final routines = await routineService.getAllRoutines();
      for (final routine in routines) {
        await routineService.resetRoutine(routine.id);
      }
      await _notificationService.checkAndRescheduleRoutines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).settingsRoutinesResetSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
              backgroundColor: MyColors.remove),
        );
      }
    }
  }

  Future<void> _resetGoals() async {
    final l = AppLocalizations.of(context);
    final confirmed = await _showConfirmation(
      title: l.settingsResetGoals,
      message: l.settingsResetGoalsMessage,
      confirmLabel: l.commonReset,
      confirmColor: warningColor,
    );
    if (confirmed != true) return;

    try {
      final goalService = GoalService(DatabaseHelper.instance);
      await goalService.resetAllGoals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).settingsGoalsResetSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
              backgroundColor: MyColors.remove),
        );
      }
    }
  }

  Future<void> _deleteAllGoals() async {
    final l = AppLocalizations.of(context);
    final confirmed = await _showConfirmation(
      title: l.settingsDeleteAllGoals,
      message: l.settingsDeleteAllGoalsMessage,
      confirmLabel: l.commonDelete,
    );
    if (confirmed != true) return;

    try {
      await DatabaseHelper.instance.deleteAllGoals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).settingsAllGoalsDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).errorWithMessage(e.toString()))),
        );
      }
    }
  }

  Future<void> _deleteAllRoutines() async {
    final l = AppLocalizations.of(context);
    final confirmed = await _showConfirmation(
      title: l.settingsDeleteAllRoutines,
      message: l.settingsDeleteAllRoutinesMessage,
      confirmLabel: l.commonDelete,
    );
    if (confirmed != true) return;

    try {
      List<Map<String, dynamic>> routines =
          await DatabaseHelper.instance.getAllRoutines();
      for (var routine in routines) {
        try {
          await _notificationService
              .cancelRoutineNotification(routine['_id']);
        } catch (e) {
          print(
              'Error canceling notification for routine ${routine['_id']}: $e');
        }
      }
      await DatabaseHelper.instance.deleteAllRoutines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).settingsAllRoutinesDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).errorWithMessage(e.toString()))),
        );
      }
    }
  }

  String _languageLabel(BuildContext context, Locale? locale) {
    final l = AppLocalizations.of(context);
    switch (locale?.languageCode) {
      case 'en':
        return l.languageEnglish;
      case 'ru':
        return l.languageRussian;
      default:
        return l.languageSystem;
    }
  }

  void _showLanguagePicker() {
    final l = AppLocalizations.of(context);
    final provider = context.read<LocaleProvider>();
    final current = provider.locale;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Widget option(String label, Locale? value) {
          final selected = current?.languageCode == value?.languageCode;
          return ListTile(
            title: Text(label, style: const TextStyle(color: textPrimary)),
            trailing: selected
                ? const Icon(Icons.check, color: MyColors.fivyColor)
                : null,
            onTap: () {
              provider.setLocale(value);
              Navigator.pop(sheetContext);
            },
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.language,
                  style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              option(l.languageSystem, null),
              option(l.languageEnglish, const Locale('en')),
              option(l.languageRussian, const Locale('ru')),
            ],
          ),
        );
      },
    );
  }

  void _showDangerZone() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              l.settingsDangerZone,
              style: const TextStyle(
                color: MyColors.remove,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.settingsDangerZoneDescription,
              style: const TextStyle(color: textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _DangerAction(
              icon: Icons.delete_outline,
              label: l.settingsDeleteAllGoals,
              onTap: () {
                Navigator.pop(context);
                _deleteAllGoals();
              },
            ),
            _DangerAction(
              icon: Icons.delete_outline,
              label: l.settingsDeleteAllRoutines,
              onTap: () {
                Navigator.pop(context);
                _deleteAllRoutines();
              },
            ),
            _DangerAction(
              icon: Icons.delete_forever,
              label: l.settingsDeleteAllRecords,
              subtitle: l.settingsDeleteAllRecordsSubtitle,
              onTap: () {
                Navigator.pop(context);
                _deleteAllRecords(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentLocale = context.watch<LocaleProvider>().locale;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title:
            Text(l.settingsTitle, style: const TextStyle(color: textPrimary)),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [

          // ── Language ──
          ChronoSettingsGroup(
            title: l.language,
            children: [
              ChronoSettingsRow(
                icon: Icons.language_rounded,
                iconColor: infoColor,
                label: l.language,
                subtitle: _languageLabel(context, currentLocale),
                onTap: _showLanguagePicker,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Backup & Restore ──
          ChronoSettingsGroup(
            title: l.settingsBackupRestore,
            children: [
              ChronoSettingsRow(
                icon: Icons.backup_rounded,
                iconColor: infoColor,
                label: l.settingsExportBackup,
                subtitle: l.settingsExportBackupSubtitle,
                onTap: _exportRecords,
              ),
              ChronoSettingsRow(
                icon: Icons.restore_rounded,
                iconColor: successColor,
                label: l.settingsImportBackup,
                subtitle: l.settingsImportBackupSubtitle,
                onTap: _importRecords,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Troubleshooting ──
          ChronoSettingsGroup(
            title: l.settingsTroubleshooting,
            children: [
              ChronoSettingsRow(
                icon: Icons.refresh_rounded,
                iconColor: warningColor,
                label: l.settingsResetRoutines,
                subtitle: l.settingsResetRoutinesSubtitle,
                onTap: _resetRoutines,
              ),
              ChronoSettingsRow(
                icon: Icons.restart_alt_rounded,
                iconColor: warningColor,
                label: l.settingsResetGoals,
                subtitle: l.settingsResetGoalsSubtitle,
                onTap: _resetGoals,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Danger Zone (single entry point) ──
          ChronoSettingsGroup(
            children: [
              ChronoSettingsRow(
                icon: Icons.warning_amber_rounded,
                iconColor: MyColors.remove,
                label: l.settingsDangerZone,
                subtitle: l.settingsDeleteDataPermanently,
                onTap: _showDangerZone,
              ),
            ],
          ),

          if (kDebugMode) ...[
            const SizedBox(height: 20),
            ChronoSettingsGroup(
              title: l.settingsDebug,
              children: [
                ChronoSettingsRow(
                  icon: Icons.bug_report_outlined,
                  iconColor: textMuted,
                  label: l.settingsPrintTags,
                  onTap: () async {
                    await DatabaseHelper.instance
                        .debugPrintTagsDumpToConsole();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text(AppLocalizations.of(context).settingsTagsPrinted),
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

class _DangerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _DangerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MyColors.remove.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: MyColors.remove),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: MyColors.remove,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: textMuted.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
