import 'dart:developer';
import 'dart:io';

import 'package:chrono/models/goal.model.dart';
import 'package:chrono/models/instructions.model.dart';
import 'package:chrono/models/record.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

/// Database configuration constants
class DatabaseConfig {
  static const String databaseName = "awarnes-4.db";
  static const int databaseVersion = 22;
  static const int pageSize = 20;
}

/// Table and column names
class DatabaseTables {
  static const String category = 'tags';
  static const String record = 'record';
  static const String recordTag = 'record_tag';
  static const String instructions = 'instructions';
  static const String routines = 'routines';
  static const String goals = 'goals';
  static const String sessions = 'sessions';
}

class DatabaseColumns {
  // Common columns
  static const String id = '_id';

  // Category table columns
  static const String tagName = 'name';
  static const String tagColor = 'color';

  // Record table columns
  static const String recordTitle = 'title';
  static const String recordText = 'text';
  static const String recordCreatedAt = 'created_at';
  static const String recordType = 'record_type';
  static const String recordGoalId = 'goal_id';
  static const String recordRoutineId = 'routine_id';

  // Instructions table columns
  static const String instructionText = 'text';
  static const String visibility = 'visibility';

  // Routine table columns
  static const String routineName = 'name';
  static const String routineTime = 'time';
  static const String routineDaysOfWeek = 'days_of_week';
  static const String routinePeriodAfter = 'period_after';
  static const String routineInterval = 'interval';
  static const String routineIsDone = 'is_done';

  // Goal table columns
  static const String goalTitle = 'title';
  static const String goalHours = 'hours';
  static const String goalMinutes = 'minutes';
  static const String goalSessionMinutes = 'session_minutes';
  static const String goalIsActive = 'is_active';
  static const String goalTimeSpentSeconds = 'time_spent_seconds';
  static const String goalSessionResumedTimestampSeconds = 'session_resumed_timestamp_seconds';
  static const String goalCompletedAt = 'completed_at';
}

/// A singleton class that manages the SQLite database operations
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  // Database instance
  static Database? _database;

  /// Get the database instance, initializing it if necessary
  Future<Database> get database async => _database ??= await _initDatabase();

  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      final Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final String path = join(documentsDirectory.path, DatabaseConfig.databaseName);

      return await openDatabase(
        path,
        version: DatabaseConfig.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      log('Error initializing database: $e');
      rethrow;
    }
  }

  /// Initialize database and verify all required tables
  Future<void> initializeDatabase() async {
    try {
      final db = await database;
      print('Database initialized');
    } catch (e) {
      log('Error initializing database: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    try {
      // Create category table
      await db.execute('''
        CREATE TABLE ${DatabaseTables.category} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY,
          ${DatabaseColumns.tagName} TEXT NOT NULL,
          ${DatabaseColumns.tagColor} TEXT NOT NULL 
        )
      ''');

      // Create record table
      await db.execute('''
        CREATE TABLE ${DatabaseTables.record} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY,
          ${DatabaseColumns.recordTitle} TEXT,
          ${DatabaseColumns.recordText} TEXT,
          ${DatabaseColumns.recordCreatedAt} INTEGER NOT NULL,
          ${DatabaseColumns.recordType} TEXT DEFAULT 'regular',
          ${DatabaseColumns.recordGoalId} INTEGER,
          ${DatabaseColumns.recordRoutineId} INTEGER
        )
      ''');

      // Create record-tag junction table
      await db.execute('''
        CREATE TABLE ${DatabaseTables.recordTag} (
          id INTEGER PRIMARY KEY,
          recordId INTEGER,
          tagId INTEGER,
          FOREIGN KEY (recordId) REFERENCES ${DatabaseTables.record}(id),
          FOREIGN KEY (tagId) REFERENCES ${DatabaseTables.category}(id)
        )
      ''');

      // Create instructions table
      await db.execute('''
        CREATE TABLE ${DatabaseTables.instructions} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseColumns.instructionText} TEXT,
          ${DatabaseColumns.visibility} INTEGER
        )
      ''');

      // Create routines table
      await db.execute('''
        CREATE TABLE ${DatabaseTables.routines} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseColumns.routineName} TEXT NOT NULL,
          ${DatabaseColumns.routineTime} TEXT NOT NULL,
          ${DatabaseColumns.routineDaysOfWeek} TEXT NOT NULL,
          ${DatabaseColumns.routinePeriodAfter} INTEGER NOT NULL,
          ${DatabaseColumns.routineInterval} INTEGER NOT NULL,
          ${DatabaseColumns.routineIsDone} INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Create goals table
      await db.execute('''
        CREATE TABLE ${DatabaseTables.goals} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseColumns.goalTitle} TEXT NOT NULL,
          ${DatabaseColumns.goalHours} INTEGER NOT NULL,
          ${DatabaseColumns.goalMinutes} INTEGER NOT NULL,
          ${DatabaseColumns.goalSessionMinutes} INTEGER NOT NULL,
          ${DatabaseColumns.goalIsActive} INTEGER NOT NULL DEFAULT 0,
          ${DatabaseColumns.goalTimeSpentSeconds} INTEGER NOT NULL DEFAULT 0,
          ${DatabaseColumns.goalSessionResumedTimestampSeconds} INTEGER,
          ${DatabaseColumns.goalCompletedAt} INTEGER
        )
      ''');

      // Create sessions table
      await db.execute('''
        CREATE TABLE ${DatabaseTables.sessions} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER NOT NULL,
          start_time INTEGER NOT NULL,
          end_time INTEGER,
          planned_duration_minutes INTEGER NOT NULL,
          actual_duration_seconds INTEGER,
          is_completed INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          FOREIGN KEY (goal_id) REFERENCES ${DatabaseTables.goals}(${DatabaseColumns.id}) ON DELETE CASCADE
        )
      ''');

      await _insertDefaultInstructions(db);
    } catch (e) {
      log('Error creating database tables: $e');
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 14) {
        // Add record_type column to record table
        await db.execute('''
          ALTER TABLE ${DatabaseTables.record}
          ADD COLUMN ${DatabaseColumns.recordType} TEXT DEFAULT 'regular'
        ''');
      }

      if (oldVersion < 15) {
        // Add goals table
        await db.execute('''
          CREATE TABLE ${DatabaseTables.goals} (
            ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseColumns.goalTitle} TEXT NOT NULL,
            ${DatabaseColumns.goalHours} INTEGER NOT NULL,
            ${DatabaseColumns.goalMinutes} INTEGER NOT NULL,
            ${DatabaseColumns.goalSessionMinutes} INTEGER NOT NULL,
            ${DatabaseColumns.goalIsActive} INTEGER NOT NULL DEFAULT 0,
            ${DatabaseColumns.goalTimeSpentSeconds} INTEGER NOT NULL DEFAULT 0,
            ${DatabaseColumns.goalSessionResumedTimestampSeconds} INTEGER,
            ${DatabaseColumns.goalCompletedAt} INTEGER
          )
        ''');
      }

      if (oldVersion < 16) {
        // Check if session column exists before adding it
        final columns = await db.rawQuery('PRAGMA table_info(${DatabaseTables.goals})');
        final hasSessionColumn =
            columns.any((col) => col['name'] == DatabaseColumns.goalSessionMinutes);

        if (!hasSessionColumn) {
          // Add session column to goals table only if it doesn't exist
          await db.execute('''
            ALTER TABLE ${DatabaseTables.goals}
            ADD COLUMN ${DatabaseColumns.goalSessionMinutes} INTEGER DEFAULT 25
          ''');
        }
      }

      if (oldVersion < 17) {
        // Add total_time_spent column to goals table
        await db.execute('''
          ALTER TABLE ${DatabaseTables.goals}
          ADD COLUMN ${DatabaseColumns.goalSessionResumedTimestampSeconds} INTEGER
        ''');
      }

      if (oldVersion < 18) {
        // Add sessions table
        await db.execute('''
          CREATE TABLE ${DatabaseTables.sessions} (
            ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            goal_id INTEGER NOT NULL,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            planned_duration_minutes INTEGER NOT NULL,
            actual_duration_seconds INTEGER,
            is_completed INTEGER NOT NULL DEFAULT 0,
            notes TEXT,
            FOREIGN KEY (goal_id) REFERENCES ${DatabaseTables.goals}(${DatabaseColumns.id}) ON DELETE CASCADE
          )
        ''');
      }

      if (oldVersion < 20) {
        // Drop the old goals table and recreate it with the correct schema.
        // This is a destructive migration but necessary to fix the schema mismatch.
        await db.execute('DROP TABLE IF EXISTS ${DatabaseTables.goals}');
        await db.execute('''
          CREATE TABLE ${DatabaseTables.goals} (
            ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseColumns.goalTitle} TEXT NOT NULL,
            ${DatabaseColumns.goalHours} INTEGER NOT NULL,
            ${DatabaseColumns.goalMinutes} INTEGER NOT NULL,
            ${DatabaseColumns.goalSessionMinutes} INTEGER NOT NULL,
            ${DatabaseColumns.goalIsActive} INTEGER NOT NULL DEFAULT 0,
            ${DatabaseColumns.goalTimeSpentSeconds} INTEGER NOT NULL DEFAULT 0,
            ${DatabaseColumns.goalSessionResumedTimestampSeconds} INTEGER,
            ${DatabaseColumns.goalCompletedAt} INTEGER
          )
        ''');
        log('Upgraded database to v20: Recreated goals table with correct schema.');
      }

      if (oldVersion < 21) {
        // Check if the column already exists to prevent crashes on restart
        final columns = await db.rawQuery('PRAGMA table_info(${DatabaseTables.goals})');
        final hasCompletedAtColumn =
            columns.any((col) => col['name'] == DatabaseColumns.goalCompletedAt);

        if (!hasCompletedAtColumn) {
          await db.execute('''
            ALTER TABLE ${DatabaseTables.goals}
            ADD COLUMN ${DatabaseColumns.goalCompletedAt} INTEGER
          ''');
          log('Upgraded database to v21: Added completed_at column to goals table.');
        } else {
          log('Skipping v21 migration: completed_at column already exists.');
        }
      }

      if (oldVersion < 22) {
        await db.execute('''
          ALTER TABLE ${DatabaseTables.record}
          ADD COLUMN ${DatabaseColumns.recordGoalId} INTEGER
        ''');
        await db.execute('''
          ALTER TABLE ${DatabaseTables.record}
          ADD COLUMN ${DatabaseColumns.recordRoutineId} INTEGER
        ''');
      }
    } catch (e) {
      log('Error during database upgrade: $e');
      rethrow;
    }
  }

  /// Insert default instructions
  Future<void> _insertDefaultInstructions(Database db) async {
    final defaultInstructions = [
      {'text': 'Summarize my note', 'visibility': 1},
      {'text': 'Translate to turkish', 'visibility': 0},
      {'text': 'Rewrite my note', 'visibility': 0},
    ];

    for (final instruction in defaultInstructions) {
      await db.insert(
        DatabaseTables.instructions,
        {
          DatabaseColumns.instructionText: instruction['text'],
          DatabaseColumns.visibility: instruction['visibility'],
        },
      );
    }
  }

  // Helper methods

  /// Insert a new tag into the database
  Future<int> insert(Map<String, dynamic> row) async {
    try {
      final Database db = await instance.database;
      return await db.insert(DatabaseTables.category, row);
    } catch (e) {
      log('Error inserting tag: $e');
      rethrow;
    }
  }

  /// Update an existing tag
  Future<int> updateTag(int tagId, Map<String, dynamic> row) async {
    try {
      final Database db = await instance.database;
      return await db.update(
        DatabaseTables.category,
        row,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [tagId],
      );
    } catch (e) {
      log('Error updating tag: $e');
      rethrow;
    }
  }

  /// Insert a new record with associated tags
  Future<int> insertRecord(Map<String, dynamic> row, List<int> tagIds) async {
    try {
      final Database db = await instance.database;
      return await db.transaction((txn) async {
        final int recordId = await txn.insert(DatabaseTables.record, row);
        for (final tagId in tagIds) {
          await txn.insert(DatabaseTables.recordTag, {
            'recordId': recordId,
            'tagId': tagId,
          });
        }
        return recordId;
      });
    } catch (e) {
      log('Error inserting record: $e');
      rethrow;
    }
  }

  /// Update an existing record and its associated tags
  Future<int> updateRecord(Map<String, dynamic> row, List<int> tagIds) async {
    try {
      final Database db = await instance.database;
      final int id = row[DatabaseColumns.id];
      return await db.transaction((txn) async {
        await txn.update(
          DatabaseTables.record,
          row,
          where: '${DatabaseColumns.id} = ?',
          whereArgs: [id],
        );

        // Delete old associations
        await txn.delete(
          DatabaseTables.recordTag,
          where: 'recordId = ?',
          whereArgs: [id],
        );

        // Insert new associations
        for (final tagId in tagIds) {
          await txn.insert(DatabaseTables.recordTag, {
            'recordId': id,
            'tagId': tagId,
          });
        }
        return id;
      });
    } catch (e) {
      log('Error updating record: $e');
      rethrow;
    }
  }

  /// Check if a record exists by its ID
  Future<bool> recordExists(int id) async {
    try {
      final Database db = await instance.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseTables.record} WHERE ${DatabaseColumns.id} = ?',
        [id],
      );
      return Sqflite.firstIntValue(result) == 1;
    } catch (e) {
      log('Error checking record existence: $e');
      rethrow;
    }
  }

  /// Get all tags
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    try {
      final Database db = await instance.database;
      return await db.query(DatabaseTables.category);
    } catch (e) {
      log('Error querying all rows: $e');
      rethrow;
    }
  }

  /// Get paginated records
  Future<List<Map<String, dynamic>>> queryRecords(int page) async {
    try {
      final offset = (page - 1) * DatabaseConfig.pageSize;
      final Database db = await instance.database;
      return await db.query(
        DatabaseTables.record,
        limit: DatabaseConfig.pageSize,
        offset: offset,
        orderBy: DatabaseColumns.recordCreatedAt,
      );
    } catch (e) {
      log('Error querying records: $e');
      rethrow;
    }
  }

  /// Get all records
  Future<List<Record>> queryAllRecords() async {
    try {
      final Database db = await instance.database;
      final recordsData = await db.query(
        DatabaseTables.record,
        orderBy: DatabaseColumns.recordCreatedAt,
      );
      return recordsData.map((data) => Record.fromMap(data)).toList();
    } catch (e) {
      log('Error querying all records: $e');
      rethrow;
    }
  }

  /// Get all notes with their associated tags
  Future<List<Map<String, dynamic>>> fetchAllNotes() async {
    try {
      final Database db = await instance.database;
      final List<Map<String, dynamic>> notes = await db.query(DatabaseTables.record);
      final List<Map<String, dynamic>> notesWithTags = [];

      for (final note in notes) {
        final List<Map<String, dynamic>> tags = await db.rawQuery(
          'SELECT t.* FROM ${DatabaseTables.category} t '
          'JOIN ${DatabaseTables.recordTag} rt ON t.${DatabaseColumns.id} = rt.tagId '
          'WHERE rt.recordId = ?',
          [note[DatabaseColumns.id]],
        );

        final Map<String, dynamic> noteWithTags = Map.from(note);
        noteWithTags['tags'] = tags.map((tag) => tag[DatabaseColumns.id]).toList();
        notesWithTags.add(noteWithTags);
      }

      return notesWithTags;
    } catch (e) {
      log('Error fetching all notes: $e');
      rethrow;
    }
  }

  /// Get records filtered by tag and search text
  Future<List<Record>> getRecordsWithTag(
    int? tagId,
    int limit,
    int offset, {
    String? searchText,
  }) async {
    try {
      final Database db = await instance.database;
      final List<dynamic> queryParams = [];

      String query;
      if (tagId != null) {
        // When filtering by specific tag
        query = '''
          SELECT 
            ${DatabaseTables.record}.*,
            GROUP_CONCAT(${DatabaseTables.category}.${DatabaseColumns.id}) AS tags
          FROM ${DatabaseTables.record}
          INNER JOIN ${DatabaseTables.recordTag} ON ${DatabaseTables.record}.${DatabaseColumns.id} = ${DatabaseTables.recordTag}.recordId
          LEFT JOIN ${DatabaseTables.category} ON ${DatabaseTables.recordTag}.tagId = ${DatabaseTables.category}.${DatabaseColumns.id}
          WHERE ${DatabaseTables.recordTag}.tagId = ?
            ${searchText != null && searchText.isNotEmpty ? "AND (${DatabaseColumns.recordText} LIKE ? OR ${DatabaseColumns.recordTitle} LIKE ?)" : ""}
          GROUP BY ${DatabaseTables.record}.${DatabaseColumns.id}
          ORDER BY ${DatabaseTables.record}.${DatabaseColumns.recordCreatedAt} DESC
          LIMIT ? OFFSET ?
        ''';
        queryParams.add(tagId);
      } else {
        // When showing all records (including those without tags)
        query = '''
          SELECT 
            ${DatabaseTables.record}.*,
            GROUP_CONCAT(${DatabaseTables.category}.${DatabaseColumns.id}) AS tags
          FROM ${DatabaseTables.record}
          LEFT JOIN ${DatabaseTables.recordTag} ON ${DatabaseTables.record}.${DatabaseColumns.id} = ${DatabaseTables.recordTag}.recordId
          LEFT JOIN ${DatabaseTables.category} ON ${DatabaseTables.recordTag}.tagId = ${DatabaseTables.category}.${DatabaseColumns.id}
          ${searchText != null && searchText.isNotEmpty ? "WHERE (${DatabaseColumns.recordText} LIKE ? OR ${DatabaseColumns.recordTitle} LIKE ?)" : ""}
          GROUP BY ${DatabaseTables.record}.${DatabaseColumns.id}
          ORDER BY ${DatabaseTables.record}.${DatabaseColumns.recordCreatedAt} DESC
          LIMIT ? OFFSET ?
        ''';
      }

      if (searchText != null && searchText.isNotEmpty) {
        queryParams.add('%$searchText%');
        queryParams.add('%$searchText%');
      }

      queryParams.addAll([limit, offset]);

      final List<Map<String, dynamic>> recordsData = await db.rawQuery(query, queryParams);
      return recordsData.map((data) => Record.fromMap(data)).toList();
    } catch (e) {
      log('Error getting records with tag: $e');
      rethrow;
    }
  }

  /// Get records by their IDs
  Future<List<Record>> getRecordsByIds(String recordIds) async {
    try {
      final Database db = await instance.database;
      final List<Map<String, dynamic>> recordsData = await db.query(
        DatabaseTables.record,
        where: '${DatabaseColumns.id} IN ($recordIds)',
      );
      return recordsData.map((data) => Record.fromMap(data)).toList();
    } catch (e) {
      log('Error getting records by IDs: $e');
      rethrow;
    }
  }

  /// Insert a new instruction
  Future<int> insertInstruction(Instruction instruction) async {
    try {
      final Database db = await instance.database;
      final Map<String, dynamic> row = {
        DatabaseColumns.instructionText: instruction.text,
        DatabaseColumns.visibility: instruction.visibility ? 1 : 0,
      };
      return await db.insert(DatabaseTables.instructions, row);
    } catch (e) {
      log('Error inserting instruction: $e');
      rethrow;
    }
  }

  /// Get all instructions
  Future<List<Instruction>> queryAllInstructions() async {
    try {
      final Database db = await instance.database;
      final List<Map<String, dynamic>> result = await db.query(DatabaseTables.instructions);
      return result.map((map) => Instruction.fromMap(map)).toList();
    } catch (e) {
      log('Error querying all instructions: $e');
      rethrow;
    }
  }

  /// Update an existing instruction
  Future<int> updateInstruction(Instruction instruction) async {
    try {
      final Database db = await instance.database;
      final Map<String, dynamic> row = instruction.toMap();
      return await db.update(
        DatabaseTables.instructions,
        row,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [instruction.id],
      );
    } catch (e) {
      log('Error updating instruction: $e');
      rethrow;
    }
  }

  /// Delete an instruction
  Future<int> deleteInstruction(int id) async {
    try {
      final Database db = await instance.database;
      return await db.delete(
        DatabaseTables.instructions,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log('Error deleting instruction: $e');
      rethrow;
    }
  }

  /// Delete a tag and its associations
  Future<bool> deleteTag(int id) async {
    try {
      final Database db = await instance.database;
      await db.transaction((txn) async {
        await txn.delete(
          DatabaseTables.category,
          where: '${DatabaseColumns.id} = ?',
          whereArgs: [id],
        );
        await txn.delete(
          DatabaseTables.recordTag,
          where: 'tagId = ?',
          whereArgs: [id],
        );
      });
      return true;
    } catch (e) {
      log('Error deleting tag: $e');
      return false;
    }
  }

  /// Delete a record
  Future<int> deleteContact(int id) async {
    try {
      final Database db = await instance.database;
      return await db.delete(
        DatabaseTables.record,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log('Error deleting contact: $e');
      rethrow;
    }
  }

  /// Count total number of records
  Future<int> countRecords() async {
    try {
      final Database db = await instance.database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.record}');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      log('Error counting records: $e');
      rethrow;
    }
  }

  /// Import records from external data
  Future<void> importRecords(dynamic data) async {
    try {
      final Database db = await instance.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.record);
        await txn.delete(DatabaseTables.category);
        await txn.delete(DatabaseTables.recordTag);

        if (data['tags'] != null) {
          for (final tag in data['tags']) {
            await txn.insert(
              DatabaseTables.category,
              {
                DatabaseColumns.id: tag['id'],
                DatabaseColumns.tagName: tag['name'],
                DatabaseColumns.tagColor: tag['color'],
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }

        if (data['notes'] != null) {
          for (final note in data['notes']) {
            // Use text field only (don't combine with title as per user request)
            String noteText = note['text'] ?? '';

            // Prepare the record data with all available fields
            Map<String, dynamic> recordData = {
              DatabaseColumns.id: note['id'],
              DatabaseColumns.recordText: noteText,
              DatabaseColumns.recordCreatedAt: _parseDateToTimestamp(note['created_at']),
            };

            // Preserve additional fields if they exist
            if (note.containsKey('record_type')) {
              recordData[DatabaseColumns.recordType] = note['record_type'];
              print('DEBUG: Importing record with type: ${note['record_type']}');
            } else {
              print('DEBUG: No record_type found in note: ${note.keys.toList()}');
            }
            if (note.containsKey('title')) {
              recordData[DatabaseColumns.recordTitle] = note['title'];
            }
            if (note.containsKey('routine_id')) {
              recordData[DatabaseColumns.recordRoutineId] = note['routine_id'];
            }
            if (note.containsKey('goal_id')) {
              recordData[DatabaseColumns.recordGoalId] = note['goal_id'];
            }

            final int noteId = await txn.insert(
              DatabaseTables.record,
              recordData,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            if (note['tags'] != null) {
              for (final tagId in note['tags']) {
                await txn.insert(
                  DatabaseTables.recordTag,
                  {
                    'recordId': noteId,
                    'tagId': tagId,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }
            }
          }
        }
      });
    } catch (e) {
      log('Error importing records: $e');
      rethrow;
    }
  }

  /// Delete all notes and their associations
  Future<void> deleteAllNotes() async {
    try {
      final Database db = await instance.database;
      await db.transaction((txn) async {
        await txn.delete(DatabaseTables.recordTag);
        await txn.delete(DatabaseTables.record);
      });
    } catch (e) {
      log('Error deleting all notes: $e');
      rethrow;
    }
  }

  /// Parse date string to timestamp
  int _parseDateToTimestamp(dynamic createdAt) {
    if (createdAt is int) {
      return createdAt;
    }

    if (createdAt is String) {
      DateTime parsedDate = DateTime.now();
      final int currentYear = DateTime.now().year;

      try {
        final List<DateFormat> dateFormats = [
          DateFormat("h:mm a"),
          DateFormat("MMM d, yyyy"),
          DateFormat("MMM d, yyyy h:mm a"),
          DateFormat("MMM d"),
        ];

        for (final format in dateFormats) {
          try {
            if (format.pattern == "MMM d") {
              final String dateStringWithYear = "$createdAt, $currentYear";
              parsedDate = DateFormat("MMM d, yyyy").parse(dateStringWithYear);
            } else {
              parsedDate = format.parse(createdAt);
            }
            break;
          } catch (_) {
            continue;
          }
        }
      } catch (e) {
        log('Error parsing date: $e');
      }
      return parsedDate.millisecondsSinceEpoch;
    }

    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Insert a new routine
  Future<int> insertRoutine(Map<String, dynamic> row) async {
    try {
      final Database db = await instance.database;
      return await db.insert(DatabaseTables.routines, row);
    } catch (e) {
      log('Error inserting routine: $e');
      rethrow;
    }
  }

  /// Update an existing routine
  Future<int> updateRoutine(int id, Map<String, dynamic> row) async {
    try {
      final Database db = await instance.database;
      return await db.update(
        DatabaseTables.routines,
        row,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log('Error updating routine: $e');
      rethrow;
    }
  }

  /// Delete a routine
  Future<int> deleteRoutine(int id) async {
    try {
      final Database db = await instance.database;
      return await db.delete(
        DatabaseTables.routines,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log('Error deleting routine: $e');
      rethrow;
    }
  }

  /// Delete all routines
  Future<int> deleteAllRoutines() async {
    try {
      final Database db = await instance.database;
      return await db.delete(DatabaseTables.routines);
    } catch (e) {
      log('Error deleting all routines: $e');
      rethrow;
    }
  }

  /// Get all routines
  Future<List<Map<String, dynamic>>> getAllRoutines() async {
    try {
      final Database db = await instance.database;
      return await db.query(
        DatabaseTables.routines,
        orderBy: '${DatabaseColumns.routineIsDone} ASC, ${DatabaseColumns.routineTime} ASC',
      );
    } catch (e) {
      log('Error getting all routines: $e');
      rethrow;
    }
  }

  /// Mark routine as done/undone
  Future<int> toggleRoutineDone(int id, bool isDone) async {
    try {
      final Database db = await instance.database;
      return await db.update(
        DatabaseTables.routines,
        {DatabaseColumns.routineIsDone: isDone ? 1 : 0},
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      log('Error toggling routine done status: $e');
      rethrow;
    }
  }

  /// Reset all routines' done status to false
  Future<void> resetRoutinesDoneStatus() async {
    try {
      final Database db = await instance.database;
      await db.update(
        DatabaseTables.routines,
        {DatabaseColumns.routineIsDone: 0},
      );
    } catch (e) {
      log('Error resetting routines done status: $e');
      rethrow;
    }
  }

  // Goal CRUD operations
  Future<int> insertGoal(Goal goal) async {
    try {
      final db = await database;
      return await db.insert(DatabaseTables.goals, goal.toMap());
    } catch (e) {
      log('Error inserting goal: $e');
      rethrow;
    }
  }

  Future<List<Goal>> getAllGoals() async {
    final db = await database;
    final maps = await db.query(DatabaseTables.goals);
    return maps.map((map) => Goal.fromMap(map)).toList();
  }

  Future<Goal?> getGoal(int id) async {
    final db = await database;
    final maps = await db.query(
      DatabaseTables.goals,
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Goal.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await database;
    return await db.update(
      DatabaseTables.goals,
      goal.toMap(),
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return await db.delete(
      DatabaseTables.goals,
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [id],
    );
  }

  /// Delete all goals
  Future<int> deleteAllGoals() async {
    try {
      final db = await database;
      return await db.delete(DatabaseTables.goals);
    } catch (e) {
      log('Error deleting all goals: $e');
      rethrow;
    }
  }

  Future<Goal?> getActiveGoal() async {
    final db = await database;
    final maps = await db.query(
      DatabaseTables.goals,
      where: '${DatabaseColumns.goalIsActive} = ?',
      whereArgs: [1],
    );
    if (maps.isNotEmpty) {
      return Goal.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Record>> getNewerRecords(int lastTimestamp, {int? tagId, String? searchText}) async {
    final db = await database;
    String whereClause = '${DatabaseColumns.recordCreatedAt} > ?';
    List<dynamic> whereArgs = [lastTimestamp];

    if (searchText != null && searchText.isNotEmpty) {
      whereClause +=
          ' AND ${DatabaseColumns.recordText} LIKE ? OR ${DatabaseColumns.recordTitle} LIKE ?';
      whereArgs.add('%$searchText%');
      whereArgs.add('%$searchText%');
    }

    List<Map<String, dynamic>> recordsData;

    if (tagId != null) {
      // If a tag is specified, we need a more complex query to join tables
      recordsData = await db.rawQuery('''
      SELECT T1.* FROM ${DatabaseTables.record} AS T1
      INNER JOIN ${DatabaseTables.recordTag} AS T2 ON T1._id = T2.recordId
      WHERE T2.tagId = ? AND T1.${DatabaseColumns.recordCreatedAt} > ?
      ${(searchText != null && searchText.isNotEmpty) ? 'AND (T1.${DatabaseColumns.recordText} LIKE ? OR T1.${DatabaseColumns.recordTitle} LIKE ?)' : ''}
      ORDER BY T1.${DatabaseColumns.recordCreatedAt} DESC
    ''', [
        tagId,
        lastTimestamp,
        if (searchText != null && searchText.isNotEmpty) '%$searchText%',
        if (searchText != null && searchText.isNotEmpty) '%$searchText%'
      ]);
    } else {
      // Query without tag filter
      recordsData = await db.query(
        DatabaseTables.record,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      );
    }

    final records = recordsData.map((data) => Record.fromMap(data)).toList();

    // For each record, fetch its associated tags
    for (var record in records) {
      final tagsData = await db.query(
        DatabaseTables.recordTag,
        columns: ['tagId'],
        where: 'recordId = ?',
        whereArgs: [record.id],
      );
      record.tagIds = tagsData.map((tag) => tag['tagId'] as int).toList();
    }

    return records;
  }
}
