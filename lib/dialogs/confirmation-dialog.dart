import 'package:chrono/db_manager.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/record.service.dart';
import 'package:flutter/material.dart';

Future<void> showDeleteConfirmationDialog(BuildContext context) async {
  RecordService recordService = RecordService();
  // Display the confirmation dialog
  bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            final l = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(l.confirmDeleteTitle),
              content: Text(l.confirmDeleteAllMessage),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pop(false); // Dismisses the dialog and returns false
                  },
                  child: Text(l.commonCancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pop(true); // Dismisses the dialog and returns true
                  },
                  child: Text(l.commonDelete),
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).allNotesDeleted)));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)
              .failedToDeleteNotes(error.toString()))));
    }
  }
}
