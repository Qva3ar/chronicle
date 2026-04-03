// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:chrono/record.service.dart';

import 'colors.dart';
import 'db_manager.dart';
import 'models/tag.dart';
import 'package:chrono/screens/tag_form_screen.dart';
import 'package:chrono/shared/chrono_ui.dart';

class TagsManager extends StatefulWidget {
  final void Function(int?) onTagSelected; //
  final int? selectedTag;

  /// When set (e.g. inside [DraggableScrollableSheet]), list scroll is linked to sheet drag.
  final ScrollController? sheetScrollController;

  /// When set, the sheet is expanded to [searchExpandSize] when the search field is focused.
  final DraggableScrollableController? sheetDragController;

  /// Fraction to expand the sheet to when search is focused (default 0.92).
  final double searchExpandSize;

  const TagsManager({
    Key? key,
    this.selectedTag,
    required this.onTagSelected,
    this.sheetScrollController,
    this.sheetDragController,
    this.searchExpandSize = 0.92,
  }) : super(key: key);

  @override
  _TagsManagerState createState() => _TagsManagerState();
}

class _TagsManagerState extends State<TagsManager> {
  RecordService recordService = RecordService();
  final dbHelper = DatabaseHelper.instance;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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

    if (result == true) {
      await getAllTags();
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
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _onSearchFocusChange() {
    final ctrl = widget.sheetDragController;
    if (ctrl == null || !ctrl.isAttached) return;
    if (_searchFocusNode.hasFocus) {
      ctrl.animateTo(
        widget.searchExpandSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    final selectedTag = getSelectedTag();
    return ChronoSheetHeader(
      title: 'Tags',
      titleIcon: Icons.grid_view_rounded,
      itemCount: allTags.length,
      actions: [
        if (selectedTag != null)
          IconButton(
            icon: Icon(Icons.edit, color: textPrimary, size: 20),
            onPressed: () => navigateToTagForm(selectedTag),
            tooltip: 'Edit tag',
          ),
        IconButton(
          icon: const Icon(Icons.add, color: textPrimary),
          onPressed: () => navigateToTagForm(),
          tooltip: 'Create new tag',
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(color: white),
        decoration: InputDecoration(
          hintText: 'Search tags...',
          hintStyle: TextStyle(color: white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: white),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: white.withOpacity(0.7), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
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
    );
  }

  Widget _buildTagChips(List<Tag> tags) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: tags.map((tag) {
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
            // Dismiss keyboard after selecting a tag
            _searchFocusNode.unfocus();
          },
        );
      }).toList(),
    );
  }

  Widget _buildSelectedTagBar() {
    final selectedTag = getSelectedTag();
    if (selectedTag == null) return const SizedBox.shrink();
    return Padding(
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
    );
  }

  /// Panel that floats above the search bar (via Stack) when the user is typing.
  Widget _buildSearchResultsPanel(List<Tag> filteredTags) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 130),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: white.withOpacity(0.08))),
      ),
      child: filteredTags.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'No tags found',
                style: TextStyle(color: white.withOpacity(0.45), fontSize: 14),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: _buildTagChips(filteredTags),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isSearching = _searchQuery.isNotEmpty;

    final filteredTags = isSearching
        ? allTags.where((tag) => tag.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList()
        : <Tag>[];

    final sheetCtrl = widget.sheetScrollController;
    final scrollCtrl = sheetCtrl ?? _scrollController;

    // Height reserved by the bottom bar (results panel + search field + paddings)
    const resultsPanelMaxHeight = 130.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // constraints.maxHeight here is the *current* sheet display height
        // (= fraction × scaffoldBodyHeight), not the max possible height.
        // Recover the actual scaffold body height by dividing by the current fraction.
        // Then compute the true keyboard overlap with the sheet:
        //   overlap = keyboardHeight - (screenHeight - scaffoldBodyHeight - statusBarHeight)
        final screenHeight = MediaQuery.of(context).size.height;
        final statusBarHeight = MediaQuery.of(context).viewPadding.top;
        final ctrl = widget.sheetDragController;
        final fraction = (ctrl != null && ctrl.isAttached && ctrl.size > 0.01) ? ctrl.size : null;
        final scaffoldBodyHeight = fraction != null
            ? constraints.maxHeight / fraction
            : constraints.maxHeight;
        final effectiveBottomPadding = (keyboardHeight - screenHeight + scaffoldBodyHeight + statusBarHeight)
            .clamp(0.0, keyboardHeight);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: cardColor,
            padding: EdgeInsets.only(bottom: effectiveBottomPadding),
            child: Column(
              children: [
                _buildHeader(),
                _buildSelectedTagBar(),
                // Stack: tag list behind, results panel floating at bottom
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        controller: scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        // Extra bottom padding so tags aren't hidden behind the results panel
                        padding: EdgeInsets.fromLTRB(
                          16, 0, 16,
                          isSearching ? resultsPanelMaxHeight + 8 : 16,
                        ),
                        children: [
                          _buildTagChips(allTags),
                        ],
                      ),
                      if (isSearching)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildSearchResultsPanel(filteredTags),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildSearchField(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
