import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/goal.model.dart';

@pragma('vm:entry-point')
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _databaseVersion = 2;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('goals.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE goals (
        _id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        hours INTEGER NOT NULL,
        minutes INTEGER NOT NULL,
        session_minutes INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        time_spent_seconds INTEGER NOT NULL DEFAULT 0,
        session_resumed_timestamp_seconds INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE goals
        ADD COLUMN session_resumed_timestamp_seconds INTEGER
      ''');
      print(
          'Database upgraded from version $oldVersion to $newVersion: Added session_resumed_timestamp_seconds column.');
    }
  }

  // Goal CRUD operations
  Future<int> insertGoal(Goal goal) async {
    final db = await database;
    return await db.insert('goals', goal.toMap());
  }

  Future<List<Goal>> getAllGoals() async {
    final db = await database;
    final maps = await db.query('goals');
    return maps.map((map) => Goal.fromMap(map)).toList();
  }

  Future<Goal?> getGoal(int id) async {
    final db = await database;
    final maps = await db.query(
      'goals',
      where: '_id = ?',
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
      'goals',
      goal.toMap(),
      where: '_id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return await db.delete(
      'goals',
      where: '_id = ?',
      whereArgs: [id],
    );
  }

  Future<Goal?> getActiveGoal() async {
    final db = await database;
    final maps = await db.query(
      'goals',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    if (maps.isNotEmpty) {
      return Goal.fromMap(maps.first);
    }
    return null;
  }

  Future<void> deactivateAllGoals() async {
    final db = await database;
    await db.update(
      'goals',
      {'is_active': 0},
      where: 'is_active = ?',
      whereArgs: [1],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
