import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/models/workspace_entry.dart';
import 'package:chrono/screens/workspace_editor_screen.dart';
import 'package:chrono/services/workspace_service.dart';
import 'package:chrono/shared/chrono_ui.dart';
import 'package:chrono/shared/workspace_color_picker.dart';
import 'package:chrono/shared/premium_gate.dart';

/// Bottom-sheet version of the workspace list.
/// Accepts a [sheetScrollController] from a [DraggableScrollableSheet]
/// so it can be dismissed by swiping down.
class WorkspaceListSheet extends StatefulWidget {
  final ScrollController? sheetScrollController;

  const WorkspaceListSheet({Key? key, this.sheetScrollController}) : super(key: key);

  @override
  State<WorkspaceListSheet> createState() => _WorkspaceListSheetState();
}

class _WorkspaceListSheetState extends State<WorkspaceListSheet> {
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
    final result = await showDialog<({String name, String? color})>(
      context: context,
      builder: (ctx) => _NewWorkspaceSheetDialog(),
    );
    if (result == null || result.name.isEmpty) return;
    final id = await _service.createWorkspace(result.name, color: result.color);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkspaceEditorScreen(workspaceId: id)),
    );
    _load();
  }

  Future<void> _changeColor(WorkspaceEntry w) async {
    if (w.id == null) return;
    final hex = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        String? selected = w.color;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: cardColor,
            title: const Text('Change color', style: TextStyle(color: textPrimary)),
            content: WorkspaceColorPicker(
              selectedColorHex: selected,
              onColorSelected: (h) => setDialogState(() => selected = h),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: const Text('Save', style: TextStyle(color: MyColors.orangeDivider)),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    final updated = hex == w.color
        ? w
        : w.copyWith(color: hex, clearColor: hex == null);
    if (updated != w) {
      await _service.persistNow(updated);
      _load();
    }
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

  Widget _buildHeader() {
    return ChronoSheetHeader(
      title: 'Workspaces',
      titleIcon: Icons.workspaces_outlined,
      itemCount: _items.length,
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: textPrimary),
          onPressed: () {
            if (!checkPremiumOrShowPaywall(context)) return;
            _createNew();
          },
          tooltip: 'New workspace',
        ),
      ],
    );
  }

  Widget _buildWorkspaceCard(WorkspaceEntry w) {
    final count = _linkedCounts[w.id] ?? 0;
    final preview = _previewText(w.documentMarkdown);
    final accent = w.color != null
        ? parseTagColor(w.color)
        : MyColors.orangeDivider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: cardColor2,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 4, color: accent.withValues(alpha: 0.7)),
                  Expanded(
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
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: surfaceElevated,
                                onSelected: (v) {
                                  if (v == 'color') _changeColor(w);
                                  if (v == 'delete') _confirmDelete(w);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'color',
                                    child: Text('Change color',
                                        style: TextStyle(color: textPrimary)),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style: TextStyle(color: MyColors.remove)),
                                  ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ChronoEmptyState(
      icon: Icons.workspaces_outlined,
      title: 'No Workspaces Yet',
      subtitle:
          'Tap + to create your first workspace.\nLink notes, write documents, and use AI to find related content.',
      buttonLabel: 'Create Workspace',
      onButton: () {
        if (!checkPremiumOrShowPaywall(context)) return;
        _createNew();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtrl = widget.sheetScrollController;

    if (sheetCtrl != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: cardColor,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? ListView(
                        controller: sheetCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(
                            height: 280,
                            child: Center(
                              child: CircularProgressIndicator(color: MyColors.orangeDivider),
                            ),
                          ),
                        ],
                      )
                    : _items.isEmpty
                        ? ListView(
                            controller: sheetCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _buildEmptyState(),
                            ],
                          )
                        : ListView.builder(
                            controller: sheetCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _items.length,
                            itemBuilder: (context, i) => _buildWorkspaceCard(_items[i]),
                          ),
              ),
            ],
          ),
        ),
      );
    }

    // Fallback (non-sheet mode)
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: MyColors.orangeDivider),
                  )
                : _items.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _items.length,
                        itemBuilder: (context, i) => _buildWorkspaceCard(_items[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _NewWorkspaceSheetDialog extends StatefulWidget {
  @override
  State<_NewWorkspaceSheetDialog> createState() => _NewWorkspaceSheetDialogState();
}

class _NewWorkspaceSheetDialogState extends State<_NewWorkspaceSheetDialog> {
  final _controller = TextEditingController(text: 'Workspace');
  String? _selectedColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardColor,
      title: const Text('New workspace', style: TextStyle(color: textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
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
          const SizedBox(height: 16),
          WorkspaceColorPicker(
            selectedColorHex: _selectedColor,
            onColorSelected: (hex) => setState(() => _selectedColor = hex),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            (name: _controller.text.trim(), color: _selectedColor),
          ),
          child: const Text('Create', style: TextStyle(color: MyColors.orangeDivider)),
        ),
      ],
    );
  }
}
