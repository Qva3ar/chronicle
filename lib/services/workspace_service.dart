import 'dart:async';

import 'package:chrono/db_manager.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/models/workspace_entry.dart';

class WorkspaceService {
  WorkspaceService._();
  static final WorkspaceService instance = WorkspaceService._();

  final DatabaseHelper _db = DatabaseHelper.instance;
  Timer? _saveDebounce;

  void schedulePersist(WorkspaceEntry entry) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      _db.updateWorkspace(entry);
    });
  }

  Future<void> persistNow(WorkspaceEntry entry) => _db.updateWorkspace(entry);

  Future<int> createWorkspace(String name, {String? color}) {
    return _db.insertWorkspace(WorkspaceEntry(
      name: name,
      documentMarkdown: '',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      color: color,
    ));
  }

  Future<List<WorkspaceEntry>> listWorkspaces() => _db.queryAllWorkspaces();

  Future<WorkspaceEntry?> getById(int id) => _db.getWorkspaceById(id);

  Future<void> deleteWorkspace(int id) => _db.deleteWorkspace(id);

  Future<List<Record>> linkedRecords(int workspaceId) =>
      _db.getWorkspaceLinkedRecords(workspaceId);

  Future<void> addRecord(int workspaceId, int recordId) =>
      _db.addRecordToWorkspace(workspaceId, recordId);

  Future<void> removeRecord(int workspaceId, int recordId) =>
      _db.removeRecordFromWorkspace(workspaceId, recordId);

  Future<void> setOrder(int workspaceId, List<int> orderedIds) =>
      _db.setWorkspaceLinkedRecordOrder(workspaceId, orderedIds);

  Future<int> linkedRecordCount(int workspaceId) =>
      _db.getWorkspaceLinkedRecordCount(workspaceId);
}
