import 'dart:io';
import 'package:chrono/services/data-exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class ExportDialog extends StatefulWidget {
  @override
  _ExportDialogState createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool _includeNotes = true;
  bool _includeRoutines = true;
  bool _includeGoals = true;
  bool _isExporting = false;
  String _statusMessage = "Select data to export";

  Future<void> _exportData() async {
    if (!_includeNotes && !_includeRoutines && !_includeGoals) {
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
      );

      await _sendEmailWithAttachment(file);

      setState(() {
        _statusMessage = "Export completed and email sent!";
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

  Future<void> _sendEmailWithAttachment(File file) async {
    List<String> dataTypes = [];
    if (_includeNotes) dataTypes.add('notes');
    if (_includeRoutines) dataTypes.add('routines');
    if (_includeGoals) dataTypes.add('goals');

    final Email email = Email(
      body: 'Here is the backup of your Chrono data including: ${dataTypes.join(', ')}.',
      subject: 'Chrono Data Backup',
      recipients: [],
      attachmentPaths: [file.path],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
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
          if (!_isExporting) ...[
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
          ],
          if (_isExporting) Center(child: CircularProgressIndicator()),
        ],
      ),
      actions: [
        if (!_isExporting) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _exportData,
            child: Text('Export'),
          ),
        ] else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
      ],
    );
  }
}
