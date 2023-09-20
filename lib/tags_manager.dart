// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_crud/contact_list.dart';
import 'package:flutter_crud/record.service.dart';
import 'package:flutter_crud/shared/confirm-dialog.dart';
import 'package:flutter_crud/tag_color_picker.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:image_picker/image_picker.dart';
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
  final void Function(int) onTagSelected; //

  const TagsManager({Key? key, required this.onTagSelected}) : super(key: key);

  @override
  _TagsManagerState createState() => _TagsManagerState();
}

class _TagsManagerState extends State<TagsManager> {
  RecordService recordService = new RecordService();

  // final TextEditingController _firstName = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  // final TextEditingController _mobileNumber = TextEditingController();
  // final TextEditingController _emailAddress = TextEditingController();
  final formGlobalKey = GlobalKey<FormState>();
  File? imageFile;
  final ImagePicker _picker = ImagePicker();
  String currentCategory = "";
  var imageEncoded;
  List<Category> allCategoryData = [];
  final dbHelper = DatabaseHelper.instance;
  late Future<Uint8List> imageBytes;
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.red,
    exportBackgroundColor: Colors.blue,
  );
  int key = 0;
  int? selectedChipIndex = null;
  List<Tag> allTags = [];
  Tag addTag = Tag(
      id: -1, name: "Добавить/Изменить", color: Colors.white.value.toString());
  Tag? selectedTag;
  bool isEditing = false;

// INITIALIZE. RESULT IS A WIDGET, SO IT CAN BE DIRECTLY USED IN BUILD METHOD

  int selectedColor = Colors.transparent.value;

  void onColorSelected(Color color) {
    selectedColor = color.value;
  }

  void getAllTags() async {
    allTags = await recordService.queryAllTagsJust();
    allTags.add(addTag);
    // allTags = await recordService.queryAllTagsJust();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _query();
    getAllTags();
  }

  saveTag() async {
    if (selectedTag != null) {
      recordService
          .updateTag(selectedTag!.id, _categoryController.text, selectedColor)
          .then((value) {
        getAllTags();
        // _categoryController.text = "";
      });
    } else {
      recordService
          .insertTag(_categoryController.text, selectedColor)
          .then((value) {
        getAllTags();
        _categoryController.text = "";
      });
    }
  }

  removeTag() async {
    if (selectedTag != null) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return ConfirmDialog(
                title: "Tag deletion",
                message: "Are you sure?",
                onConfirm: (bool result) async {
                  if (result) {
                    final id = await recordService.deleteTag(selectedTag!.id);

                    if (id) {
                      getAllTags();
                      _categoryController.text = "";
                      selectedTag = null;
                    }
                  }
                });
          });
    }
  }

  setEditing(bool isEdit) {
    setState(
      () {
        isEditing = isEdit;
      },
    );
    if (isEditing) {
      selectTagForEditing();
    }
  }

  selectTagForEditing() {
    if (isEditing) {
      selectedTag =
          allTags.where((element) => element.id == selectedChipIndex).first;
      if (selectedTag != null) {
        _categoryController.text = selectedTag!.name;
        setState(() {});
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
              // const SizedBox(
              //   height: 20,
              // ),
              // InkWell(
              //   onTap: () async {
              //     final XFile? pickedFile = await _picker.pickImage(
              //         source: ImageSource.gallery);

              //     if (pickedFile != null) {
              //       imageBytes = pickedFile.readAsBytes();
              //       setState(() {
              //         imageFile = File(pickedFile.path);
              //       });
              //     }
              //   },
              //   child: imageFile == null
              //       ? CircleAvatar(
              //           backgroundColor: MyColors.primaryColor,
              //           minRadius: 50,
              //           child: Icon(
              //             Icons.image,
              //             color: Colors.white,
              //           ),
              //         )
              //       : CircleAvatar(
              //           backgroundImage: Image.file(
              //             imageFile!,
              //             fit: BoxFit.cover,
              //             alignment: Alignment.center,
              //           ).image,
              //           minRadius: 100,
              //         ),
              // ),
              // SizedBox(
              //   height: 20,
              // ),
              // TextFormField(
              //   decoration: InputDecoration(
              //     focusedBorder: OutlineInputBorder(
              //       borderSide: BorderSide(
              //           color: Colors.greenAccent, width: 2.0),
              //     ),
              //     enabledBorder: OutlineInputBorder(
              //       borderSide: BorderSide(
              //           color: MyColors.primaryColor, width: 1.0),
              //     ),
              //     hintText: 'First Name',
              //     contentPadding:
              //         EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              //   ),
              //   controller: _firstName,
              //   validator: (value) {
              //     if (value == null || value.isEmpty) {
              //       return 'Enter First Name';
              //     }
              //     return null;
              //   },
              // ),
              // SizedBox(
              //   height: 20,
              // ),
              // Center(
              //   child: MultiSelectContainer(
              //       key: UniqueKey(),
              //       items: allCategoryData
              //           .map((e) =>
              //               MultiSelectCard(value: e.name, label: e.name))
              //           .toList(),
              //       onChange: (allSelectedItems, selectedItem) {
              //         // var selected = selectedItem as MultiSelectCard;
              //         if (selectedItem == 'add') {
              //           print('ADD');
              //           showModalBottomSheet(
              //               context: context,
              //               builder: (context) {
              //                 return AddRecord();
              //               });
              //           return;
              //         }
              //         print(allSelectedItems);

              //         // setState(() {
              //         //   _animals.add(MultiSelectCard(value: 1, label: "1"));
              //         // });
              //         // print(_animals.length);
              //       }),
              // ),
              Text("Search by Tag"),
              LimitedBox(
                maxHeight: 300,
                child: Wrap(
                  spacing: 8.0, // Расстояние между чипсами
                  children: allTags.map((entry) {
                    final int id = entry.id;
                    final tag = entry;

                    return ChoiceChip(
                      label: Text(tag.name ?? ""), // Замените на ваш текст
                      selected: selectedChipIndex == id,
                      side: selectedChipIndex == id
                          ? BorderSide(width: 2, color: white)
                          : null,
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
                            // currentPage = 0;
                            selectedChipIndex = null;
                            // loadRecords();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              isEditing
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 16),
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: InputDecoration(
                              fillColor: Colors.white,
                              filled: true,
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: const Color.fromARGB(
                                        255, 223, 234, 229),
                                    width: 2.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: MyColors.primaryColor, width: 1.0),
                              ),
                              hintText: 'Tag Name',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
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
                                selected: selectedTag,
                                onColorSelected: onColorSelected),
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: TextButton(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            MyColors.trecondaryColor),
                                  ),
                                  onPressed: () {
                                    if (formGlobalKey.currentState!
                                        .validate()) {
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
                                            MaterialStateProperty.all<Color>(
                                                MyColors.remove),
                                      ),
                                      onPressed: () {
                                        if (formGlobalKey.currentState!
                                            .validate()) {
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
      print('query all rows:');
    }
    allCategoryData =
        allRows.map((element) => Category(name: element["name"])).toList();
    setState(() {});
  }
}
