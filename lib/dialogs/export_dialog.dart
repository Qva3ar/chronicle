import 'dart:io';
import 'package:chrono/colors.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/services/data-exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

class ExportDialog extends StatefulWidget {
  @override
  _ExportDialogState createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool _includeNotes = true;
  bool _includeRoutines = true;
  bool _includeGoals = true;
  bool _includeTodos = true;
  bool _includeInstructions = true;
  bool _includeWorkspaces = true;
  bool _isExporting = false;
  bool _exportCompleted = false;
  // Empty means "show the default localized prompt" (resolved in build with context).
  String _statusMessage = '';
  File? _exportedFile;

  bool get _hasSelection =>
      _includeNotes ||
      _includeRoutines ||
      _includeGoals ||
      _includeTodos ||
      _includeInstructions ||
      _includeWorkspaces;

  Future<void> _exportData() async {
    if (!_hasSelection) {
      setState(() {
        _statusMessage = AppLocalizations.of(context).exportSelectAtLeastOne;
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _statusMessage = AppLocalizations.of(context).exportExporting;
    });

    try {
      var dataExporter = DataExporter();
      File file = await dataExporter.exportData(
        includeNotes: _includeNotes,
        includeRoutines: _includeRoutines,
        includeGoals: _includeGoals,
        includeTodos: _includeTodos,
        includeInstructions: _includeInstructions,
        includeWorkspaces: _includeWorkspaces,
      );

      setState(() {
        _exportedFile = file;
        _exportCompleted = true;
        _statusMessage = AppLocalizations.of(context).exportReady;
      });
    } catch (e) {
      setState(() {
        _statusMessage =
            AppLocalizations.of(context).exportFailed(e.toString());
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _shareFile() async {
    if (_exportedFile == null) return;

    try {
      List<String> dataTypes = [];
      if (_includeNotes) dataTypes.add('notes');
      if (_includeRoutines) dataTypes.add('routines');
      if (_includeGoals) dataTypes.add('goals');
      if (_includeTodos) dataTypes.add('todos');
      if (_includeWorkspaces) dataTypes.add('workspaces');
      if (_includeInstructions) dataTypes.add('instructions');

      final l = AppLocalizations.of(context);
      final result = await Share.shareXFiles(
        [XFile(_exportedFile!.path)],
        subject: l.exportBackupSubject,
        text: l.exportBackupBody(dataTypes.join(', ')),
      );

      if (result.status == ShareResultStatus.success) {
        setState(() {
          _statusMessage = AppLocalizations.of(context).exportSharedSuccess;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            AppLocalizations.of(context).exportShareFailed(e.toString());
      });
    }
  }

  Future<void> _sendEmailWithAttachment() async {
    if (_exportedFile == null) return;

    try {
      List<String> dataTypes = [];
      if (_includeNotes) dataTypes.add('notes');
      if (_includeRoutines) dataTypes.add('routines');
      if (_includeGoals) dataTypes.add('goals');
      if (_includeTodos) dataTypes.add('todos');
      if (_includeWorkspaces) dataTypes.add('workspaces');
      if (_includeInstructions) dataTypes.add('instructions');

      final l = AppLocalizations.of(context);
      final Email email = Email(
        body: l.exportBackupBody(dataTypes.join(', ')),
        subject: l.exportBackupSubject,
        recipients: [],
        attachmentPaths: [_exportedFile!.path],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      setState(() {
        _statusMessage = AppLocalizations.of(context).exportEmailOpened;
      });
    } catch (e) {
      if (e.toString().contains('not_available') ||
          e.toString().contains('No email clients')) {
        setState(() {
          _statusMessage = AppLocalizations.of(context).exportNoEmailApp;
        });
      } else {
        setState(() {
          _statusMessage =
              AppLocalizations.of(context).exportEmailFailed(e.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: infoColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.backup_rounded,
                      size: 18, color: infoColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).exportTitle,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _statusMessage.isEmpty
                  ? AppLocalizations.of(context).exportSelectData
                  : _statusMessage,
              style: const TextStyle(
                color: textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            if (!_isExporting && !_exportCompleted) ...[
              // Checkboxes
              _ExportCheckbox(
                label: AppLocalizations.of(context).exportLabelNotes,
                icon: Icons.note_rounded,
                value: _includeNotes,
                onChanged: (v) => setState(() => _includeNotes = v ?? false),
              ),
              _ExportCheckbox(
                label: AppLocalizations.of(context).navRoutines,
                icon: Icons.schedule_rounded,
                value: _includeRoutines,
                onChanged: (v) => setState(() => _includeRoutines = v ?? false),
              ),
              _ExportCheckbox(
                label: AppLocalizations.of(context).navGoals,
                icon: Icons.track_changes_rounded,
                value: _includeGoals,
                onChanged: (v) => setState(() => _includeGoals = v ?? false),
              ),
              _ExportCheckbox(
                label: AppLocalizations.of(context).exportLabelTodos,
                icon: Icons.checklist_rounded,
                value: _includeTodos,
                onChanged: (v) => setState(() => _includeTodos = v ?? false),
              ),
              _ExportCheckbox(
                label: AppLocalizations.of(context).workspacesTitle,
                icon: Icons.workspaces_rounded,
                value: _includeWorkspaces,
                onChanged: (v) =>
                    setState(() => _includeWorkspaces = v ?? false),
              ),
              _ExportCheckbox(
                label: AppLocalizations.of(context).exportLabelInstructions,
                icon: Icons.psychology_rounded,
                value: _includeInstructions,
                onChanged: (v) =>
                    setState(() => _includeInstructions = v ?? false),
              ),
              const SizedBox(height: 16),

              // Export button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasSelection ? _exportData : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: infoColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: cardColor2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).exportCreateBackup,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).commonCancel,
                      style: const TextStyle(color: textMuted, fontSize: 13)),
                ),
              ),
            ],

            if (_isExporting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(infoColor),
                  ),
                ),
              ),

            if (_exportCompleted && !_isExporting) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sendEmailWithAttachment,
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: Text(AppLocalizations.of(context).exportEmailButton),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(
                            color: cardBorder.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareFile,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(AppLocalizations.of(context).exportShareButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: infoColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).commonDone,
                      style: const TextStyle(color: textMuted, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportCheckbox extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _ExportCheckbox({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: MyColors.orangeDivider,
                checkColor: Colors.black,
                side: BorderSide(color: textMuted, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 16, color: textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: value ? textPrimary : textSecondary,
                fontSize: 14,
                fontWeight: value ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
