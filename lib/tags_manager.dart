// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Chrono/contact_list.dart';
import 'package:Chrono/record.service.dart';
import 'package:Chrono/shared/confirm-dialog.dart';
import 'package:Chrono/tag_color_picker.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:signature/signature.dart';

import 'colors.dart';
import 'db_manager.dart';
import 'models/tag.dart';
import 'mydrawal.dart';

class Animal {
  final int id;
  final String name;

  Animal({
    required this.id,
    required this.name,
  });
}

class Category {
  late int id;
  final String name;

  Category({
    required this.name,
  });
}

class TagsManager extends StatefulWidget {
  final void Function(int?) onTagSelected; //
  final int? selectedTag;

  const TagsManager({Key? key, this.selectedTag, required this.onTagSelected}) : super(key: key);

  @override
  _TagsManagerState createState() => _TagsManagerState();
}

class _TagsManagerState extends State<TagsManager> {
  RecordService recordService = RecordService(); // Замените RecordService на ваш реальный сервис
  final dbHelper = DatabaseHelper.instance;

  final TextEditingController _categoryController = TextEditingController();
  final formGlobalKey = GlobalKey<FormState>();
  List<Category> allCategoryData = [];
  late Future<Uint8List> imageBytes;

  int? selectedChipIndex;
  List<Tag> allTags = [];
  Tag addTag = Tag(
    id: -1,
    name: "Add/Remove",
    color: Colors.white.value.toString(),
  );
  Tag? selectedTag;
  bool isEditing = false;

  int selectedColor = Colors.transparent.value;

  void onColorSelected(Color color) {
    selectedColor = color.value;
  }

  Future<void> getAllTags() async {
    List<Tag> tags = await recordService.queryAllTagsJust();
    setState(() {
      allTags = tags;
      allTags.add(addTag);
    });
  }

  @override
  void initState() {
    selectedChipIndex = widget.selectedTag;
    super.initState();
    _query();
    getAllTags();
  }

  Future<void> saveTag() async {
    if (selectedTag != null) {
      await recordService.updateTag(selectedTag!.id, _categoryController.text, selectedColor);
    } else {
      await recordService.insertTag(_categoryController.text, selectedColor);
    }
    getAllTags();
    _categoryController.text = "";
  }

  Future<void> removeTag() async {
    if (selectedTag != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ConfirmDialog(
            title: "Tag deletion",
            message: "Are you sure?",
            onConfirm: (bool) async {
              final id = await recordService.deleteTag(selectedTag!.id);
              if (id) {
                getAllTags();
                widget.onTagSelected(null);
                _categoryController.text = "";
                selectedTag = null;
              }
            },
          );
        },
      );
    }
  }

  void setEditing(bool isEdit) {
    setState(() {
      isEditing = isEdit;
    });
    if (isEditing) {
      selectTagForEditing();
    }
  }

  void selectTagForEditing() {
    if (isEditing && selectedChipIndex != null) {
      selectedTag = allTags.firstWhere(
        (element) => element.id == selectedChipIndex,
      );
      if (selectedTag != null) {
        _categoryController.text = selectedTag!.name;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MyColors.secondaryColor,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: formGlobalKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Search by Tag"),
              Wrap(
                spacing: 8.0, // Расстояние между чипсами
                children: allTags.map((entry) {
                  final int id = entry.id;
                  final tag = entry;

                  return ChoiceChip(
                    label: Text(tag.name ?? ""), // Замените на ваш текст
                    selected: selectedChipIndex == id,
                    side: selectedChipIndex == id ? BorderSide(width: 2, color: white) : null,
                    backgroundColor: Color(int.parse(tag.color!)),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          if (id == -1) {
                            setEditing(!isEditing);
                            return;
                          }
                          // currentPage = 0;
                          widget.onTagSelected(id);
                          selectedChipIndex = id;
                          selectTagForEditing();
                          // loadRecords();
                        } else {
                          if (id == -1) {
                            setEditing(false);
                            return;
                          }
                          widget.onTagSelected(null);
                          // currentPage = 0;
                          selectedChipIndex = null;
                          // loadRecords();
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              isEditing
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: InputDecoration(
                              fillColor: Colors.white,
                              filled: true,
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: const Color.fromARGB(255, 223, 234, 229), width: 2.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: MyColors.primaryColor, width: 1.0),
                              ),
                              hintText: 'Tag Name',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            ),
                            controller: _categoryController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Write Tag name';
                              }
                              return null;
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ColorPickerWidget(
                                selected: selectedTag, onColorSelected: onColorSelected),
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: TextButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.all<Color>(MyColors.trecondaryColor),
                                  ),
                                  onPressed: () {
                                    if (formGlobalKey.currentState!.validate()) {
                                      saveTag();
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
                                        backgroundColor:
                                            WidgetStateProperty.all<Color>(MyColors.remove),
                                      ),
                                      onPressed: () {
                                        if (formGlobalKey.currentState!.validate()) {
                                          removeTag();
                                        }
                                      },
                                      child: Text(
                                        "Remove",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    )
                                  : Container()
                            ],
                          ),
                        ],
                      ),
                    )
                  : Container()
            ],
          ),
        ),
      ),
    );
  }

  void _query() async {
    final allRows = await dbHelper.queryAllRows();
    if (kDebugMode) {
      //print('query all rows:');
    }
    allCategoryData = allRows.map((element) => Category(name: element["name"])).toList();
    setState(() {});
  }
}
