import 'package:flutter/material.dart';
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
      selectedColor = int.parse(widget.existingTag!.color!);
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
        await recordService.updateTag(
          widget.existingTag!.id,
          _tagNameController.text.trim(),
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
            content: Text('Error saving tag: $e'),
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
          const SnackBar(
            content: Text('System tags cannot be deleted'),
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
          title: "Tag deletion",
          message: "Are you sure you want to delete this tag?",
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
          isEditing ? 'Edit Tag' : 'Create Tag',
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
              const Text(
                'Tag Name',
                style: TextStyle(
                  color: white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
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
                  hintText: 'Enter tag name',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                controller: _tagNameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a tag name';
                  }
                  return null;
                },
                autofocus: !isEditing,
              ),
              const SizedBox(height: 24),
              const Text(
                'Tag Color',
                style: TextStyle(
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
                        isEditing ? 'Update' : 'Create',
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
                        child: const Text(
                          'Delete',
                          style: TextStyle(
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
