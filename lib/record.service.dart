import 'package:Chrono/db_manager.dart';
import 'package:Chrono/models/record.dart';
import 'package:Chrono/services/gpt.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:rxdart/rxdart.dart';

import 'models/tag.dart';

class RecordService {
  static final RecordService _singleton = RecordService._internal();
  GPTService gptService = GPTService();

  // Приватный конструктор
  RecordService._internal() {
    //print("Конструктор RecordService вызван");
    _titleSubject.debounceTime(Duration(milliseconds: 300)).listen((event) {
      prepareTitle(event);
    });
    _textSubject.debounceTime(Duration(milliseconds: 300)).listen((event) {
      prepareText(event);
    });

    _textSubject.debounceTime(Duration(milliseconds: 500)).listen((event) {
      if (event.isNotEmpty) {
        getRecomendations(event);
      }
    });
  }

  getRecomendations(String event) async {
    // final complation = await gptService.getCompletion(event, _tags.value);
    // //print("===========ID===========");
    // //print(complation.choices[0]);
    // OpenAIChatCompletionChoiceModel model = complation.choices[0];
    // gptSelectedTags.add(model.message.content);
  }

  // Фабричный метод для получения экземпляра класса
  factory RecordService() {
    return _singleton;
  }

  final dbHelper = DatabaseHelper();

  final _titleSubject = BehaviorSubject<String>.seeded('');
  final _textSubject = BehaviorSubject<String>.seeded('');
  final _tagIdsSubject = BehaviorSubject<List<int>?>.seeded([]);
  final _tags = BehaviorSubject<List<Tag>>.seeded([]);
  final gptSelectedTags = PublishSubject<String>();
  int? _currentRecordId;

  final _importSubject = BehaviorSubject<bool>();

  // Stream getter to be used by UI components
  Stream<bool> get importStream => _importSubject.stream;

  // Method to call when import is successful
  void importSuccess() {
    _importSubject.sink.add(true);
  }

  // Dispose method to close the stream
  void dispose() {
    _importSubject.close();
  }

  List<Record> allRecords = [];

  setRecords(List<Record> records) {
    allRecords = records;
  }

  getAllRecords() {
    return allRecords;
  }

  void handleTitle(String title) {
    _titleSubject.add(title);
  }

  void handleText(String desc) {
    _textSubject.add(desc);
  }

  void setTagIds(List<int>? tagIds) {
    _tagIdsSubject.add(tagIds ?? []);
    Map<String, dynamic> updatedRow = {};

    _handleTitleAndText(updatedRow);
  }

  void clearTagIds() {
    _tagIdsSubject.add([]);
  }

  void setCurrentRecordId(int? recordId) {
    if (recordId != null) {
      _currentRecordId = recordId;
    } else {
      _currentRecordId = null;
    }
  }

  void prepareTitle(String title) {
    if (title.isEmpty) {
      return;
    }
    Map<String, dynamic> updatedRow = {
      DatabaseHelper.columnRecordTitle: title,
      DatabaseHelper.columnRecordCreatedAt: DateTime.now().millisecondsSinceEpoch,
    };
    _handleTitleAndText(updatedRow);
  }

  void prepareText(String text) {
    if (text.isEmpty) {
      return;
    }
    Map<String, dynamic> updatedRow = {
      DatabaseHelper.columnRecordText: text,
    };
    _handleTitleAndText(updatedRow);
  }

  void _handleTitleAndText(Map<String, dynamic> updatedRow) async {
    if (_currentRecordId != null) {
      bool recordExists = await dbHelper.recordExists(_currentRecordId!);
      if (recordExists) {
        updatedRow[DatabaseHelper.columnId] = _currentRecordId;
        await dbHelper.updateRecord(updatedRow, _tagIdsSubject.value!);
        //print('Record updated');
      } else {
        updatedRow[DatabaseHelper.columnRecordCreatedAt] = DateTime.now().millisecondsSinceEpoch;
        _currentRecordId = await dbHelper.insertRecord(updatedRow, _tagIdsSubject.value!);
        //print('New record created with id: $_currentRecordId');
      }
    } else {
      if (updatedRow[DatabaseHelper.columnRecordText] != null) {
        updatedRow[DatabaseHelper.columnRecordCreatedAt] = DateTime.now().millisecondsSinceEpoch;
        _currentRecordId = await dbHelper.insertRecord(updatedRow, _tagIdsSubject.value!);
        //print('New record created with id: $_currentRecordId');
      }
    }

    // _queryRecords();
  }

  Future<List<Record>> queryRecords() async {
    final allRecords = await dbHelper.queryAllRowsofRecords();
    //print(allRows[0]);
    return allRecords;
    // allRows.forEach(print);
  }

  Future<List<MultiSelectCard<dynamic>>> queryTags(List<int>? selectedTags) async {
    final allTags = await dbHelper.queryAllRows();

    return allTags
        // .where((e) =>
        //     selectedTags != null && selectedTags.contains(e['_id']) || false)
        .map((e) => MultiSelectCard(
              value: e['_id'],
              label: e['name'],
              selected: selectedTags != null && selectedTags.contains(e['_id']) || false,
              decorations: MultiSelectItemDecorations(
                decoration: BoxDecoration(
                    color: Color(int.parse(e['color'])).withAlpha(150),
                    borderRadius: BorderRadius.circular(10)),
                selectedDecoration: BoxDecoration(
                    color: Color(int.parse(e['color'])), borderRadius: BorderRadius.circular(10)),
              ),
            ))
        .toList();
  }

  Future<List<MultiSelectCard<dynamic>>> queryAllTags() async {
    final allTags = await dbHelper.queryAllRows();

    return allTags
        .map((e) => MultiSelectCard(
              value: e['_id'],
              label: e['name'],
              decorations: MultiSelectItemDecorations(
                decoration: BoxDecoration(
                    color: Color(int.parse(e['color'])).withAlpha(150),
                    borderRadius: BorderRadius.circular(10)),
                selectedDecoration: BoxDecoration(
                    color: Color(int.parse(e['color'])), borderRadius: BorderRadius.circular(10)),
              ),
            ))
        .toList();
  }

  Future<List<Tag>> queryAllTagsJust() async {
    final allTagsData = await dbHelper.queryAllRows();
    final List<Tag> allTags = allTagsData.map((tagData) {
      return Tag.fromJson(tagData);
    }).toList();
    _tags.add(allTags);

    return allTags;
  }

  Future<int> insertTag(String catName, int color) async {
    var base64image;
    // if (imageFile?.exists() != null) {
    //   base64image = base64Encode(imageFile!.readAsBytesSync().toList());
    // }

    // row to insert
    Map<String, dynamic> row = {
      DatabaseHelper.columnTagName: catName,
      DatabaseHelper.columnTagColor: color,
      // DatabaseHelper.columnMobile: _mobileNumber.text,
      // DatabaseHelper.columnEmail: _emailAddress.text,
      // DatabaseHelper.columnCategory: currentCategory,
      // DatabaseHelper.columnProfile: base64image,
    };
    final id = await dbHelper.insert(row);
    return id;
    // //print('insert stRT');
    // currentCategory = "";

    // final id = await dbHelper.insert(row);
    // if (kDebugMode) {
    //   //print('inserted row id: $id');
    // }
    // _query();
    // Navigator.push(context, MaterialPageRoute(builder: (_) => ContactList()));
  }

  Future<int> updateTag(int tagId, String catName, int color) async {
    // row to insert
    Map<String, dynamic> row = {
      DatabaseHelper.columnTagName: catName,
      DatabaseHelper.columnTagColor: color,
    };

    final id = await dbHelper.updateTag(tagId, row);
    return id;
  }

  Future<bool> deleteTag(int tagId) async {
    return await dbHelper.deleteTag(tagId);
  }

  Future<int> getCountOfRecords() async {
    int recordCount = await DatabaseHelper().countRecords();
    //print(recordCount);

    return recordCount;
  }
}
