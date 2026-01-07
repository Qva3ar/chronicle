import 'package:chrono/models/record.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/gpt.service.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:rxdart/rxdart.dart';

import 'models/tag.dart';

class RecordService {
  static final RecordService _singleton = RecordService._internal();
  GPTService gptService = GPTService();
  // 🎯 FIXED: Private constructor with proper debouncing and state management
  RecordService._internal() {
    print("🔧 RecordService: Initializing with enhanced debouncing");

    // Debounce title changes (keep original timing)
    _titleSubject.debounceTime(Duration(milliseconds: 300)).listen((event) {
      prepareTitle(event);
    });

    // 🎯 FIXED: Reduced debounce time for faster auto-save while typing
    _textSubject.debounceTime(Duration(milliseconds: 500)).listen((event) {
      prepareText(event);
    });

    // Keep GPT recommendations with separate debouncing
    _textSubject.debounceTime(Duration(milliseconds: 1500)).listen((event) {
      if (event.isNotEmpty && event.length > 10) {
        // Only get recommendations for substantial text
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

  final dbHelper = DatabaseHelper.instance;

  final _titleSubject = BehaviorSubject<String>.seeded('');
  final _textSubject = BehaviorSubject<String>.seeded('');
  final _tagIdsSubject = BehaviorSubject<List<int>?>.seeded([]);
  final _isLockedSubject = BehaviorSubject<bool>.seeded(false);
  final _tags = BehaviorSubject<List<Tag>>.seeded([]);
  final gptSelectedTags = PublishSubject<String>();
  final _recordCreatedSubject = PublishSubject<Record>();
  int? _currentRecordId;
  bool _isCreatingRecord = false; // 🎯 NEW: Prevent concurrent record creation
  String _lastProcessedText = ''; // 🎯 NEW: Track last processed text to prevent duplicates

  Stream<Record> get recordCreatedStream => _recordCreatedSubject.stream;

  final _importSubject = BehaviorSubject<bool>();

  // Stream getter to be used by UI components
  Stream<bool> get importStream => _importSubject.stream;

  // Method to call when import is successful
  void importSuccess() {
    _importSubject.sink.add(true);
    _recordCreatedSubject.close();
  }

  // 🎯 ENHANCED: Dispose method with proper cleanup
  void dispose() {
    print("🧹 RecordService: Disposing and cleaning up");
    _importSubject.close();
    _currentRecordId = null;
    _isCreatingRecord = false;
    _lastProcessedText = '';
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
    _isLockedSubject.add(false);
  }

  void setCurrentRecordId(int? recordId) {
    if (recordId != null) {
      _currentRecordId = recordId;
      print("🎯 RecordService: Set current record ID to $recordId (edit mode)");
    } else {
      _currentRecordId = null;
      _lastProcessedText = ''; // Reset when starting new note
      print("🎯 RecordService: Cleared record ID (create mode)");
    }
  }

  void prepareTitle(String title) {
    if (title.isEmpty) {
      return;
    }
    Map<String, dynamic> updatedRow = {
      DatabaseColumns.recordTitle: title,
      DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
    };
    _handleTitleAndText(updatedRow);
  }

  void prepareText(String text) {
    // 🎯 ENHANCED: Skip empty text and prevent duplicate processing
    if (text.isEmpty || text.trim().isEmpty) {
      if (_currentRecordId != null) {
        print("🗑️ RecordService: Empty text for existing record, deleting ID: $_currentRecordId");
        deleteRecord(_currentRecordId!);
      } else {
        print("⏭️ RecordService: Skipping empty text for new record");
      }
      return;
    }

    // 🎯 CRITICAL FIX: Prevent processing the same text multiple times
    if (text == _lastProcessedText) {
      print(
          "⏭️ RecordService: Skipping duplicate text: '${text.substring(0, text.length > 20 ? 20 : text.length)}...'");
      return;
    }

    _lastProcessedText = text;
    print(
        "📝 RecordService: Processing text change: '${text.substring(0, text.length > 30 ? 30 : text.length)}...'");

    Map<String, dynamic> updatedRow = {
      DatabaseColumns.recordText: text,
    };
    _handleTitleAndText(updatedRow);
  }

  Future<void> deleteRecord(int id) async {
    await dbHelper.deleteContact(id);
    _currentRecordId = null; // Clear ID after deletion
    _lastProcessedText = ''; // Reset text
  }

  void handleLock(bool isLocked) {
    _isLockedSubject.add(isLocked);
    Map<String, dynamic> updatedRow = {
      DatabaseColumns.recordIsLocked: isLocked ? 1 : 0,
    };
    _handleTitleAndText(updatedRow);
  }

  Future<Record?> createRecord(Map<String, dynamic> row, List<int> tags) async {
    final id = await dbHelper.insertRecord(row, tags);
    // id is int, so it's never null, but keeping check for logic flow or if type changes
    final newRecords = await dbHelper.getRecordsByIds(id.toString());
    if (newRecords.isNotEmpty) {
      final newRecord = newRecords.first;
      _recordCreatedSubject.sink.add(newRecord);
      return newRecord;
    }
    return null;
  }

  // 🎯 COMPLETELY REWRITTEN: Fixed record creation logic to prevent duplicates
  void _handleTitleAndText(Map<String, dynamic> updatedRow) async {
    // 🎯 CRITICAL FIX: Prevent concurrent operations
    if (_isCreatingRecord) {
      print("⏸️ RecordService: Already creating/updating record, skipping");
      return;
    }

    _isCreatingRecord = true;

    try {
      if (_currentRecordId != null) {
        // 📝 EDIT MODE: Update existing record
        print("✏️ RecordService: Updating existing record ID: $_currentRecordId");

        bool recordExists = await dbHelper.recordExists(_currentRecordId!);
        if (recordExists) {
          updatedRow[DatabaseColumns.id] = _currentRecordId;
          await dbHelper.updateRecord(updatedRow, _tagIdsSubject.value!);
          print("✅ RecordService: Record $_currentRecordId updated successfully");
        } else {
          print("⚠️ RecordService: Record $_currentRecordId doesn't exist, creating new one");
          updatedRow[DatabaseColumns.recordCreatedAt] = DateTime.now().millisecondsSinceEpoch;
          final newRecord = await createRecord(updatedRow, _tagIdsSubject.value!);
          if (newRecord != null) {
            _currentRecordId = newRecord.id;
            print("✅ RecordService: New record created with ID: $_currentRecordId");
          }
        }
      } else {
        // 🆕 CREATE MODE: Create new record only if we don't have one yet
        if (updatedRow[DatabaseColumns.recordText] != null) {
          print("🆕 RecordService: Creating new record (current ID is null)");

          updatedRow[DatabaseColumns.recordCreatedAt] = DateTime.now().millisecondsSinceEpoch;
          final newRecord = await createRecord(updatedRow, _tagIdsSubject.value!);
          if (newRecord != null) {
            _currentRecordId = newRecord.id;
            print("✅ RecordService: New record created successfully with ID: $_currentRecordId");
            print("🔄 RecordService: Switching to EDIT MODE for subsequent changes");
          } else {
            print("❌ RecordService: Failed to create new record");
          }
        } else {
          print("⏭️ RecordService: No text content to save, skipping record creation");
        }
      }
    } catch (e) {
      print("❌ RecordService: Error in _handleTitleAndText: $e");
    } finally {
      _isCreatingRecord = false;
    }
  }

  Future<List<Record>> queryRecords() async {
    final allRecords = await dbHelper.queryAllRecords();
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
              value: e[DatabaseColumns.id],
              label: e[DatabaseColumns.tagName],
              selected:
                  selectedTags != null && selectedTags.contains(e[DatabaseColumns.id]) || false,
              decorations: MultiSelectItemDecorations(
                decoration: BoxDecoration(
                    color: Color(int.tryParse(e[DatabaseColumns.tagColor].toString()) ?? 0xFFFFFFFF)
                        .withAlpha(150),
                    borderRadius: BorderRadius.circular(10)),
                selectedDecoration: BoxDecoration(
                    color:
                        Color(int.tryParse(e[DatabaseColumns.tagColor].toString()) ?? 0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(10)),
              ),
            ))
        .toList();
  }

  Future<List<MultiSelectCard<dynamic>>> queryAllTags() async {
    final allTags = await dbHelper.queryAllRows();

    return allTags
        .map((e) => MultiSelectCard(
              value: e[DatabaseColumns.id],
              label: e[DatabaseColumns.tagName],
              decorations: MultiSelectItemDecorations(
                decoration: BoxDecoration(
                    color: Color(int.tryParse(e[DatabaseColumns.tagColor].toString()) ?? 0xFFFFFFFF)
                        .withAlpha(150),
                    borderRadius: BorderRadius.circular(10)),
                selectedDecoration: BoxDecoration(
                    color:
                        Color(int.tryParse(e[DatabaseColumns.tagColor].toString()) ?? 0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(10)),
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
      DatabaseColumns.tagName: catName,
      DatabaseColumns.tagColor: color,
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
    // Navigator.push(context, MaterialPageRoute(builder: (_) => ContactList()));
  }

  Future<int> updateTag(int tagId, String catName, int color) async {
    // row to insert
    Map<String, dynamic> row = {
      DatabaseColumns.tagName: catName,
      DatabaseColumns.tagColor: color,
    };

    final id = await dbHelper.updateTag(tagId, row);
    return id;
  }

  Future<bool> deleteTag(int tagId) async {
    return await dbHelper.deleteTag(tagId);
  }

  Future<int> getCountOfRecords() async {
    int recordCount = await dbHelper.countRecords();
    //print(recordCount);

    return recordCount;
  }
}
