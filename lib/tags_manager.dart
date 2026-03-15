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

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MyColors.forthyColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Search by Tag",
                  style: TextStyle(
                    color: white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (selectedTag != null)
                      IconButton(
                        icon: Icon(Icons.edit, color: white, size: 20),
                        onPressed: () => navigateToTagForm(selectedTag),
                        tooltip: 'Edit tag',
                      ),
                    IconButton(
                      icon: Icon(Icons.add, color: white, size: 24),
                      onPressed: () => navigateToTagForm(),
                      tooltip: 'Create new tag',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: white),
              decoration: InputDecoration(
                hintText: 'Search tags...',
                hintStyle: TextStyle(color: white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: white),
                filled: true,
                fillColor: white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: filteredTags.map((tag) {
                  final int id = tag.id;

                  return ChoiceChip(
                    label: Text(
                      tag.name,
                      style: const TextStyle(
                        color: white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: selectedChipIndex == id,
                    side: selectedChipIndex == id ? const BorderSide(width: 2, color: white) : null,
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
          if (selectedTag != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Selected: ${selectedTag.name}',
                        style: const TextStyle(
                          color: white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: white, size: 20),
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
            ),
        ],
      ),
    );
  }
}
