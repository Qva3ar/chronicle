import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/models/tag.dart';
import 'package:chrono/db_manager.dart';

/// Dialog for selecting multiple tags to include in AI context
class TagSelectionDialog extends StatefulWidget {
  final List<Tag> availableTags;
  final List<int> initialSelectedTagIds;

  const TagSelectionDialog({
    Key? key,
    required this.availableTags,
    required this.initialSelectedTagIds,
  }) : super(key: key);

  @override
  State<TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<TagSelectionDialog> {
  late Set<int> selectedTagIds;
  bool selectAll = false;
  int noteCount = 0;
  bool isLoadingCount = false;

  @override
  void initState() {
    super.initState();
    selectedTagIds = Set<int>.from(widget.initialSelectedTagIds);
    selectAll = selectedTagIds.length == widget.availableTags.length;
    _updateNoteCount();
  }

  Future<void> _updateNoteCount() async {
    if (selectedTagIds.isEmpty) {
      setState(() {
        noteCount = 0;
        isLoadingCount = false;
      });
      return;
    }

    setState(() {
      isLoadingCount = true;
    });

    try {
      final records = await DatabaseHelper.instance.getRecordsByMultipleTags(
        selectedTagIds.toList(),
      );
      setState(() {
        noteCount = records.length;
        isLoadingCount = false;
      });
    } catch (e) {
      setState(() {
        noteCount = 0;
        isLoadingCount = false;
      });
    }
  }

  void toggleTag(int tagId) {
    setState(() {
      if (selectedTagIds.contains(tagId)) {
        selectedTagIds.remove(tagId);
        selectAll = false;
      } else {
        selectedTagIds.add(tagId);
        if (selectedTagIds.length == widget.availableTags.length) {
          selectAll = true;
        }
      }
    });
    _updateNoteCount();
  }

  void toggleSelectAll() {
    setState(() {
      selectAll = !selectAll;
      if (selectAll) {
        selectedTagIds = Set<int>.from(widget.availableTags.map((tag) => tag.id));
      } else {
        selectedTagIds.clear();
      }
    });
    _updateNoteCount();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                "Select Tags for AI Context",
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Choose which notes to include based on their tags",
                style: TextStyle(
                  color: white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),

              // Select All option
              InkWell(
                onTap: toggleSelectAll,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: MyColors.primaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectAll ? Icons.check_box : Icons.check_box_outline_blank,
                        color: white,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Select All",
                        style: TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Tags list
              Flexible(
                child: widget.availableTags.isEmpty
                    ? Center(
                        child: Text(
                          "No tags available",
                          style: TextStyle(color: white.withOpacity(0.5)),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: widget.availableTags.map((tag) {
                            final bool isSelected = selectedTagIds.contains(tag.id);

                            return ChoiceChip(
                              label: Text(
                                tag.name,
                                style: TextStyle(
                                  color: white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              selected: isSelected,
                              side: isSelected
                                  ? BorderSide(width: 2, color: white)
                                  : null,
                              backgroundColor: Color(int.parse(tag.color!)),
                              onSelected: (bool selected) {
                                toggleTag(tag.id);
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),

              SizedBox(height: 16),

              // Selection count and note preview
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MyColors.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: white.withOpacity(0.7), size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${selectedTagIds.length} tag${selectedTagIds.length != 1 ? 's' : ''} selected",
                            style: TextStyle(
                              color: white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          isLoadingCount
                              ? Text(
                                  "Counting notes...",
                                  style: TextStyle(
                                    color: white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                )
                              : Text(
                                  selectedTagIds.isEmpty
                                      ? "No notes will be included"
                                      : "$noteCount note${noteCount != 1 ? 's' : ''} will be included in AI context",
                                  style: TextStyle(
                                    color: white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(null); // Return null to indicate cancellation
                    },
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: white.withOpacity(0.7)),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Return the selected tag IDs, or null if none selected
                      Navigator.of(context).pop(
                        selectedTagIds.isEmpty ? null : selectedTagIds.toList(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Confirm",
                      style: TextStyle(color: white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
