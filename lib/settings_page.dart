import 'dart:io';

import 'package:Chrono/dialogs/confirmation-dialog.dart';
import 'package:Chrono/import_notes.dart';
import 'package:Chrono/services/data-exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _importRecords() async {
    showDialog(
      context: context,
      builder: (context) => ImportNotesDialog(),
    );
  }

  Future<void> _exportRecords() async {
    var dataExporter = DataExporter();
    File file = await dataExporter.exportData();
    await sendEmailWithAttachment(file);
  }

  Future<void> _deleteAllRecords(context) async {
    showDeleteConfirmationDialog(context);
  }

  Future<void> sendEmailWithAttachment(File file) async {
    final Email email = Email(
      body: 'Here is the backup of all notes and tags.',
      subject: 'Backup of Notes',
      recipients: [], // Optionally add default recipient email addresses
      attachmentPaths: [file.path],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
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
