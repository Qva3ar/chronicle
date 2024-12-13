import 'package:Chrono/core/db/db_manager.dart';
import 'package:sqflite/sqflite.dart';

import 'models/health_reminder_entity.dart';

class HealthReminderDbService {
  static const tableName = 'health_reminder';
  static const columnId = 'id';
  static const columnDate = 'date';
  static const columnDescription = 'description';
  static const columnIsChecked = 'is_checked';
  static const columnSelectedDays = 'days';

  final DatabaseHelper _databaseHelper;

  HealthReminderDbService({required DatabaseHelper databaseHelper})
      : _databaseHelper = databaseHelper;

  Future insertReminder(HealthReminderEntity entity) async {
    final database = await _databaseHelper.database;
    database.insert(tableName, entity.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HealthReminderEntity>> getReminders() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    final check = maps.map((e) {
      return HealthReminderEntity.fromJson(e);
    }).toList();
    return check;
  }

  Future deleteReminder(String id) async {
    final db = await _databaseHelper.database;
    return db.delete(tableName, where: '$columnId = ?', whereArgs: [id]);
  }

  Future deleteAllReminders() async {
    final db = await _databaseHelper.database;
    return db.delete(tableName);
  }

  Future insertRemindersList(List<HealthReminderEntity> remindersList) async {
    final Database database = await _databaseHelper.database;

    for (HealthReminderEntity reminder in remindersList) {
      database.insert(tableName, reminder.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<HealthReminderEntity?> getReminderById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? HealthReminderEntity.fromJson(maps[0]) : null;
  }
}
