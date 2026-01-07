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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTag = getSelectedTag();
    final filteredTags = allTags
        .where((tag) => tag.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.max,
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
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: filteredTags.map((tag) {
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
                        side: selectedChipIndex == id ? BorderSide(width: 2, color: white) : null,
                        backgroundColor: Color(int.tryParse(tag.color ?? "") ?? 0xFFFFFFFF),
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
              SizedBox(height: 12),
              // Search Input
              TextField(
                controller: _searchController,
                style: TextStyle(color: white),
                decoration: InputDecoration(
                  hintText: 'Search tags...',
                  hintStyle: TextStyle(color: white.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: white),
                  filled: true,
                  fillColor: white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
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
                          color: Color(int.tryParse(selectedTag.color ?? "") ?? 0xFFFFFFFF),
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
      ),
    );
  }
}
