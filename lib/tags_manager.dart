// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:chrono/record.service.dart';

import 'colors.dart';
import 'db_manager.dart';
import 'models/tag.dart';
import 'package:chrono/screens/tag_form_screen.dart';

class TagsManager extends StatefulWidget {
  final void Function(int?) onTagSelected; //
  final int? selectedTag;

  const TagsManager({Key? key, this.selectedTag, required this.onTagSelected}) : super(key: key);

  @override
  _TagsManagerState createState() => _TagsManagerState();
}

class _TagsManagerState extends State<TagsManager> {
  RecordService recordService = RecordService();
  final dbHelper = DatabaseHelper.instance;

  final ScrollController _scrollController = ScrollController();

  int? selectedChipIndex;
  List<Tag> allTags = [];

  Future<void> getAllTags() async {
    List<Tag> tags = await recordService.queryAllTagsJust();
    setState(() {
      allTags = tags;
    });
  }

  Future<void> navigateToTagForm([Tag? tag]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TagFormScreen(existingTag: tag),
      ),
    );

    // Reload tags if a tag was created/updated/deleted
    if (result == true) {
      await getAllTags();
      // If a tag was deleted and it was selected, clear the selection
      if (tag != null && selectedChipIndex == tag.id) {
        setState(() {
          selectedChipIndex = null;
        });
        widget.onTagSelected(null);
      }
    }
  }

  Tag? getSelectedTag() {
    if (selectedChipIndex == null) return null;
    try {
      return allTags.firstWhere((tag) => tag.id == selectedChipIndex);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    selectedChipIndex = widget.selectedTag;
    super.initState();
    getAllTags();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTag = getSelectedTag();

    return Container(
      color: MyColors.secondaryColor,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Search by Tag",
                  style: TextStyle(
                    color: white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    // Edit button (only shown when tag is selected)
                    if (selectedTag != null)
                      IconButton(
                        icon: Icon(Icons.edit, color: white, size: 20),
                        onPressed: () => navigateToTagForm(selectedTag),
                        tooltip: 'Edit tag',
                      ),
                    // Create new tag button
                    IconButton(
                      icon: Icon(Icons.add, color: white, size: 24),
                      onPressed: () => navigateToTagForm(),
                      tooltip: 'Create new tag',
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            // Scrollable tags section
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: allTags.map((tag) {
                    final int id = tag.id;

                    return ChoiceChip(
                      label: Text(
                        tag.name,
                        style: TextStyle(
                          color: white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      selected: selectedChipIndex == id,
                      side: selectedChipIndex == id
                        ? BorderSide(width: 2, color: white)
                        : null,
                      backgroundColor: Color(int.parse(tag.color!)),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            widget.onTagSelected(id);
                            selectedChipIndex = id;
                          } else {
                            widget.onTagSelected(null);
                            selectedChipIndex = null;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            // Selected tag indicator at the bottom
            if (selectedTag != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MyColors.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(int.parse(selectedTag.color!)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Selected: ${selectedTag.name}',
                        style: TextStyle(
                          color: white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: white, size: 20),
                      onPressed: () {
                        setState(() {
                          selectedChipIndex = null;
                        });
                        widget.onTagSelected(null);
                      },
                      tooltip: 'Clear selection',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
