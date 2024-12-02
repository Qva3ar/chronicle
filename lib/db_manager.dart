import 'dart:developer';

import 'package:Chrono/models/instructions.model.dart';
import 'package:Chrono/models/record.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'features/health_reminder/data/db/health_reminder_db_service.dart';

class DatabaseHelper {
  final pageSize = 1000;
  static final _databaseName = "awarnes-4.db";
  static final _databaseVersion = 13;

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

  static final tableInstructions = 'instructions';

  static final columnInstructionId = '_id';
  static final columnInstructionText = 'text';
  static final columnVisibility = 'visibility';

  static Database? _database;

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database?> get database1 async {
    if (_database == null) {
      _database = await _initDatabase();
    }
    return _database;
  }

  // this opens the database (and creates it if it doesn't exist)
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    String path = join(databasePath, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
    await db.execute('''
      CREATE TABLE $tableInstructions (
        $columnInstructionId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnInstructionText TEXT,
        $columnVisibility INTEGER
      )
      ''');

    await db.execute('''
    CREATE TABLE ${HealthReminderDbService.tableName}(
    ${HealthReminderDbService.columnId} TEXT PRIMARY KEY, 
    ${HealthReminderDbService.columnDate} TEXT,
    ${HealthReminderDbService.columnDescription} TEXT,
    ${HealthReminderDbService.columnDays} TEXT
    )
    ''');

    await insertInstructions(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Удалите существующие таблицы
    await db.execute('DROP TABLE IF EXISTS $tableCategory');
    await db.execute('DROP TABLE IF EXISTS $tableRecord');
    await db.execute('DROP TABLE IF EXISTS $tableRecordTag');

    // Создайте новые таблицы с обновленной схемой
    await _onCreate(db, newVersion);
  }

  Future<void> insertInstructions(Database db) async {
    await db.insert(tableInstructions, {
      columnInstructionText: 'Summarize my note',
      columnVisibility: 1,
    });

    await db.insert(tableInstructions, {
      columnInstructionText: 'Translate to turkish',
      columnVisibility: 0,
    });

    await db.insert(tableInstructions, {
      columnInstructionText: 'Rewrite my note',
      columnVisibility: 0,
    });
  }

  // Helper methods

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    Database? db = await database;
    return await db.insert(tableCategory, row);
  }

  Future<int> updateTag(int tagId, Map<String, dynamic> row) async {
    final Database db = await database;
    return await db.update(
      tableCategory,
      row,
      where: '$columnId = ?',
      whereArgs: [tagId],
    );
  }

  Future<int> insertRecord(Map<String, dynamic> row, List<int> tagIds) async {
    final Database db = await database;
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
    final Database db = await database;
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
    Database db = await database;
    var result = await db.rawQuery('SELECT COUNT(*) FROM $tableRecord WHERE $columnId = ?', [id]);
    return Sqflite.firstIntValue(result) == 1;
  }

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await database;
    return await db.query(tableCategory);
  }

  Future<List<Map<String, dynamic>>> queryRecords(
    int page,
  ) async {
    final offset = (page - 1) * pageSize; // pageSize - количество записей на одной странице
    final Database db = await database;
    final records = await db.query(tableRecord,
        limit: pageSize, offset: offset, orderBy: DatabaseHelper.columnRecordCreatedAt);
    return records;
  }

  Future<List<Record>> queryAllRecords() async {
    Database db = await database;
    final recordsData = await db.query(tableRecord, orderBy: columnRecordCreatedAt);
    List<Record> records = recordsData.map((data) => Record.fromMap(data)).toList();
    return records;
  }

  Future<List<Map<String, dynamic>>> fetchAllNotes() async {
    Database db = await database;
    List<Map<String, dynamic>> notes = await db.query(tableRecord);

    List<Map<String, dynamic>> notesWithTags = []; // List to hold notes with their tags

    for (var note in notes) {
      List<Map<String, dynamic>> tags = await db.rawQuery(
          'SELECT t.* FROM $tableCategory t JOIN $tableRecordTag rt ON t.$columnId = rt.tagId WHERE rt.recordId = ?',
          [note['_id']]);

      // Create a new map for the note that includes the tags
      Map<String, dynamic> noteWithTags = Map.from(note);
      noteWithTags['tags'] = tags.map((tag) => tag[columnId]).toList();

      notesWithTags.add(noteWithTags);
    }

    return notesWithTags;
  }

  Future<List<Record>> getRecordsWithTag(int? tagId, int limit, int offset,
      {String? searchText}) async {
    final Database db = await database;
    String query;
    List<dynamic> queryParams = [];

    // Construct the SQL query
    query = '''
    SELECT 
      $tableRecord.*,
      GROUP_CONCAT($tableCategory.$columnId) AS tags
    FROM $tableRecord
    LEFT JOIN $tableRecordTag ON $tableRecord._id = $tableRecordTag.recordId
    LEFT JOIN $tableCategory ON $tableRecordTag.tagId = $tableCategory.$columnId
    WHERE 
      (${tagId != null ? "$tableRecordTag.tagId = ?" : "1=1"}) 
      ${searchText != null && searchText.isNotEmpty ? "AND ($columnRecordText LIKE ?)" : ""}
    GROUP BY $tableRecord._id
    ORDER BY $tableRecord.created_at DESC
    LIMIT ? OFFSET ?
  ''';

    // Add parameters to the query
    if (tagId != null) {
      queryParams.add(tagId);
    }

    // Add search text parameters if provided
    if (searchText != null && searchText.isNotEmpty) {
      queryParams.add('%$searchText%');
    }

    queryParams.add(limit); // Add limit to query parameters
    queryParams.add(offset); // Add offset to query parameters

    // Execute the query
    final List<Map<String, dynamic>> recordsData = await db.rawQuery(query, queryParams);

    // Map the results to Record objects
    List<Record> records = recordsData.map((data) {
      return Record.fromMap(data);
    }).toList();

    return records;
  }

  Future<List<Record>> queryAllRowsofRecords() async {
    Database db = await database;

    final List<Map<String, dynamic>> recordsData = await db.query(tableRecord);
    List<Record> records = recordsData.map((data) => Record.fromMap(data)).toList();
    return records;
  }

  Future<List<Record>> getRecordsByIds(String recordIds) async {
    final Database db = await database;
    final List<Map<String, dynamic>> recordsData = await db.query(
      tableRecord,
      where: '$columnId IN (${recordIds})',
    );

    List<Record> records = recordsData.map((data) => Record.fromMap(data)).toList();
    return records;
  }

  Future<int> insertInstruction(Instruction instruction) async {
    Database db = await database;
    Map<String, dynamic> row = {
      columnInstructionText: instruction.text,
      columnVisibility: instruction.visibility ? 1 : 0,
    };
    return await db.insert(tableInstructions, row);
  }

  Future<List<Instruction>> queryAllInstructions() async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(tableInstructions);
    return result.map((map) => Instruction.fromMap(map)).toList();
  }

  Future<int> updateInstruction(Instruction instruction) async {
    Database db = await database;
    Map<String, dynamic> row = instruction.toMap();
    return await db.update(
      tableInstructions,
      row,
      where: '$columnInstructionId = ?',
      whereArgs: [instruction.id],
    );
  }

  Future<int> deleteInstruction(int id) async {
    Database db = await database;
    return await db.delete(
      tableInstructions,
      where: '$columnInstructionId = ?',
      whereArgs: [id],
    );
  }

  // All of the methods (insert, query, update, delete) can also be done using
  // raw SQL commands. This method uses a raw query to give the row count.
  // Future<int> queryRowCount() async {
  //   Database db = await instance.database;
  //   return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableRecord')) ?? 0;
  // }

  // We are assuming here that the id column in the map is set. The other
  // column values will be used to update the row.
  // Future<int> update(Map<String, dynamic> row) async {
  //   Database db = await instance.database;
  //   int id = row[columnId];
  //   return await db.update(tableCategory, row, where: '$columnId = ?', whereArgs: [id]);
  // }

  // Deletes the row specified by the id. The number of affected rows is
  // returned. This should be 1 as long as the row exists.
  Future<bool> deleteTag(int id) async {
    final Database db = await database;

    try {
      await db.transaction((txn) async {
        // Delete the category from the tableCategory
        await txn.delete(tableCategory, where: '$columnId = ?', whereArgs: [id]);

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
    Database db = await database;
    return await db.delete(tableRecord, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> countRecords() async {
    final Database db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableRecord'));
    return result ?? 0;
  }

  Future<void> importRecords(dynamic data) async {
    final Database db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableRecord);
      await txn.delete(tableCategory);
      await txn.delete(tableRecordTag);

      // Insert all tags
      if (data['tags'] != null) {
        for (var tag in data['tags']) {
          await txn.insert(
              tableCategory,
              {
                '_id': tag['id'], // Assuming 'id' is provided and auto-increment is not used
                'name': tag['name'],
                'color': tag['color'],
              },
              conflictAlgorithm: ConflictAlgorithm
                  .ignore); // Use ignore to avoid insertion errors if id already exists
        }
      }

      // Insert all notes
      if (data['notes'] != null) {
        for (var note in data['notes']) {
          String noteText = note['text'];
          if (noteText.contains("часть вторая")) {
            log("часть вторая");
            log(note['created_at'].toString());
            log(_parseDateToTimestamp(note['created_at']).toString());
          }
          if (note.containsKey('title') && note['title'] != null && note['title'].isNotEmpty) {
            noteText = '${note['title']}\n\n$noteText';
          }
          int noteId = await txn.insert(
              tableRecord,
              {
                '_id': note['id'], // Assuming 'id' is provided and auto-increment is not used
                'text': noteText,
                'created_at': _parseDateToTimestamp(note['created_at']),
              },
              conflictAlgorithm:
                  ConflictAlgorithm.ignore); // Use ignore to skip insertion if id already exists

          // Insert note-tag associations if provided
          if (note['tags'] != null) {
            for (var tagId in note['tags']) {
              await txn.insert(
                  tableRecordTag,
                  {
                    'recordId': noteId,
                    'tagId': tagId,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore); // Use ignore to avoid duplicates
            }
          }
        }
      }
    });
  }

  Future<void> deleteAllNotes() async {
    final Database db = await database;
    await db.transaction((txn) async {
      // First, delete all entries from the junction table that may reference notes
      await txn.delete(tableRecordTag);

      // Then, delete all entries from the notes table
      await txn.delete(tableRecord);
    });
  }

  // Helper method to parse dates into timestamps
  int _parseDateToTimestamp(dynamic createdAt) {
    // Check if 'createdAt' is already an integer (timestamp in milliseconds)
    if (createdAt is int) {
      return createdAt; // Return it directly if it's already a timestamp
    }

    // If 'createdAt' is a string, attempt to parse it to DateTime
    if (createdAt is String) {
      // Initialize parsedDate to the current time as a default
      DateTime parsedDate = DateTime.now();
      int currentYear = DateTime.now().year; // Get current year to use for dates without a year

      try {
        // Create a formatter to handle different expected date formats
        List<DateFormat> dateFormats = [
          DateFormat("h:mm a"), // for "10:30 AM"
          DateFormat("MMM d, yyyy"), // for "Jan 14, 2022"
          DateFormat("MMM d, yyyy h:mm a"), // combined date and time if needed
          DateFormat("MMM d"), // for "Mar 19" assuming current year
        ];

        for (var format in dateFormats) {
          try {
            // Special handling for "MMM d" format to add current year
            if (format.pattern == "MMM d") {
              String dateStringWithYear = "$createdAt, $currentYear";
              parsedDate = DateFormat("MMM d, yyyy").parse(dateStringWithYear);
            } else {
              parsedDate = format.parse(createdAt);
            }
            break; // Exit the loop if the date is successfully parsed
          } catch (_) {
            // Ignore errors and try the next format
          }
        }
      } catch (e) {
        // Log or handle the error as needed
        print("Error parsing date: $e");
      }
      return parsedDate.millisecondsSinceEpoch;
    }

    // Fallback to current time if the input is neither int nor a recognizable string
    return DateTime.now().millisecondsSinceEpoch;
  }
}
