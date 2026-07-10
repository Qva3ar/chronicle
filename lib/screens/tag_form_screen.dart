import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/record.service.dart';
import 'package:chrono/tag_color_picker.dart';
import 'package:chrono/models/tag.dart';
import 'package:chrono/shared/confirm-dialog.dart';

class TagFormScreen extends StatefulWidget {
  final Tag? existingTag;

  const TagFormScreen({Key? key, this.existingTag}) : super(key: key);

  @override
  State<TagFormScreen> createState() => _TagFormScreenState();
}

class _TagFormScreenState extends State<TagFormScreen> {
  final RecordService recordService = RecordService();
  final TextEditingController _tagNameController = TextEditingController();
  final formGlobalKey = GlobalKey<FormState>();

  int selectedColor = Colors.blue.value;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTag != null) {
      isEditing = true;
      _tagNameController.text = widget.existingTag!.name;
      selectedColor = int.tryParse(widget.existingTag!.color ?? "") ?? Colors.blue.value;
    }
  }

  @override
  void dispose() {
    _tagNameController.dispose();
    super.dispose();
  }

  void onColorSelected(Color color) {
    // Schedule the update for after the current frame to avoid setState during build
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            selectedColor = color.value;
          });
        }
      });
    }
  }

  Future<void> saveTag() async {
    if (!formGlobalKey.currentState!.validate()) {
      return;
    }

    try {
      if (isEditing && widget.existingTag != null) {
        // System tag name cannot be changed (only color)
        final nameToSave = widget.existingTag!.isSystem
            ? widget.existingTag!.name
            : _tagNameController.text.trim();
        await recordService.updateTag(
          widget.existingTag!.id,
          nameToSave,
          selectedColor,
        );
      } else {
        await recordService.insertTag(
          _tagNameController.text.trim(),
          selectedColor,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).tagErrorSaving(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> removeTag() async {
    if (widget.existingTag == null) return;

    // Check if tag is a system tag
    if (widget.existingTag!.isSystem) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).tagSystemCannotDelete),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: AppLocalizations.of(context).tagDeleteTitle,
          message: AppLocalizations.of(context).tagDeleteMessage,
          onConfirm: (confirmed) async {
            if (confirmed) {
              final success = await recordService.deleteTag(widget.existingTag!.id);
              if (mounted) {
                Navigator.pop(context, success);
              }
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.primaryColor,
      appBar: AppBar(
        backgroundColor: MyColors.primaryColor,
        title: Text(
          isEditing
              ? AppLocalizations.of(context).tagEditTitle
              : AppLocalizations.of(context).tagCreateTitle,
          style: const TextStyle(color: white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: formGlobalKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).tagNameLabel,
                style: const TextStyle(
                  color: white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                readOnly: widget.existingTag?.isSystem ?? false,
                style: const TextStyle(color: MyColors.secondaryColor),
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromARGB(255, 223, 234, 229),
                      width: 2.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: MyColors.forthyColor,
                      width: 1.0,
                    ),
                  ),
                  hintText: widget.existingTag?.isSystem ?? false
                      ? AppLocalizations.of(context).tagSystemNameCannotChange
                      : AppLocalizations.of(context).tagEnterName,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                controller: _tagNameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppLocalizations.of(context).tagNameRequired;
                  }
                  return null;
                },
                autofocus: !isEditing,
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).tagColorLabel,
                style: const TextStyle(
                  color: white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ColorPickerWidget(
                selected: widget.existingTag,
                onColorSelected: onColorSelected,
              ),
              const Spacer(),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MyColors.trecondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: saveTag,
                      child: Text(
                        isEditing
                            ? AppLocalizations.of(context).commonUpdate
                            : AppLocalizations.of(context).commonCreate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (isEditing && !(widget.existingTag?.isSystem ?? false)) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyColors.remove,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: removeTag,
                        child: Text(
                          AppLocalizations.of(context).commonDelete,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
