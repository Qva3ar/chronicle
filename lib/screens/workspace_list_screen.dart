import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/models/workspace_entry.dart';
import 'package:chrono/screens/workspace_editor_screen.dart';
import 'package:chrono/services/workspace_service.dart';
import 'package:chrono/shared/workspace_color_picker.dart';
import 'package:chrono/shared/premium_gate.dart';

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
    final result = await showDialog<({String name, String? color})>(
      context: context,
      builder: (ctx) => _NewWorkspaceDialog(),
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

  Future<void> _rename(WorkspaceEntry w) async {
    if (w.id == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: w.name);
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(AppLocalizations.of(ctx).commonRename,
              style: const TextStyle(color: textPrimary)),
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
              child: Text(AppLocalizations.of(ctx).commonCancel,
                  style: const TextStyle(color: textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(AppLocalizations.of(ctx).commonSave,
                  style: const TextStyle(color: MyColors.orangeDivider)),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await _service.persistNow(w.copyWith(name: name));
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
            title: Text(AppLocalizations.of(ctx).workspaceChangeColor,
                style: const TextStyle(color: textPrimary)),
            content: WorkspaceColorPicker(
              selectedColorHex: selected,
              onColorSelected: (h) => setDialogState(() => selected = h),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(ctx).commonCancel,
                    style: const TextStyle(color: textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: Text(AppLocalizations.of(ctx).commonSave,
                    style: const TextStyle(color: MyColors.orangeDivider)),
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
        title: Text(AppLocalizations.of(ctx).workspaceDeleteTitle,
            style: const TextStyle(color: textPrimary)),
        content: Text(
          AppLocalizations.of(ctx).workspaceRemoveMessage(w.name),
          style: TextStyle(color: textMuted.withValues(alpha: 0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).commonCancel,
                style: const TextStyle(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx).commonDelete,
                style: const TextStyle(color: MyColors.remove)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteWorkspace(w.id!);
    _load();
  }

  String _formatDate(BuildContext context, int millis) {
    final l = AppLocalizations.of(context);
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l.timeJustNow;
    if (diff.inHours < 1) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);
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
        title: Text(AppLocalizations.of(context).workspacesTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MyColors.secondaryColor,
        onPressed: () {
          if (!checkPremiumOrShowPaywall(context)) return;
          _createNew();
        },
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
                        Text(
                          AppLocalizations.of(context).noWorkspacesYet,
                          style: const TextStyle(
                              color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).workspaceEmptyHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: textMuted, height: 1.5),
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
                    final accent = w.color != null
                        ? parseTagColor(w.color)
                        : MyColors.orangeDivider;
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
                                              color: surfaceElevated,
                                              onSelected: (v) {
                                                if (v == 'rename') _rename(w);
                                                if (v == 'color') _changeColor(w);
                                                if (v == 'delete') _confirmDelete(w);
                                              },
                                              itemBuilder: (ctx) => [
                                                PopupMenuItem(
                                                    value: 'rename',
                                                    child: Text(AppLocalizations.of(ctx).commonRename,
                                                        style: const TextStyle(color: textPrimary))),
                                                PopupMenuItem(
                                                    value: 'color',
                                                    child: Text(AppLocalizations.of(ctx).workspaceChangeColor,
                                                        style: const TextStyle(color: textPrimary))),
                                                PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text(AppLocalizations.of(ctx).commonDelete,
                                                        style: const TextStyle(color: MyColors.remove))),
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
                                              _formatDate(context, w.updatedAt),
                                              style: const TextStyle(color: textHint, fontSize: 12),
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(Icons.link_rounded, size: 14, color: textHint),
                                            const SizedBox(width: 4),
                                            Text(
                                              AppLocalizations.of(context).noteCount(count),
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
                    );
                  },
                ),
    );
  }
}

class _NewWorkspaceDialog extends StatefulWidget {
  @override
  State<_NewWorkspaceDialog> createState() => _NewWorkspaceDialogState();
}

class _NewWorkspaceDialogState extends State<_NewWorkspaceDialog> {
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
      title: Text(AppLocalizations.of(context).newWorkspaceTitle,
          style: const TextStyle(color: textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: textPrimary),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).workspaceNameHint,
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
          child: Text(AppLocalizations.of(context).commonCancel,
              style: const TextStyle(color: textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            (name: _controller.text.trim(), color: _selectedColor),
          ),
          child: Text(AppLocalizations.of(context).commonCreate,
              style: const TextStyle(color: MyColors.orangeDivider)),
        ),
      ],
    );
  }
}
