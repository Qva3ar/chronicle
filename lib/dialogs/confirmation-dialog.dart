import 'package:Chrono/db_manager.dart';
import 'package:Chrono/record.service.dart';
import 'package:flutter/material.dart';

Future<void> showDeleteConfirmationDialog(BuildContext context) async {
  RecordService recordService = RecordService();
  // Display the confirmation dialog
  bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm Delete'),
              content:
                  Text('Are you sure you want to delete all notes? This action cannot be undone.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Dismisses the dialog and returns false
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // Dismisses the dialog and returns true
                  },
                  child: Text('Delete'),
                ),
              ],
            );
          }) ??
      false; // Handle null (e.g., if the dialog is dismissed via tapping outside)

  // If the user confirms, proceed to delete all notes
  if (confirm) {
    try {
      await DatabaseHelper.instance.deleteAllNotes();
      recordService.importSuccess();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('All notes have been deleted successfully.')));
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete notes: $error')));
    }
  }
}
