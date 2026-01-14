import 'dart:io';
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
  bool _isExporting = false;
  bool _exportCompleted = false;
  String _statusMessage = "Select data to export";
  File? _exportedFile;

  Future<void> _exportData() async {
    if (!_includeNotes && !_includeRoutines && !_includeGoals && !_includeTodos && !_includeInstructions) {
      setState(() {
        _statusMessage = "Please select at least one data type to export.";
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _statusMessage = "Exporting data...";
    });

    try {
      var dataExporter = DataExporter();
      File file = await dataExporter.exportData(
        includeNotes: _includeNotes,
        includeRoutines: _includeRoutines,
        includeGoals: _includeGoals,
        includeTodos: _includeTodos,
        includeInstructions: _includeInstructions,
      );

      setState(() {
        _exportedFile = file;
        _exportCompleted = true;
        _statusMessage = "Export completed! Choose how to share your backup.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Export failed: ${e.toString()}";
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
      if (_includeInstructions) dataTypes.add('instructions');

      final result = await Share.shareXFiles(
        [XFile(_exportedFile!.path)],
        subject: 'Chrono Data Backup',
        text: 'Here is the backup of your Chrono data including: ${dataTypes.join(', ')}.',
      );

      if (result.status == ShareResultStatus.success) {
        setState(() {
          _statusMessage = "Backup shared successfully!";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Share failed: ${e.toString()}";
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
      if (_includeInstructions) dataTypes.add('instructions');

      final Email email = Email(
        body: 'Here is the backup of your Chrono data including: ${dataTypes.join(', ')}.',
        subject: 'Chrono Data Backup',
        recipients: [],
        attachmentPaths: [_exportedFile!.path],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      setState(() {
        _statusMessage = "Email composer opened!";
      });
    } catch (e) {
      // Handle "no email client" error gracefully
      if (e.toString().contains('not_available') || e.toString().contains('No email clients')) {
        setState(() {
          _statusMessage = "No email app found. Please use 'Share' instead.";
        });
      } else {
        setState(() {
          _statusMessage = "Email failed: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Export Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusMessage),
          SizedBox(height: 16),
          if (!_isExporting && !_exportCompleted) ...[
            Text(
              'Select data to export:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            CheckboxListTile(
              title: Text('Notes & Tags'),
              subtitle: Text('All your notes and tags'),
              value: _includeNotes,
              onChanged: (bool? value) {
                setState(() {
                  _includeNotes = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: Text('Routines'),
              subtitle: Text('Your daily routines and reminders'),
              value: _includeRoutines,
              onChanged: (bool? value) {
                setState(() {
                  _includeRoutines = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: Text('Goals'),
              subtitle: Text('Your time-tracking goals'),
              value: _includeGoals,
              onChanged: (bool? value) {
                setState(() {
                  _includeGoals = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: Text('Todos'),
              subtitle: Text('Your todo list and reminders'),
              value: _includeTodos,
              onChanged: (bool? value) {
                setState(() {
                  _includeTodos = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: Text('Instructions'),
              subtitle: Text('Your GPT instructions'),
              value: _includeInstructions,
              onChanged: (bool? value) {
                setState(() {
                  _includeInstructions = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          if (_isExporting) Center(child: CircularProgressIndicator()),
          if (_exportCompleted && !_isExporting) ...[
            SizedBox(height: 8),
            Text(
              'Backup created successfully!',
              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isExporting && !_exportCompleted) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _exportData,
            child: Text('Export'),
          ),
        ],
        if (_exportCompleted && !_isExporting) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: _sendEmailWithAttachment,
            icon: Icon(Icons.email),
            label: Text('Email'),
          ),
          ElevatedButton.icon(
            onPressed: _shareFile,
            icon: Icon(Icons.share),
            label: Text('Share'),
          ),
        ],
        if (_isExporting)
          TextButton(
            onPressed: null,
            child: Text('Please wait...'),
          ),
      ],
    );
  }
}
