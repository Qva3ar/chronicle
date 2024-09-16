import 'package:flutter/material.dart';
import 'package:Chrono/colors.dart';
import 'package:Chrono/models/tag.dart';
import 'package:Chrono/tag_color_picker.dart';

class TagsEditWidget extends StatelessWidget {
  final TextEditingController controller;
  final Tag? selectedTag;
  final Function(Color) onColorSelected;
  final VoidCallback onSave;
  final VoidCallback onRemove;
  final GlobalKey<FormState> formKey;

  TagsEditWidget({
    required this.controller,
    required this.selectedTag,
    required this.onColorSelected,
    required this.onSave,
    required this.onRemove,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(
                fillColor: Colors.white,
                filled: true,
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: const Color.fromARGB(255, 223, 234, 229), width: 2.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: MyColors.primaryColor, width: 1.0),
                ),
                hintText: 'Tag Name',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              ),
              controller: controller,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Write Tag name';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ColorPickerWidget(selected: selectedTag, onColorSelected: onColorSelected),
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(MyColors.trecondaryColor),
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        onSave();
                      }
                    },
                    child: Text(
                      "Save",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                selectedTag != null
                    ? TextButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all<Color>(MyColors.remove),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            onRemove();
                          }
                        },
                        child: Text(
                          "Remove",
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : Container(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
