import 'dart:io';

import 'package:chrono/db_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;

  _FakePathProviderPlatform(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  setUpAll(() async {
    // Use SQLite FFI so sqflite works in VM tests.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Export -> Import keeps Chrono system tag and note tag links', () async {
    final tempDir = await Directory.systemTemp.createTemp('chrono_import_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

    // Ensure we start from a clean DB for this run.
    await DatabaseHelper.instance.closeDatabase();

    final db = await DatabaseHelper.instance.database;

    // Chrono system tag should be created on DB creation.
    final chronoRowsBefore = await db.query(
      DatabaseTables.category,
      where: '${DatabaseColumns.tagName} = ?',
      whereArgs: const ['Chrono'],
      limit: 1,
    );
    expect(chronoRowsBefore, isNotEmpty);
    final int chronoId = chronoRowsBefore.first[DatabaseColumns.id] as int;
    expect(chronoRowsBefore.first[DatabaseColumns.tagIsSystem], 1);

    // Create a non-system tag and a note linked to both tags.
    final int foodId = await db.insert(DatabaseTables.category, {
      DatabaseColumns.tagName: 'Food',
      DatabaseColumns.tagColor: '123',
      DatabaseColumns.tagIsSystem: 0,
    });

    final int recordId = await db.insert(DatabaseTables.record, {
      DatabaseColumns.recordText: 'Went to a new cafe near home',
      DatabaseColumns.recordCreatedAt: DateTime(2026, 2, 22, 12, 0).millisecondsSinceEpoch,
      DatabaseColumns.recordType: 'regular',
      DatabaseColumns.recordIsLocked: 0,
    });

    await db.insert(DatabaseTables.recordTag, {'recordId': recordId, 'tagId': chronoId});
    await db.insert(DatabaseTables.recordTag, {'recordId': recordId, 'tagId': foodId});

    // Export using the same shape as DataExporter (raw DB rows).
    final exportedTags = (await DatabaseHelper.instance.queryAllRows())
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final exportedNotes = (await DatabaseHelper.instance.fetchAllNotes())
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final exportData = <String, dynamic>{
      'tags': exportedTags,
      'notes': exportedNotes,
    };

    // Simulate a backup where Chrono lost its system flag; import should restore it.
    for (final t in exportedTags) {
      if (t[DatabaseColumns.tagName] == 'Chrono') {
        t[DatabaseColumns.tagIsSystem] = 0;
      }
    }

    await DatabaseHelper.instance.importRecords(exportData);

    // Verify Chrono is still system after import.
    final chronoRowsAfter = await db.query(
      DatabaseTables.category,
      where: '${DatabaseColumns.tagName} = ?',
      whereArgs: const ['Chrono'],
      limit: 1,
    );
    expect(chronoRowsAfter, isNotEmpty);
    expect(chronoRowsAfter.first[DatabaseColumns.tagIsSystem], 1);

    // Verify the imported note retained its tag links.
    final links = await db.query(
      DatabaseTables.recordTag,
      columns: const ['tagId'],
      where: 'recordId = ?',
      whereArgs: [recordId],
    );
    final linkedTagIds = links.map((e) => e['tagId'] as int).toSet();
    expect(linkedTagIds.contains(chronoId), isTrue);
    expect(linkedTagIds.contains(foodId), isTrue);

    await DatabaseHelper.instance.closeDatabase();
    await tempDir.delete(recursive: true);
  });
}
