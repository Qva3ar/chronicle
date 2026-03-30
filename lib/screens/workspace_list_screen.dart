import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/models/workspace_entry.dart';
import 'package:chrono/screens/workspace_editor_screen.dart';
import 'package:chrono/services/workspace_service.dart';

class WorkspaceListScreen extends StatefulWidget {
  const WorkspaceListScreen({Key? key}) : super(key: key);

  @override
  State<WorkspaceListScreen> createState() => _WorkspaceListScreenState();
}

class _WorkspaceListScreenState extends State<WorkspaceListScreen> {
  final _service = WorkspaceService.instance;
  List<WorkspaceEntry> _items = [];
  Map<int, int> _linkedCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.listWorkspaces();
    final counts = <int, int>{};
    for (final w in list) {
      if (w.id != null) {
        counts[w.id!] = await _service.linkedRecordCount(w.id!);
      }
    }
    if (mounted) {
      setState(() {
        _items = list;
        _linkedCounts = counts;
        _loading = false;
      });
    }
  }

  Future<void> _createNew() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: 'Workspace');
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text('New workspace', style: TextStyle(color: textPrimary)),
          content: TextField(
            controller: c,
            autofocus: true,
            style: const TextStyle(color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Name',
              hintStyle: const TextStyle(color: textHint),
              filled: true,
              fillColor: cardColor2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Create', style: TextStyle(color: MyColors.orangeDivider)),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final id = await _service.createWorkspace(name);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkspaceEditorScreen(workspaceId: id)),
    );
    _load();
  }

  Future<void> _rename(WorkspaceEntry w) async {
    if (w.id == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: w.name);
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text('Rename', style: TextStyle(color: textPrimary)),
          content: TextField(
            controller: c,
            autofocus: true,
            style: const TextStyle(color: textPrimary),
            decoration: InputDecoration(
              hintStyle: const TextStyle(color: textHint),
              filled: true,
              fillColor: cardColor2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save', style: TextStyle(color: MyColors.orangeDivider)),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await _service.persistNow(w.copyWith(name: name));
    _load();
  }

  Future<void> _confirmDelete(WorkspaceEntry w) async {
    if (w.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Delete workspace?', style: TextStyle(color: textPrimary)),
        content: Text(
          'This removes "${w.name}" and its note links. Notes themselves are not deleted.',
          style: TextStyle(color: textMuted.withValues(alpha: 0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: MyColors.remove)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteWorkspace(w.id!);
    _load();
  }

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  String _previewText(String markdown) {
    final cleaned = markdown
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'[*_~`>]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    if (cleaned.length <= 80) return cleaned;
    return '${cleaned.substring(0, 80)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Workspaces',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MyColors.secondaryColor,
        onPressed: _createNew,
        child: Icon(Icons.add, color: MyColors.fivyColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MyColors.orangeDivider))
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspaces_outlined, size: 64, color: textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          'No workspaces yet',
                          style: TextStyle(
                              color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to create your first workspace.\nLink notes, write documents, and use AI to find related content.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final w = _items[i];
                    final count = _linkedCounts[w.id] ?? 0;
                    final preview = _previewText(w.documentMarkdown);
                    return Material(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          if (w.id == null) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkspaceEditorScreen(workspaceId: w.id!),
                            ),
                          );
                          _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      w.name,
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: textMuted, size: 20),
                                    color: surfaceElevated,
                                    onSelected: (v) {
                                      if (v == 'rename') _rename(w);
                                      if (v == 'delete') _confirmDelete(w);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                          value: 'rename',
                                          child: Text('Rename',
                                              style: TextStyle(color: textPrimary))),
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete',
                                              style: TextStyle(color: MyColors.remove))),
                                    ],
                                  ),
                                ],
                              ),
                              if (preview.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  preview,
                                  style: const TextStyle(color: textMuted, fontSize: 13, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: textHint),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(w.updatedAt),
                                    style: const TextStyle(color: textHint, fontSize: 12),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.link_rounded, size: 14, color: textHint),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$count note${count != 1 ? 's' : ''}',
                                    style: const TextStyle(color: textHint, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
