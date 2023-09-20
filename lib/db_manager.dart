import 'dart:io';

import 'package:flutter_crud/models/record.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  final pageSize = 1000;
  static final _databaseName = "awarnes-4.db";
  static final _databaseVersion = 12;

  static final tableCategory = 'tags';
  static final tableRecord = 'record';
  static final tableRecordTag = 'record_tag';

  static final columnId = '_id';
  static final columnTagName = 'name';
  static final columnTagColor = 'color';
  static final columnText = 'text';
  static final columnMobile = 'mobile';
  static final columnEmail = 'email';
  static final columnCategory = 'cat';
  static final columnProfile = 'profile';

  static final columnRecordTitle = 'title';
  static final columnRecordText = 'text';
  static final columnRecordTags = 'tags';
  static final columnRecordCreatedAt = 'created_at';

  // make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();
  Future<Database?> get database1 async {
    if (_database == null) {
      _database = await _initDatabase();
    }
    return _database;
  }

  // this opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $tableCategory (
            $columnId INTEGER PRIMARY KEY,
            $columnTagName TEXT NOT NULL,
            $columnTagColor TEXT NOT NULL 
          )
          ''');
    await db.execute('''
          CREATE TABLE $tableRecord (
            $columnId INTEGER PRIMARY KEY,
            $columnRecordTitle TEXT,
            $columnRecordText TEXT,
            $columnRecordCreatedAt INTEGER NOT NULL
          )
          ''');

    await db.execute('''
          CREATE TABLE $tableRecordTag (
            id INTEGER PRIMARY KEY,
            recordId INTEGER,
            tagId INTEGER,
            FOREIGN KEY (recordId) REFERENCES Record(id),
            FOREIGN KEY (tagId) REFERENCES Tag(id)
          )
          ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Удалите существующие таблицы
    await db.execute('DROP TABLE IF EXISTS $tableCategory');
    await db.execute('DROP TABLE IF EXISTS $tableRecord');
    await db.execute('DROP TABLE IF EXISTS $tableRecordTag');

    // Создайте новые таблицы с обновленной схемой
    await _onCreate(db, newVersion);
  }

  // Helper methods

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    Database? db = await instance.database;
    return await db.insert(tableCategory, row);
  }

  Future<int> updateTag(int tagId, Map<String, dynamic> row) async {
    final Database db = await instance.database;
    return await db.update(
      tableCategory,
      row,
      where: '$columnId = ?',
      whereArgs: [tagId],
    );
  }

  Future<int> insertRecord(Map<String, dynamic> row, List<int> tagIds) async {
    final Database db = await instance.database;
    int id = await db.transaction((txn) async {
      int recordId = await txn.insert(tableRecord, row);
      for (int tagId in tagIds) {
        await txn.insert(tableRecordTag, {
          'recordId': recordId,
          'tagId': tagId,
        });
      }
      return recordId;
    });
    return id;
  }

  Future<int> updateRecord(Map<String, dynamic> row, List<int> tagIds) async {
    final Database db = await instance.database;
    int id = row[columnId];
    return await db.transaction((txn) async {
      await txn.update(
        tableRecord,
        row,
        where: '$columnId = ?',
        whereArgs: [id],
      );

      // Удаляем старые связи
      await txn.delete(tableRecordTag, where: 'recordId = ?', whereArgs: [id]);

      // Вставляем новые связи
      for (int tagId in tagIds) {
        await txn.insert(tableRecordTag, {
          'recordId': id,
          'tagId': tagId,
        });
      }
      return id;
    });
  }

  Future<bool> recordExists(int id) async {
    Database db = await instance.database;
    var result = await db.rawQuery(
        'SELECT COUNT(*) FROM $tableRecord WHERE $columnId = ?', [id]);
    return Sqflite.firstIntValue(result) == 1;
  }

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(tableCategory);
  }

  Future<List<Map<String, dynamic>>> queryRecords(
    int page,
  ) async {
    final offset = (page - 1) *
        pageSize; // pageSize - количество записей на одной странице
    final Database db = await instance.database;
    final records = await db.query(tableRecord,
        limit: pageSize,
        offset: offset,
        orderBy: DatabaseHelper.columnRecordCreatedAt);
    return records;
  }

  Future<List<Record>> queryAllRecords() async {
    Database db = await instance.database;
    final recordsData =
        await db.query(tableRecord, orderBy: columnRecordCreatedAt);
    List<Record> records =
        recordsData.map((data) => Record.fromMap(data)).toList();
    return records;
  }

  Future<List<Record>> getRecordsWithTag(int page, int? tagId) async {
    final offset = (page - 1) * pageSize;
    final Database db = await database;

    String query;
    List<dynamic> queryParams = [];

    query = '''
    SELECT
      $tableRecord.*,
      GROUP_CONCAT($tableCategory.$columnId) AS tags
    FROM $tableRecord
    LEFT JOIN $tableRecordTag ON $tableRecord._id = $tableRecordTag.recordId
    LEFT JOIN $tableCategory ON $tableRecordTag.tagId = $tableCategory.$columnId
    WHERE ($tagId IS NULL OR $tableRecordTag.tagId = ? OR $tableRecordTag.tagId IS NULL)
    GROUP BY $tableRecord._id
    LIMIT ?
    OFFSET ?
  ''';

    if (tagId != null) {
      queryParams.add(tagId);
    } else {
      queryParams.add(null); // Add a null parameter if tagId is null
    }

    queryParams.add(pageSize);
    queryParams.add(offset);

    final List<Map<String, dynamic>> recordsData =
        await db.rawQuery(query, queryParams);

    List<Record> records = recordsData.map((data) {
      return Record.fromMap(data);
      // final tagsString = data['tags'] as String?;
      // if (tagsString != null) {
      //   // Split the concatenated tags string into a List of tags
      //   final tags = tagsString.split(',');
      //   // record.tagIds = tags;
      // }
      // return record;
    }).toList();

    return records;
  }

  Future<List<Record>> queryAllRowsofRecords() async {
    Database db = await instance.database;

    final List<Map<String, dynamic>> recordsData = await db.query(tableRecord);
    List<Record> records =
        recordsData.map((data) => Record.fromMap(data)).toList();
    return records;
  }

  Future<List<Record>> getRecordsByIds(String recordIds) async {
    final Database db = await database;
    final List<Map<String, dynamic>> recordsData = await db.query(
      tableRecord,
      where: '$columnId IN (${recordIds})',
    );

    List<Record> records =
        recordsData.map((data) => Record.fromMap(data)).toList();
    return records;
  }

  // All of the methods (insert, query, update, delete) can also be done using
  // raw SQL commands. This method uses a raw query to give the row count.
  Future<int> queryRowCount() async {
    Database db = await instance.database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableRecord')) ??
        0;
  }

  // We are assuming here that the id column in the map is set. The other
  // column values will be used to update the row.
  Future<int> update(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db
        .update(tableCategory, row, where: '$columnId = ?', whereArgs: [id]);
  }

  // Deletes the row specified by the id. The number of affected rows is
  // returned. This should be 1 as long as the row exists.
  Future<bool> deleteTag(int id) async {
    final Database db = await instance.database;

    try {
      await db.transaction((txn) async {
        // Delete the category from the tableCategory
        await txn
            .delete(tableCategory, where: '$columnId = ?', whereArgs: [id]);

        // Delete related records in the tableRecordTag
        await txn.delete(tableRecordTag, where: 'tagId = ?', whereArgs: [id]);
      });

      // If the transaction completes without errors, return true
      return true;
    } catch (e) {
      // If an error occurs during deletion, return false
      return false;
    }
  }

  Future<int> deleteContact(int id) async {
    Database db = await instance.database;
    return await db
        .delete(tableRecord, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> countRecords() async {
    final Database db = await database;
    final result = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $tableRecord'));
    return result ?? 0;
  }
}
