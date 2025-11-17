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
  static const int databaseVersion = 27;
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
  static const String aiInterestSignals = 'ai_interest_signals';
  static const String aiContextSummaries = 'ai_context_summaries';
  static const String aiInsights = 'ai_insights';
  static const String appSettings = 'app_settings';
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
  static const String routineStreak = 'streak';
  static const String routineLastCompletedDate = 'last_completed_date';
  static const String routineShowStreak = 'show_streak';
  static const String routinePreviousStreak = 'previous_streak';
  static const String routinePreviousLastCompletedDate = 'previous_last_completed_date';

  // Goal table columns
  static const String goalTitle = 'title';
  static const String goalHours = 'hours';
  static const String goalMinutes = 'minutes';
  static const String goalSessionMinutes = 'session_minutes';
  static const String goalIsActive = 'is_active';
  static const String goalTimeSpentSeconds = 'time_spent_seconds';
  static const String goalSessionResumedTimestampSeconds = 'session_resumed_timestamp_seconds';
  static const String goalCompletedAt = 'completed_at';
  static const String goalIsPrimary = 'is_primary';
  static const String goalCreatedFromOnboarding = 'created_from_onboarding';

  // AI interest signals columns
  static const String aiSource = 'source';
  static const String aiSourceId = 'source_id';
  static const String aiTopic = 'topic';
  static const String aiIntent = 'intent';
  static const String aiConfidence = 'confidence';
  static const String aiCreatedAt = 'created_at';

  // AI context summaries columns
  static const String aiScope = 'scope';
  static const String aiSummary = 'summary';
  static const String aiPeriodStart = 'period_start';
  static const String aiPeriodEnd = 'period_end';
  static const String aiTokens = 'tokens';

  // AI insights columns
  static const String insightTitle = 'title';
  static const String insightBody = 'body';
  static const String insightTags = 'tags';
  static const String insightScore = 'score';
  static const String insightUrgency = 'urgency';
  static const String insightSourceContextHash = 'source_context_hash';
  static const String insightDeliveredAs = 'delivered_as';
  static const String insightDeliveredAt = 'delivered_at';
  static const String insightDismissedAt = 'dismissed_at';
  static const String insightExpiresAt = 'expires_at';

  // App settings columns
  static const String settingInsightEnabled = 'insight_enabled';
  static const String settingInsightIntervalMinutes = 'insight_interval_minutes';
  static const String settingInsightContextDays = 'insight_context_days';
  static const String settingInsightTokenLimit = 'insight_token_limit';
  static const String settingQuietHoursStart = 'quiet_hours_start';
  static const String settingQuietHoursEnd = 'quiet_hours_end';
  static const String settingPrimaryGoalId = 'primary_goal_id';
  static const String settingMainIntentionText = 'main_intention_text';
  static const String settingLastBackgroundRunAt = 'last_background_run_at';
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

  /// Initialize the database with backup verification
  Future<Database> _initDatabase() async {
    try {
      final Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final String path = join(documentsDirectory.path, DatabaseConfig.databaseName);

      // 🎯 DATA PROTECTION: Log database info for debugging
      log('📍 Database path: $path');

      // Check if database file exists and log its size
      final File dbFile = File(path);
      if (await dbFile.exists()) {
        final int size = await dbFile.length();
        final DateTime modified = await dbFile.lastModified();
        log('📊 Existing database found: ${size} bytes, last modified: $modified');
      } else {
        log('🆕 Creating new database at: $path');
      }

      final database = await openDatabase(
        path,
        version: DatabaseConfig.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );

      // 🎯 VERIFICATION: Check data integrity after opening
      await _verifyDataIntegrity(database);

      return database;
    } catch (e) {
      log('❌ Error initializing database: $e');
      rethrow;
    }
  }

  /// Verify data integrity when opening database
  Future<void> _onOpen(Database db) async {
    log('🔓 Database opened successfully');
  }

  /// Verify data integrity and log recent records
  Future<void> _verifyDataIntegrity(Database db) async {
    try {
      // Count records
      final List<Map<String, dynamic>> recordCount =
          await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.record}');
      final int totalRecords = recordCount.first['count'] as int;

      // Get most recent records
      final List<Map<String, dynamic>> recentRecords = await db
          .rawQuery('SELECT ${DatabaseColumns.recordCreatedAt}, ${DatabaseColumns.recordTitle} '
              'FROM ${DatabaseTables.record} '
              'ORDER BY ${DatabaseColumns.recordCreatedAt} DESC LIMIT 5');

      log('📊 DATABASE VERIFICATION:');
      log('   Total records: $totalRecords');

      if (recentRecords.isNotEmpty) {
        log('   Recent records:');
        for (final record in recentRecords) {
          final DateTime created =
              DateTime.fromMillisecondsSinceEpoch(record[DatabaseColumns.recordCreatedAt] as int);
          final String title = record[DatabaseColumns.recordTitle] ?? 'No title';
          log('     - ${DateFormat('yyyy-MM-dd HH:mm:ss').format(created)}: ${title.substring(0, title.length > 30 ? 30 : title.length)}${title.length > 30 ? '...' : ''}');
        }
      } else {
        log('   No records found');
      }

      // Check for recent data (within last 7 days)
      final DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final List<Map<String, dynamic>> recentCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM ${DatabaseTables.record} '
          'WHERE ${DatabaseColumns.recordCreatedAt} > ?',
          [sevenDaysAgo.millisecondsSinceEpoch]);
      final int recentRecordCount = recentCount.first['count'] as int;

      log('   Records from last 7 days: $recentRecordCount');

      if (recentRecordCount == 0 && totalRecords > 0) {
        log('⚠️  WARNING: No recent records found but old records exist - possible backup restore!');
      }
    } catch (e) {
      log('❌ Error during data verification: $e');
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
          ${DatabaseColumns.routineIsDone} INTEGER NOT NULL DEFAULT 0,
          ${DatabaseColumns.routineStreak} INTEGER NOT NULL DEFAULT 0,
          ${DatabaseColumns.routineLastCompletedDate} TEXT,
          ${DatabaseColumns.routineShowStreak} INTEGER NOT NULL DEFAULT 1,
          ${DatabaseColumns.routinePreviousStreak} INTEGER,
          ${DatabaseColumns.routinePreviousLastCompletedDate} TEXT
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
          ${DatabaseColumns.goalCompletedAt} INTEGER,
          ${DatabaseColumns.goalIsPrimary} INTEGER NOT NULL DEFAULT 0,
          ${DatabaseColumns.goalCreatedFromOnboarding} INTEGER NOT NULL DEFAULT 0
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

      // Create app settings table (singleton row)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.appSettings} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseColumns.settingInsightEnabled} INTEGER NOT NULL DEFAULT 1,
          ${DatabaseColumns.settingInsightIntervalMinutes} INTEGER NOT NULL DEFAULT 60,
          ${DatabaseColumns.settingInsightContextDays} INTEGER NOT NULL DEFAULT 7,
          ${DatabaseColumns.settingInsightTokenLimit} INTEGER NOT NULL DEFAULT 4000,
          ${DatabaseColumns.settingQuietHoursStart} TEXT,
          ${DatabaseColumns.settingQuietHoursEnd} TEXT,
          ${DatabaseColumns.settingPrimaryGoalId} INTEGER,
          ${DatabaseColumns.settingMainIntentionText} TEXT,
          ${DatabaseColumns.settingLastBackgroundRunAt} INTEGER
        )
      ''');

      // Ensure a default settings row exists
      final countSettings =
          await db.rawQuery('SELECT COUNT(*) as c FROM ${DatabaseTables.appSettings}');
      final settingsCount = countSettings.first['c'] as int? ?? 0;
      if (settingsCount == 0) {
        await db.insert(DatabaseTables.appSettings, {
          DatabaseColumns.settingInsightEnabled: 1,
          DatabaseColumns.settingInsightIntervalMinutes: 60,
          DatabaseColumns.settingInsightContextDays: 7,
          DatabaseColumns.settingInsightTokenLimit: 4000,
          DatabaseColumns.settingQuietHoursStart: null,
          DatabaseColumns.settingQuietHoursEnd: null,
          DatabaseColumns.settingPrimaryGoalId: null,
        });
      }

      // Create AI interest signals table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.aiInterestSignals} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseColumns.aiSource} TEXT NOT NULL,
          ${DatabaseColumns.aiSourceId} TEXT,
          ${DatabaseColumns.aiTopic} TEXT NOT NULL,
          ${DatabaseColumns.aiIntent} TEXT,
          ${DatabaseColumns.aiConfidence} REAL,
          ${DatabaseColumns.aiCreatedAt} INTEGER NOT NULL
        )
      ''');

      // Create AI context summaries table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.aiContextSummaries} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseColumns.aiScope} TEXT NOT NULL,
          ${DatabaseColumns.aiSummary} TEXT NOT NULL,
          ${DatabaseColumns.aiPeriodStart} INTEGER,
          ${DatabaseColumns.aiPeriodEnd} INTEGER,
          ${DatabaseColumns.aiTokens} INTEGER,
          ${DatabaseColumns.aiCreatedAt} INTEGER NOT NULL
        )
      ''');

      // Create AI insights table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.aiInsights} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseColumns.insightTitle} TEXT NOT NULL,
          ${DatabaseColumns.insightBody} TEXT NOT NULL,
          ${DatabaseColumns.insightTags} TEXT,
          ${DatabaseColumns.insightScore} REAL,
          ${DatabaseColumns.insightUrgency} TEXT,
          ${DatabaseColumns.insightSourceContextHash} TEXT UNIQUE,
          ${DatabaseColumns.insightDeliveredAs} TEXT,
          ${DatabaseColumns.insightDeliveredAt} INTEGER,
          ${DatabaseColumns.insightDismissedAt} INTEGER,
          ${DatabaseColumns.insightExpiresAt} INTEGER
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

      if (oldVersion < 23) {
        // Add streak tracking columns to routines table
        await db.execute('''
          ALTER TABLE ${DatabaseTables.routines}
          ADD COLUMN ${DatabaseColumns.routineStreak} INTEGER NOT NULL DEFAULT 0
        ''');
        await db.execute('''
          ALTER TABLE ${DatabaseTables.routines}
          ADD COLUMN ${DatabaseColumns.routineLastCompletedDate} TEXT
        ''');
        await db.execute('''
          ALTER TABLE ${DatabaseTables.routines}
          ADD COLUMN ${DatabaseColumns.routineShowStreak} INTEGER NOT NULL DEFAULT 1
        ''');

        // ONE-TIME: Calculate streaks for existing routines based on completion history
        log('Calculating streaks for existing routines...');
        final routines = await db.query(DatabaseTables.routines);
        for (var routine in routines) {
          final routineId = routine[DatabaseColumns.id] as int;
          await _calculateAndUpdateStreakForMigration(db, routineId);
        }

        log('Upgraded database to v23: Added streak tracking columns and calculated existing streaks.');
      }

      if (oldVersion < 24) {
        // Add previous state columns for undo functionality when unchecking routines
        await db.execute('''
          ALTER TABLE ${DatabaseTables.routines}
          ADD COLUMN ${DatabaseColumns.routinePreviousStreak} INTEGER
        ''');
        await db.execute('''
          ALTER TABLE ${DatabaseTables.routines}
          ADD COLUMN ${DatabaseColumns.routinePreviousLastCompletedDate} TEXT
        ''');

        // Recalculate all streaks using scheduled-day logic
        log('Recalculating routine streaks with scheduled-day logic...');
        final routines = await db.query(DatabaseTables.routines);
        for (var routine in routines) {
          final routineId = routine[DatabaseColumns.id] as int;
          await _calculateAndUpdateStreakWithScheduledDays(db, routineId);
        }

        log('Upgraded database to v24: Added previous state columns and recalculated streaks with scheduled-day logic.');
      }

      if (oldVersion < 25) {
        // Goals: add is_primary and created_from_onboarding if missing
        final goalColumns = await db.rawQuery('PRAGMA table_info(${DatabaseTables.goals})');
        final hasIsPrimary = goalColumns.any((c) => c['name'] == DatabaseColumns.goalIsPrimary);
        final hasCreatedFrom =
            goalColumns.any((c) => c['name'] == DatabaseColumns.goalCreatedFromOnboarding);
        if (!hasIsPrimary) {
          await db.execute('''
            ALTER TABLE ${DatabaseTables.goals}
            ADD COLUMN ${DatabaseColumns.goalIsPrimary} INTEGER NOT NULL DEFAULT 0
          ''');
        }
        if (!hasCreatedFrom) {
          await db.execute('''
            ALTER TABLE ${DatabaseTables.goals}
            ADD COLUMN ${DatabaseColumns.goalCreatedFromOnboarding} INTEGER NOT NULL DEFAULT 0
          ''');
        }

        // Create app_settings if not exists
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DatabaseTables.appSettings} (
            ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseColumns.settingInsightEnabled} INTEGER NOT NULL DEFAULT 1,
            ${DatabaseColumns.settingInsightIntervalMinutes} INTEGER NOT NULL DEFAULT 60,
            ${DatabaseColumns.settingInsightContextDays} INTEGER NOT NULL DEFAULT 7,
            ${DatabaseColumns.settingInsightTokenLimit} INTEGER NOT NULL DEFAULT 4000,
            ${DatabaseColumns.settingQuietHoursStart} TEXT,
            ${DatabaseColumns.settingQuietHoursEnd} TEXT,
            ${DatabaseColumns.settingPrimaryGoalId} INTEGER
          )
        ''');
        // Ensure a default settings row exists
        final countSettings =
            await db.rawQuery('SELECT COUNT(*) as c FROM ${DatabaseTables.appSettings}');
        final settingsCount = countSettings.first['c'] as int? ?? 0;
        if (settingsCount == 0) {
          await db.insert(DatabaseTables.appSettings, {
            DatabaseColumns.settingInsightEnabled: 1,
            DatabaseColumns.settingInsightIntervalMinutes: 60,
            DatabaseColumns.settingInsightContextDays: 7,
            DatabaseColumns.settingInsightTokenLimit: 4000,
            DatabaseColumns.settingQuietHoursStart: null,
            DatabaseColumns.settingQuietHoursEnd: null,
            DatabaseColumns.settingPrimaryGoalId: null,
          });
        }

        // AI tables
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DatabaseTables.aiInterestSignals} (
            ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseColumns.aiSource} TEXT NOT NULL,
            ${DatabaseColumns.aiSourceId} TEXT,
            ${DatabaseColumns.aiTopic} TEXT NOT NULL,
            ${DatabaseColumns.aiIntent} TEXT,
            ${DatabaseColumns.aiConfidence} REAL,
            ${DatabaseColumns.aiCreatedAt} INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DatabaseTables.aiContextSummaries} (
            ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseColumns.aiScope} TEXT NOT NULL,
            ${DatabaseColumns.aiSummary} TEXT NOT NULL,
            ${DatabaseColumns.aiPeriodStart} INTEGER,
            ${DatabaseColumns.aiPeriodEnd} INTEGER,
            ${DatabaseColumns.aiTokens} INTEGER,
            ${DatabaseColumns.aiCreatedAt} INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${DatabaseTables.aiInsights} (
            ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseColumns.insightTitle} TEXT NOT NULL,
            ${DatabaseColumns.insightBody} TEXT NOT NULL,
            ${DatabaseColumns.insightTags} TEXT,
            ${DatabaseColumns.insightScore} REAL,
            ${DatabaseColumns.insightUrgency} TEXT,
            ${DatabaseColumns.insightSourceContextHash} TEXT UNIQUE,
            ${DatabaseColumns.insightDeliveredAs} TEXT,
            ${DatabaseColumns.insightDeliveredAt} INTEGER,
            ${DatabaseColumns.insightDismissedAt} INTEGER,
            ${DatabaseColumns.insightExpiresAt} INTEGER
          )
        ''');

        log('Upgraded database to v25: Added AI tables, app settings, and goal flags.');
      }

      if (oldVersion < 26) {
        // Add main_intention_text column for storing onboarding primary text
        await db.execute('''
          ALTER TABLE ${DatabaseTables.appSettings}
          ADD COLUMN ${DatabaseColumns.settingMainIntentionText} TEXT
        ''');
        log('Upgraded database to v26: Added main_intention_text to app_settings.');
      }

      if (oldVersion < 27) {
        // Add last_background_run_at column for tracking background task execution
        await db.execute('''
          ALTER TABLE ${DatabaseTables.appSettings}
          ADD COLUMN ${DatabaseColumns.settingLastBackgroundRunAt} INTEGER
        ''');
        log('Upgraded database to v27: Added last_background_run_at to app_settings.');
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

  /// Find the previous scheduled occurrence date for a routine
  /// Returns null if no scheduled day found in the past week
  DateTime? _findPreviousScheduledOccurrence(DateTime date, List<bool> daysOfWeek) {
    // Start from yesterday and look backwards up to 7 days
    DateTime checkDate =
        DateTime(date.year, date.month, date.day).subtract(const Duration(days: 1));

    for (int i = 0; i < 7; i++) {
      int dayIndex = checkDate.weekday - 1; // Convert to 0-based (Monday=0)
      if (daysOfWeek[dayIndex]) {
        return checkDate;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // No scheduled day found (should not happen if at least one day is active)
    return null;
  }

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
    bool? showGoalRecords,
    bool? showRoutineRecords,
  }) async {
    try {
      final Database db = await instance.database;
      final List<dynamic> queryParams = [];

      // Build type filter conditions
      List<String> typeFilters = [];
      if (showGoalRecords == false && showRoutineRecords == false) {
        // If both are false, show only regular records (no goal_id and no routine_id)
        typeFilters.add("${DatabaseTables.record}.${DatabaseColumns.recordGoalId} IS NULL");
        typeFilters.add("${DatabaseTables.record}.${DatabaseColumns.recordRoutineId} IS NULL");
      } else if (showGoalRecords == false) {
        // Hide goal records
        typeFilters.add("${DatabaseTables.record}.${DatabaseColumns.recordGoalId} IS NULL");
      } else if (showRoutineRecords == false) {
        // Hide routine records
        typeFilters.add("${DatabaseTables.record}.${DatabaseColumns.recordRoutineId} IS NULL");
      }
      // If both are true or null, show all records (no additional filtering)

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
            ${typeFilters.isNotEmpty ? "AND (${typeFilters.join(" AND ")})" : ""}
          GROUP BY ${DatabaseTables.record}.${DatabaseColumns.id}
          ORDER BY ${DatabaseTables.record}.${DatabaseColumns.recordCreatedAt} DESC
          LIMIT ? OFFSET ?
        ''';
        queryParams.add(tagId);
      } else {
        // When showing all records (including those without tags)
        final whereConditions = <String>[];

        if (searchText != null && searchText.isNotEmpty) {
          whereConditions.add(
              "(${DatabaseColumns.recordText} LIKE ? OR ${DatabaseColumns.recordTitle} LIKE ?)");
        }

        if (typeFilters.isNotEmpty) {
          whereConditions.add("(${typeFilters.join(" AND ")})");
        }

        query = '''
          SELECT
            ${DatabaseTables.record}.*,
            GROUP_CONCAT(${DatabaseTables.category}.${DatabaseColumns.id}) AS tags
          FROM ${DatabaseTables.record}
          LEFT JOIN ${DatabaseTables.recordTag} ON ${DatabaseTables.record}.${DatabaseColumns.id} = ${DatabaseTables.recordTag}.recordId
          LEFT JOIN ${DatabaseTables.category} ON ${DatabaseTables.recordTag}.tagId = ${DatabaseTables.category}.${DatabaseColumns.id}
          ${whereConditions.isNotEmpty ? "WHERE ${whereConditions.join(" AND ")}" : ""}
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
      log('🔍 Filter applied - showGoals: $showGoalRecords, showRoutines: $showRoutineRecords, results: ${recordsData.length}');
      return recordsData.map((data) => Record.fromMap(data)).toList();
    } catch (e) {
      log('Error getting records with tag: $e');
      rethrow;
    }
  }

  /// Get records by multiple tag IDs (returns records that have ANY of the specified tags)
  Future<List<Record>> getRecordsByMultipleTags(List<int> tagIds) async {
    try {
      if (tagIds.isEmpty) {
        return [];
      }

      final Database db = await instance.database;

      // Create placeholders for the IN clause
      final String placeholders = List.filled(tagIds.length, '?').join(',');

      final query = '''
        SELECT DISTINCT
          ${DatabaseTables.record}.*,
          GROUP_CONCAT(${DatabaseTables.category}.${DatabaseColumns.id}) AS tags
        FROM ${DatabaseTables.record}
        INNER JOIN ${DatabaseTables.recordTag} ON ${DatabaseTables.record}.${DatabaseColumns.id} = ${DatabaseTables.recordTag}.recordId
        LEFT JOIN ${DatabaseTables.category} ON ${DatabaseTables.recordTag}.tagId = ${DatabaseTables.category}.${DatabaseColumns.id}
        WHERE ${DatabaseTables.recordTag}.tagId IN ($placeholders)
        GROUP BY ${DatabaseTables.record}.${DatabaseColumns.id}
        ORDER BY ${DatabaseTables.record}.${DatabaseColumns.recordCreatedAt} DESC
      ''';

      final List<Map<String, dynamic>> recordsData = await db.rawQuery(query, tagIds);
      log('🔍 getRecordsByMultipleTags - Found ${recordsData.length} records for tags: $tagIds');
      return recordsData.map((data) => Record.fromMap(data)).toList();
    } catch (e) {
      log('Error getting records by multiple tags: $e');
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

  /// Get records by routine ID
  Future<List<Map<String, dynamic>>> getRecordsByRoutineId(int routineId) async {
    try {
      final Database db = await instance.database;
      return await db.query(
        DatabaseTables.record,
        where: '${DatabaseColumns.recordRoutineId} = ?',
        whereArgs: [routineId],
        orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      );
    } catch (e) {
      log('Error getting records by routine ID: $e');
      rethrow;
    }
  }

  /// Internal helper for migration: Calculate and update streak for a routine
  Future<void> _calculateAndUpdateStreakForMigration(Database db, int routineId) async {
    try {
      final records = await db.query(
        DatabaseTables.record,
        where: '${DatabaseColumns.recordRoutineId} = ?',
        whereArgs: [routineId],
        orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      );

      if (records.isEmpty) {
        // No completions, keep default streak of 0
        return;
      }

      // Get completion dates (normalized to date only, no time)
      final Set<String> completionDates = {};
      for (var record in records) {
        final timestamp = record[DatabaseColumns.recordCreatedAt] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        completionDates.add(dateStr);
      }

      // Sort dates in descending order
      final sortedDates = completionDates.toList()..sort((a, b) => b.compareTo(a));

      // Get the most recent completion date
      final lastCompletedDate = sortedDates.first;
      final lastDate = DateTime.parse(lastCompletedDate);
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));

      // Calculate streak
      int streak = 0;

      // Only count streak if last completion was today or yesterday
      if (lastCompletedDate == todayStr || lastCompletedDate == yesterdayStr) {
        // Start from the most recent date and count backwards
        DateTime checkDate = lastDate;

        for (int i = 0; i < sortedDates.length; i++) {
          final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);

          if (completionDates.contains(dateStr)) {
            streak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            // Gap found, stop counting
            break;
          }
        }
      }

      // Update the routine
      await db.update(
        DatabaseTables.routines,
        {
          DatabaseColumns.routineStreak: streak,
          DatabaseColumns.routineLastCompletedDate: lastCompletedDate,
        },
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [routineId],
      );

      log('Migration: Updated routine $routineId: streak=$streak, lastCompleted=$lastCompletedDate');
    } catch (e) {
      log('Error calculating routine streak during migration: $e');
      // Don't rethrow during migration - continue with other routines
    }
  }

  /// Calculate streak respecting scheduled days of week (for v24+ migration)
  Future<void> _calculateAndUpdateStreakWithScheduledDays(Database db, int routineId) async {
    try {
      // Get routine data to access days_of_week
      final routineData = await db.query(
        DatabaseTables.routines,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [routineId],
      );

      if (routineData.isEmpty) {
        return;
      }

      final routine = routineData.first;
      final daysOfWeekString = routine[DatabaseColumns.routineDaysOfWeek] as String;
      final daysOfWeek = daysOfWeekString.split(',').map((day) => day == '1').toList();

      // Get completion records
      final records = await db.query(
        DatabaseTables.record,
        where: '${DatabaseColumns.recordRoutineId} = ?',
        whereArgs: [routineId],
        orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      );

      if (records.isEmpty) {
        // No completions, keep default streak of 0
        return;
      }

      // Get completion dates (normalized to date only, no time)
      final Set<String> completionDates = {};
      for (var record in records) {
        final timestamp = record[DatabaseColumns.recordCreatedAt] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        completionDates.add(dateStr);
      }

      // Sort dates in descending order
      final sortedDates = completionDates.toList()..sort((a, b) => b.compareTo(a));

      // Get the most recent completion date
      final lastCompletedDate = sortedDates.first;
      DateTime mostRecentDate = DateTime.parse(lastCompletedDate);

      // Calculate streak using scheduled days
      int streak = 1; // Start with 1 for the most recent completion
      DateTime currentDate = mostRecentDate;

      // Count backwards through scheduled occurrences
      while (true) {
        final previousScheduled = _findPreviousScheduledOccurrence(currentDate, daysOfWeek);
        if (previousScheduled == null) {
          // No more scheduled days to check
          break;
        }

        final prevDateStr = DateFormat('yyyy-MM-dd').format(previousScheduled);
        if (completionDates.contains(prevDateStr)) {
          // Previous scheduled occurrence was completed, continue streak
          streak++;
          currentDate = previousScheduled;
        } else {
          // Streak broken - previous scheduled day was not completed
          break;
        }
      }

      // Update the routine
      await db.update(
        DatabaseTables.routines,
        {
          DatabaseColumns.routineStreak: streak,
          DatabaseColumns.routineLastCompletedDate: lastCompletedDate,
        },
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [routineId],
      );

      log('Migration v24: Updated routine $routineId with scheduled-day streak: $streak, lastCompleted=$lastCompletedDate');
    } catch (e) {
      log('Error calculating routine streak with scheduled days during migration: $e');
      // Don't rethrow during migration - continue with other routines
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
              log('DEBUG: Importing record with type: ${note['record_type']}');
            } else {
              log('DEBUG: No record_type found in note: ${note.keys.toList()}');
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

  /// Mark routine as done/undone with streak tracking
  Future<int> toggleRoutineDone(int id, bool isDone) async {
    try {
      final Database db = await instance.database;

      if (isDone) {
        // Get current routine data
        final List<Map<String, dynamic>> routineData = await db.query(
          DatabaseTables.routines,
          where: '${DatabaseColumns.id} = ?',
          whereArgs: [id],
        );

        if (routineData.isEmpty) {
          throw Exception('Routine not found');
        }

        final currentRoutine = routineData.first;
        final String? lastCompletedDate =
            currentRoutine[DatabaseColumns.routineLastCompletedDate] as String?;
        final int currentStreak = currentRoutine[DatabaseColumns.routineStreak] as int? ?? 0;
        final String daysOfWeekString = currentRoutine[DatabaseColumns.routineDaysOfWeek] as String;
        final List<bool> daysOfWeek = daysOfWeekString.split(',').map((day) => day == '1').toList();

        // Calculate new streak using scheduled-day logic
        final DateTime now = DateTime.now();
        final String today = DateFormat('yyyy-MM-dd').format(now);
        int newStreak = 1;

        if (lastCompletedDate == today) {
          // Already completed today - keep current streak (same-day re-completion)
          newStreak = currentStreak;
        } else if (lastCompletedDate != null) {
          // Find the previous scheduled occurrence before today
          final DateTime? previousScheduled = _findPreviousScheduledOccurrence(
            DateTime(now.year, now.month, now.day),
            daysOfWeek,
          );

          if (previousScheduled != null) {
            final String previousScheduledStr = DateFormat('yyyy-MM-dd').format(previousScheduled);

            // If the previous scheduled day was completed, increment streak
            if (lastCompletedDate == previousScheduledStr) {
              newStreak = currentStreak + 1;
            }
            // Otherwise, streak resets to 1 (already set above)
          }
        }

        // Update routine with new streak data, saving previous state for undo
        return await db.update(
          DatabaseTables.routines,
          {
            DatabaseColumns.routineIsDone: 1,
            DatabaseColumns.routineStreak: newStreak,
            DatabaseColumns.routineLastCompletedDate: today,
            // Save previous state for potential undo on same day
            DatabaseColumns.routinePreviousStreak: currentStreak,
            DatabaseColumns.routinePreviousLastCompletedDate: lastCompletedDate,
          },
          where: '${DatabaseColumns.id} = ?',
          whereArgs: [id],
        );
      } else {
        // Get current routine data to check if we should restore previous state
        final List<Map<String, dynamic>> routineData = await db.query(
          DatabaseTables.routines,
          where: '${DatabaseColumns.id} = ?',
          whereArgs: [id],
        );

        if (routineData.isEmpty) {
          throw Exception('Routine not found');
        }

        final currentRoutine = routineData.first;
        final String? lastCompletedDate =
            currentRoutine[DatabaseColumns.routineLastCompletedDate] as String?;
        final DateTime now = DateTime.now();
        final String today = DateFormat('yyyy-MM-dd').format(now);

        // Check if the routine was completed today - if so, restore previous state
        if (lastCompletedDate == today) {
          // Restore previous state to undo accidental check
          final int? previousStreak = currentRoutine[DatabaseColumns.routinePreviousStreak] as int?;
          final String? previousLastCompletedDate =
              currentRoutine[DatabaseColumns.routinePreviousLastCompletedDate] as String?;

          return await db.update(
            DatabaseTables.routines,
            {
              DatabaseColumns.routineIsDone: 0,
              DatabaseColumns.routineStreak: previousStreak ?? 0,
              DatabaseColumns.routineLastCompletedDate: previousLastCompletedDate,
              // Clear previous state after restoring
              DatabaseColumns.routinePreviousStreak: null,
              DatabaseColumns.routinePreviousLastCompletedDate: null,
            },
            where: '${DatabaseColumns.id} = ?',
            whereArgs: [id],
          );
        } else {
          // Not unchecking on the same day, just update isDone status
          return await db.update(
            DatabaseTables.routines,
            {DatabaseColumns.routineIsDone: 0},
            where: '${DatabaseColumns.id} = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (e) {
      log('Error toggling routine done status: $e');
      rethrow;
    }
  }

  /// Backdate a routine completion for a specific date
  /// Returns the created record ID on success, throws an error on failure
  Future<int> backdateRoutineCompletion(int routineId, DateTime completionDate) async {
    try {
      final Database db = await instance.database;

      // Get routine data
      final List<Map<String, dynamic>> routineData = await db.query(
        DatabaseTables.routines,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [routineId],
      );

      if (routineData.isEmpty) {
        throw Exception('Routine not found');
      }

      final currentRoutine = routineData.first;
      final String routineName = currentRoutine[DatabaseColumns.routineName] as String;
      final String daysOfWeekString = currentRoutine[DatabaseColumns.routineDaysOfWeek] as String;
      final List<bool> daysOfWeek = daysOfWeekString.split(',').map((day) => day == '1').toList();

      // Normalize completion date to midnight
      final DateTime normalizedDate =
          DateTime(completionDate.year, completionDate.month, completionDate.day);
      final int dayIndex = normalizedDate.weekday - 1; // Convert to 0-based index

      // Validate: Check if routine is scheduled for this day
      if (!daysOfWeek[dayIndex]) {
        throw Exception('Routine is not scheduled for this day of the week');
      }

      // Validate: Check if date is in the past (not today or future)
      final DateTime today = DateTime.now();
      final DateTime todayNormalized = DateTime(today.year, today.month, today.day);
      if (normalizedDate.isAfter(todayNormalized) ||
          normalizedDate.isAtSameMomentAs(todayNormalized)) {
        throw Exception('Can only backdate to past dates');
      }

      // No time limit on backdating - users can backdate to any past date

      // TODO: Uncomment to enable backtracking limit (14 days)
      // final int daysDifference = todayNormalized.difference(normalizedDate).inDays;
      // if (daysDifference > 14) {
      //   throw Exception('Can only backdate up to 14 days in the past');
      // }

      // Check if already completed on this date
      final existingRecords = await db.query(
        DatabaseTables.record,
        where: '${DatabaseColumns.recordRoutineId} = ?',
        whereArgs: [routineId],
      );

      for (var record in existingRecords) {
        final int timestamp = record[DatabaseColumns.recordCreatedAt] as int;
        final DateTime recordDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final DateTime recordDateNormalized =
            DateTime(recordDate.year, recordDate.month, recordDate.day);

        if (recordDateNormalized.isAtSameMomentAs(normalizedDate)) {
          throw Exception('Routine already completed on this date');
        }
      }

      // Create routine record with backdated timestamp (set to noon of that day)
      final DateTime backdatedTimestamp = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        12, // Noon
        0,
        0,
      );

      final record = {
        DatabaseColumns.recordText: 'Completed routine: $routineName',
        DatabaseColumns.recordCreatedAt: backdatedTimestamp.millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'routine',
        DatabaseColumns.recordRoutineId: routineId,
      };

      final int recordId = await db.insert(DatabaseTables.record, record);

      // Recalculate streak based on all completions
      await _recalculateRoutineStreak(db, routineId);

      return recordId;
    } catch (e) {
      log('Error backdating routine completion: $e');
      rethrow;
    }
  }

  /// Recalculate and update a routine's streak based on all completion records
  Future<void> _recalculateRoutineStreak(Database db, int routineId) async {
    try {
      // Get routine data
      final List<Map<String, dynamic>> routineData = await db.query(
        DatabaseTables.routines,
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [routineId],
      );

      if (routineData.isEmpty) return;

      final currentRoutine = routineData.first;
      final String daysOfWeekString = currentRoutine[DatabaseColumns.routineDaysOfWeek] as String;
      final List<bool> daysOfWeek = daysOfWeekString.split(',').map((day) => day == '1').toList();

      // Get all completion records for this routine
      final records = await db.query(
        DatabaseTables.record,
        where: '${DatabaseColumns.recordRoutineId} = ?',
        whereArgs: [routineId],
        orderBy: '${DatabaseColumns.recordCreatedAt} DESC',
      );

      // Extract unique completion dates (normalized to just the date)
      final Set<String> completionDates = {};
      String? mostRecentCompletionDate;

      for (var record in records) {
        final int timestamp = record[DatabaseColumns.recordCreatedAt] as int;
        final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final String dateStr = DateFormat('yyyy-MM-dd').format(date);
        completionDates.add(dateStr);

        // Track most recent completion
        mostRecentCompletionDate ??= dateStr;
      }

      if (completionDates.isEmpty) {
        // No completions, reset streak
        await db.update(
          DatabaseTables.routines,
          {
            DatabaseColumns.routineStreak: 0,
            DatabaseColumns.routineLastCompletedDate: null,
            DatabaseColumns.routineIsDone: 0,
          },
          where: '${DatabaseColumns.id} = ?',
          whereArgs: [routineId],
        );
        return;
      }

      // Calculate streak from most recent completion going backwards
      int streak = 1; // Start with 1 for the most recent completion
      DateTime currentDate = DateFormat('yyyy-MM-dd').parse(mostRecentCompletionDate!);

      // Check if most recent completion is today
      final DateTime today = DateTime.now();
      final String todayStr = DateFormat('yyyy-MM-dd').format(today);
      final bool isDoneToday = mostRecentCompletionDate == todayStr;

      // Count backwards through scheduled occurrences
      while (true) {
        final previousScheduled = _findPreviousScheduledOccurrence(currentDate, daysOfWeek);
        if (previousScheduled == null) break;

        final prevDateStr = DateFormat('yyyy-MM-dd').format(previousScheduled);
        if (completionDates.contains(prevDateStr)) {
          streak++;
          currentDate = previousScheduled;
        } else {
          break;
        }
      }

      // Update the routine
      await db.update(
        DatabaseTables.routines,
        {
          DatabaseColumns.routineStreak: streak,
          DatabaseColumns.routineLastCompletedDate: mostRecentCompletionDate,
          DatabaseColumns.routineIsDone: isDoneToday ? 1 : 0,
        },
        where: '${DatabaseColumns.id} = ?',
        whereArgs: [routineId],
      );
    } catch (e) {
      log('Error recalculating routine streak: $e');
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

  /// Reset all goals' progress for the day
  Future<void> resetGoalsStatus() async {
    try {
      final Database db = await instance.database;
      await db.update(
        DatabaseTables.goals,
        {
          DatabaseColumns.goalTimeSpentSeconds: 0,
          DatabaseColumns.goalIsActive: 0,
          DatabaseColumns.goalSessionResumedTimestampSeconds: null,
          DatabaseColumns.goalCompletedAt: null,
        },
      );
    } catch (e) {
      log('Error resetting goals status: $e');
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
