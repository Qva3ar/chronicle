import 'dart:convert';
import 'dart:io';
import 'package:Chrono/db_manager.dart';
import 'package:Chrono/record.service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ImportNotesDialog extends StatefulWidget {
  @override
  _ImportNotesDialogState createState() => _ImportNotesDialogState();
}

class _ImportNotesDialogState extends State<ImportNotesDialog> {
  bool _isLoading = false;
  String _statusMessage = "Press the button to import notes.";
  RecordService dataController = RecordService();

  Future<void> _importNotes() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Importing...";
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileContent = await file.readAsString();
      var records = jsonDecode(fileContent);
      // Implement your own logic to process and store these records
      // For example, using a method from your DatabaseHelper

      // Assuming DatabaseHelper is set up to handle batch inserts
      await DatabaseHelper().importRecords(records);

      setState(() {
        _statusMessage = "Import successful!";
      });
      dataController.importSuccess();
    } else {
      setState(() {
        _statusMessage = "No file selected.";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Import Notes'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isLoading) CircularProgressIndicator() else Text(_statusMessage),
        ],
      ),
      actions: <Widget>[
        if (!_isLoading)
          TextButton(
            onPressed: _importNotes,
            child: Text('Import'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}
