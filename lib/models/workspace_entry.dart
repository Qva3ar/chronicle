import 'package:chrono/db_manager.dart';

class WorkspaceEntry {
  final int? id;
  final String name;
  final String documentMarkdown;
  final int updatedAt;
  final double splitTopRatio;

  WorkspaceEntry({
    this.id,
    required this.name,
    required this.documentMarkdown,
    required this.updatedAt,
    this.splitTopRatio = 0.55,
  });

  WorkspaceEntry copyWith({
    int? id,
    String? name,
    String? documentMarkdown,
    int? updatedAt,
    double? splitTopRatio,
  }) {
    return WorkspaceEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      documentMarkdown: documentMarkdown ?? this.documentMarkdown,
      updatedAt: updatedAt ?? this.updatedAt,
      splitTopRatio: splitTopRatio ?? this.splitTopRatio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DatabaseColumns.id: id,
      DatabaseColumns.workspaceName: name,
      DatabaseColumns.workspaceDocumentMarkdown: documentMarkdown,
      DatabaseColumns.workspaceUpdatedAt: updatedAt,
      DatabaseColumns.workspaceSplitTopRatio: splitTopRatio,
    };
  }

  factory WorkspaceEntry.fromMap(Map<String, dynamic> map) {
    final ratioRaw = map[DatabaseColumns.workspaceSplitTopRatio];
    double ratio = 0.55;
    if (ratioRaw is num) {
      ratio = ratioRaw.toDouble();
    } else if (ratioRaw != null) {
      ratio = double.tryParse(ratioRaw.toString()) ?? 0.55;
    }
    return WorkspaceEntry(
      id: map[DatabaseColumns.id] as int?,
      name: map[DatabaseColumns.workspaceName]?.toString() ?? '',
      documentMarkdown: map[DatabaseColumns.workspaceDocumentMarkdown]?.toString() ?? '',
      updatedAt: map[DatabaseColumns.workspaceUpdatedAt] is int
          ? map[DatabaseColumns.workspaceUpdatedAt] as int
          : int.tryParse('${map[DatabaseColumns.workspaceUpdatedAt]}') ??
              DateTime.now().millisecondsSinceEpoch,
      splitTopRatio: ratio.clamp(0.2, 0.85),
    );
  }
}
