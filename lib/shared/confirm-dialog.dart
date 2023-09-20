import 'package:flutter/material.dart';
import 'package:flutter_crud/colors.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final Function(bool) onConfirm;

  ConfirmDialog(
      {required this.title, required this.message, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(""),
      actions: <Widget>[
        TextButton(
          child: Text(
            'Cancel',
            style: TextStyle(color: MyColors.secondaryColor),
          ),
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
            onConfirm(false); // Callback with false
          },
        ),
        TextButton(
          child: Text(
            'Confirm',
            style: TextStyle(color: MyColors.secondaryColor),
          ),
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
            onConfirm(true); // Callback with true
          },
        ),
      ],
    );
  }
}
