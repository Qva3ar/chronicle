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
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: double.infinity,
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
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Choose which notes to include based on their tags",
                style: TextStyle(
                  color: textMuted,
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
                    color: MyColors.orangeDivider.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MyColors.orangeDivider.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectAll ? Icons.check_box : Icons.check_box_outline_blank,
                        color: MyColors.orangeDivider,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Select All",
                        style: TextStyle(
                          color: textPrimary,
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
                          style: TextStyle(color: textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 6.0,
                          runSpacing: 0.0,
                          children: widget.availableTags.map((tag) {
                            final bool isSelected = selectedTagIds.contains(tag.id);

                            return ChoiceChip(
                              label: Text(
                                tag.name,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              selected: isSelected,
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: -2),
                              visualDensity: VisualDensity.compact,
                              side: isSelected
                                  ? BorderSide(width: 2, color: textPrimary)
                                  : BorderSide(width: 1, color: parseTagColor(tag.color).withAlpha(128)),
                              backgroundColor: parseTagColor(tag.color).withAlpha(100),
                              selectedColor: parseTagColor(tag.color),
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
                  color: surfaceElevated,
                  border: Border.all(color: cardBorder, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: textMuted, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${selectedTagIds.length} tag${selectedTagIds.length != 1 ? 's' : ''} selected",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          isLoadingCount
                              ? Text(
                                  "Counting notes...",
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 12,
                                  ),
                                )
                              : Text(
                                  selectedTagIds.isEmpty
                                      ? "No notes will be included"
                                      : "$noteCount note${noteCount != 1 ? 's' : ''} will be included in AI context",
                                  style: TextStyle(
                                    color: textMuted,
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
                      style: TextStyle(color: textMuted),
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
                      backgroundColor: MyColors.orangeDivider,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Confirm",
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
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
