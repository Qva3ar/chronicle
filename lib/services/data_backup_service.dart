import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db_manager.dart';

/// Service for creating and managing data backups
class DataBackupService {
  static final DataBackupService instance = DataBackupService._internal();
  DataBackupService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Create a complete JSON backup of all user data
  Future<Map<String, dynamic>> createBackup() async {
    try {
      final db = await _db.database;
      
      // Export all tables
      final backup = <String, dynamic>{
        'version': DatabaseConfig.databaseVersion,
        'created_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0', // You can get this from package_info_plus
        'data': {}
      };
      
      // Export records
      final records = await db.query(DatabaseTables.record);
      backup['data']['records'] = records;
      
      // Export tags
      final tags = await db.query(DatabaseTables.category);
      backup['data']['tags'] = tags;
      
      // Export record-tag associations
      final recordTags = await db.query(DatabaseTables.recordTag);
      backup['data']['record_tags'] = recordTags;
      
      // Export goals
      final goals = await db.query(DatabaseTables.goals);
      backup['data']['goals'] = goals;
      
      // Export routines
      final routines = await db.query(DatabaseTables.routines);
      backup['data']['routines'] = routines;
      
      // Export instructions
      final instructions = await db.query(DatabaseTables.instructions);
      backup['data']['instructions'] = instructions;
      
      print('🎯 BACKUP: Created backup with ${records.length} records, ${tags.length} tags');
      
      return backup;
    } catch (e) {
      print('❌ BACKUP ERROR: $e');
      rethrow;
    }
  }
  
  /// Save backup to file and optionally share it
  Future<String> exportBackupToFile({bool share = false}) async {
    try {
      final backup = await createBackup();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
      
      // Get external storage directory
      final Directory? externalDir = await getExternalStorageDirectory();
      final Directory backupDir = Directory('${externalDir?.path ?? (await getApplicationDocumentsDirectory()).path}/backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      final String fileName = 'chrono_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0]}.json';
      final File backupFile = File('${backupDir.path}/$fileName');
      
      await backupFile.writeAsString(jsonString);
      
      print('✅ BACKUP: Saved to ${backupFile.path}');
      
      if (share) {
        await Share.shareXFiles([XFile(backupFile.path)], text: 'Chrono App Backup');
      }
      
      return backupFile.path;
    } catch (e) {
      print('❌ EXPORT ERROR: $e');
      rethrow;
    }
  }
  
  /// Restore data from backup file
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final File backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: $backupPath');
      }
      
      final String jsonString = await backupFile.readAsString();
      final Map<String, dynamic> backup = jsonDecode(jsonString);
      
      if (backup['data'] == null) {
        throw Exception('Invalid backup format');
      }
      
      final db = await _db.database;
      
      // Clear existing data (optional - you might want to merge instead)
      // await db.delete(DatabaseTables.recordTag);
      // await db.delete(DatabaseTables.record);
      // await db.delete(DatabaseTables.category);
      
      // Restore data
      final data = backup['data'] as Map<String, dynamic>;
      
      if (data['tags'] != null) {
        for (final tag in data['tags']) {
          await db.insert(DatabaseTables.category, tag, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      if (data['records'] != null) {
        for (final record in data['records']) {
          await db.insert(DatabaseTables.record, record, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      if (data['record_tags'] != null) {
        for (final recordTag in data['record_tags']) {
          await db.insert(DatabaseTables.recordTag, recordTag, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      if (data['goals'] != null) {
        for (final goal in data['goals']) {
          await db.insert(DatabaseTables.goals, goal, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      if (data['routines'] != null) {
        for (final routine in data['routines']) {
          await db.insert(DatabaseTables.routines, routine, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      print('✅ RESTORE: Successfully restored backup');
      return true;
    } catch (e) {
      print('❌ RESTORE ERROR: $e');
      return false;
    }
  }
  
  /// Create automatic backup before critical operations
  Future<void> createAutomaticBackup(String operation) async {
    try {
      final backup = await createBackup();
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final Directory autoBackupDir = Directory('${documentsDir.path}/auto_backups');
      
      if (!await autoBackupDir.exists()) {
        await autoBackupDir.create(recursive: true);
      }
      
      final String fileName = 'auto_backup_${operation}_${DateTime.now().millisecondsSinceEpoch}.json';
      final File backupFile = File('${autoBackupDir.path}/$fileName');
      
      await backupFile.writeAsString(jsonEncode(backup));
      
      // Keep only last 5 automatic backups
      await _cleanupOldBackups(autoBackupDir);
      
      print('✅ AUTO BACKUP: Created for operation: $operation');
    } catch (e) {
      print('❌ AUTO BACKUP ERROR: $e');
    }
  }
  
  /// Clean up old backup files, keeping only the most recent ones
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final List<FileSystemEntity> files = await backupDir.list().toList();
      final List<File> backupFiles = files.whereType<File>().where((f) => f.path.endsWith('.json')).toList();
      
      if (backupFiles.length > 5) {
        // Sort by modification time, newest first
        backupFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        
        // Delete older backups
        for (int i = 5; i < backupFiles.length; i++) {
          await backupFiles[i].delete();
          print('🗑️ Deleted old backup: ${backupFiles[i].path}');
        }
      }
    } catch (e) {
      print('❌ CLEANUP ERROR: $e');
    }
  }
}