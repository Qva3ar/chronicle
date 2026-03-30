import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/models/tag.dart';
import 'package:chrono/models/workspace_entry.dart';
import 'package:chrono/chat_page_note.dart';
import 'package:chrono/record.service.dart';
import 'package:chrono/services/filter_service.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/services/messages.service.dart';
import 'package:chrono/services/workspace_ai_service.dart';
import 'package:chrono/services/workspace_service.dart';
import 'package:chrono/shared/api-key-popup.dart';
import 'package:chrono/shared/tag_selection_dialog.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Workspace Editor
// ──────────────────────────────────────────────────────────────────────────────

class WorkspaceEditorScreen extends StatefulWidget {
  const WorkspaceEditorScreen({Key? key, required this.workspaceId}) : super(key: key);
  final int workspaceId;

  @override
  State<WorkspaceEditorScreen> createState() => _WorkspaceEditorScreenState();
}

class _WorkspaceEditorScreenState extends State<WorkspaceEditorScreen> {
  final _service = WorkspaceService.instance;
  final _gptBind = GPTNoteBindService();
  final _messageService = MessageService();
  final _markdownController = TextEditingController();
  final _scrollMarkdown = ScrollController();

  WorkspaceEntry? _entry;
  List<Record> _linked = [];
  bool _loading = true;
  bool _showLinkedPanel = false;
  bool _previewMarkdown = false;
  bool _includeLinkedInChat = false;
  double _splitRatio = 0.55;

  // Cached AI/Search results (persist while editor is open)
  List<Record> _cachedSearchResults = [];
  List<Record> _cachedAiResults = [];

  // Persist AI chat draft text between open/close
  String _chatDraftText = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _service.getById(widget.workspaceId);
    final linked = await _service.linkedRecords(widget.workspaceId);
    if (!mounted) return;
    if (e == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _entry = e;
      _linked = linked;
      _splitRatio = e.splitTopRatio;
      _markdownController.text = e.documentMarkdown;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _markdownController.dispose();
    _scrollMarkdown.dispose();
    super.dispose();
  }

  // ── Persistence ──

  void _onBodyChanged(String text) {
    final e = _entry;
    if (e == null) return;
    final updated = e.copyWith(
      documentMarkdown: text,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _entry = updated);
    _service.schedulePersist(updated);
  }

  Future<void> _persistRatio() async {
    final e = _entry;
    if (e == null) return;
    final updated = e.copyWith(splitTopRatio: _splitRatio);
    setState(() => _entry = updated);
    await _service.persistNow(updated);
  }

  // ── Markdown helpers ──

  void _insertAtCursor(String insert) {
    final c = _markdownController;
    final sel = c.selection;
    if (!sel.isValid) {
      c.text = c.text + insert;
      c.selection = TextSelection.collapsed(offset: c.text.length);
    } else {
      final text = c.text;
      final newText = text.replaceRange(sel.start, sel.end, insert);
      c.text = newText;
      c.selection = TextSelection.collapsed(offset: sel.start + insert.length);
    }
    _onBodyChanged(c.text);
  }

  // ── AI Chat ──

  String _chatNoteContext() {
    final doc = _markdownController.text;
    if (!_includeLinkedInChat || _linked.isEmpty) return doc;
    final buf = StringBuffer(doc);
    buf.writeln('\n\n---\nLinked notes in workspace:');
    for (final r in _linked) {
      buf.writeln('\n--- Note #${r.id} ---');
      if (r.title.isNotEmpty) buf.writeln('Title: ${r.title}');
      buf.writeln(r.text);
    }
    return buf.toString();
  }

  void _showGptSheet() {
    if (!_gptBind.isKeyProvided()) {
      showDialog(context: context, builder: (_) => ApiKeyPopup());
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: MyColors.secondaryColor,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ChatPageNote(
            messageService: _messageService,
            noteText: _chatNoteContext(),
            initialDraftText: _chatDraftText,
            onDraftChanged: (text) => _chatDraftText = text,
          ),
        ),
      ),
    );
  }

  // ── Linked notes panel ──

  Future<void> _openAddSheet() async {
    final linkedIds = _linked.map((r) => r.id).toSet();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => _WorkspaceAddNotesPanel(
          workspaceId: widget.workspaceId,
          alreadyLinkedIds: linkedIds,
          scrollController: scrollCtrl,
          cachedSearchResults: _cachedSearchResults,
          cachedAiResults: _cachedAiResults,
          onCacheUpdated: (search, ai) {
            _cachedSearchResults = search;
            _cachedAiResults = ai;
          },
          onAdded: () async {
            final linked = await _service.linkedRecords(widget.workspaceId);
            if (mounted) setState(() => _linked = linked);
          },
        ),
      ),
    );
    // Refresh linked after closing
    final linked = await _service.linkedRecords(widget.workspaceId);
    if (mounted) setState(() => _linked = linked);
  }

  Future<void> _removeLink(int recordId) async {
    await _service.removeRecord(widget.workspaceId, recordId);
    final linked = await _service.linkedRecords(widget.workspaceId);
    if (mounted) setState(() => _linked = linked);
  }

  Future<void> _renameWorkspace() async {
    final e = _entry;
    if (e == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: e.name);
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text('Rename workspace', style: TextStyle(color: textPrimary)),
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
    final updated = e.copyWith(name: name);
    setState(() => _entry = updated);
    await _service.persistNow(updated);
  }

  // ── Format toolbar ──

  Widget _formatBar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceElevated,
        border: Border(bottom: BorderSide(color: cardBorder.withValues(alpha: 0.3))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _fmtBtn('H1', () => _insertAtCursor('# ')),
            _fmtBtn('H2', () => _insertAtCursor('## ')),
            _fmtBtn('H3', () => _insertAtCursor('### ')),
            _fmtBtn('B', () {
              final sel = _markdownController.selection;
              if (sel.isValid && sel.start != sel.end) {
                final text = _markdownController.text;
                final selected = text.substring(sel.start, sel.end);
                final newText = text.replaceRange(sel.start, sel.end, '**$selected**');
                _markdownController.text = newText;
                _markdownController.selection =
                    TextSelection.collapsed(offset: sel.start + selected.length + 4);
                _onBodyChanged(newText);
              } else {
                _insertAtCursor('**text**');
              }
            }),
            _fmtBtn('I', () {
              final sel = _markdownController.selection;
              if (sel.isValid && sel.start != sel.end) {
                final text = _markdownController.text;
                final selected = text.substring(sel.start, sel.end);
                final newText = text.replaceRange(sel.start, sel.end, '*$selected*');
                _markdownController.text = newText;
                _markdownController.selection =
                    TextSelection.collapsed(offset: sel.start + selected.length + 2);
                _onBodyChanged(newText);
              } else {
                _insertAtCursor('*text*');
              }
            }),
            _fmtBtn('•', () => _insertAtCursor('- ')),
            _fmtBtn('1.', () => _insertAtCursor('1. ')),
            _fmtBtn('>', () => _insertAtCursor('> ')),
            _fmtBtn('—', () => _insertAtCursor('\n---\n')),
          ],
        ),
      ),
    );
  }

  Widget _fmtBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: cardColor2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _previewMarkdown ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                color: _previewMarkdown ? textHint : textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Document editor / preview ──

  Widget _docEditor() {
    if (_previewMarkdown) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownWidget(
          data: _markdownController.text.isEmpty ? '*Nothing yet*' : _markdownController.text,
          shrinkWrap: true,
          config: MarkdownConfig(configs: [
            PConfig(textStyle: const TextStyle(color: textPrimary, height: 1.6, fontSize: 14)),
            H1Config(style: const TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
            H2Config(style: const TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            H3Config(style: const TextStyle(color: textSecondary, fontSize: 17, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }
    return TextField(
      controller: _markdownController,
      scrollController: _scrollMarkdown,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: textPrimary, fontSize: 14, height: 1.6),
      cursorColor: MyColors.orangeDivider,
      cursorWidth: 2,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Write in Markdown…',
        hintStyle: TextStyle(color: textHint),
        contentPadding: EdgeInsets.all(16),
      ),
      onChanged: _onBodyChanged,
    );
  }

  // ── Linked notes (full-text vertical cards) ──

  Widget _linkedPanel() {
    if (_linked.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded, size: 40, color: textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                'No linked notes yet',
                style: TextStyle(color: textMuted, fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "Add" to search or use AI',
                style: TextStyle(color: textHint, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _linked.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = _linked[i];
        return _LinkedNoteCard(
          record: r,
          onRemove: () => _removeLink(r.id),
          showSwipeHint: i == 0,
        );
      },
    );
  }

  // ── Split handle (FIX #1: reversed direction — drag up = ratio increases = top grows) ──

  Widget _splitHandle(double totalH) {
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (totalH <= 0) return;
        setState(() {
          _splitRatio = (_splitRatio + d.delta.dy / totalH).clamp(0.2, 0.85);
        });
      },
      onVerticalDragEnd: (_) => _persistRatio(),
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: surfaceElevated,
          border: Border(
            top: BorderSide(color: cardBorder.withValues(alpha: 0.4)),
            bottom: BorderSide(color: cardBorder.withValues(alpha: 0.4)),
          ),
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom toolbar ──

  Widget _bottomTools() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceElevated,
        border: Border(top: BorderSide(color: cardBorder.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _toolBtn(
              tooltip: 'Linked notes',
              icon: _showLinkedPanel ? Icons.vertical_align_center : Icons.vertical_split_rounded,
              active: _showLinkedPanel,
              badge: _linked.isNotEmpty ? _linked.length.toString() : null,
              onTap: () => setState(() => _showLinkedPanel = !_showLinkedPanel),
            ),
            _toolBtn(
              tooltip: 'Add notes',
              icon: Icons.playlist_add_rounded,
              onTap: _openAddSheet,
            ),
            _toolBtn(
              tooltip: _previewMarkdown ? 'Edit' : 'Preview',
              icon: _previewMarkdown ? Icons.edit_note_rounded : Icons.visibility_outlined,
              active: _previewMarkdown,
              onTap: () => setState(() => _previewMarkdown = !_previewMarkdown),
            ),
            const Spacer(),
            _toolBtn(
              tooltip: _includeLinkedInChat ? 'Chat: doc + notes' : 'Chat: doc only',
              icon: _includeLinkedInChat ? Icons.link_rounded : Icons.link_off_rounded,
              active: _includeLinkedInChat,
              onTap: () {
                setState(() => _includeLinkedInChat = !_includeLinkedInChat);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _includeLinkedInChat
                          ? 'AI Chat will include linked notes'
                          : 'AI Chat: document only',
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _toolBtn(
              tooltip: 'AI Chat',
              icon: null,
              svgAsset: 'assets/icons/chat.svg',
              onTap: _showGptSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn({
    required String tooltip,
    IconData? icon,
    String? svgAsset,
    bool active = false,
    String? badge,
    required VoidCallback onTap,
  }) {
    Widget iconWidget;
    if (svgAsset != null) {
      iconWidget = SvgPicture.asset(
        svgAsset,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(
          active ? MyColors.orangeDivider : textSecondary,
          BlendMode.srcIn,
        ),
      );
    } else {
      iconWidget = Icon(
        icon,
        size: 24,
        color: active ? MyColors.orangeDivider : textSecondary,
      );
    }

    Widget btn = IconButton(
      tooltip: tooltip,
      icon: iconWidget,
      onPressed: onTap,
    );

    if (badge != null) {
      btn = Stack(
        clipBehavior: Clip.none,
        children: [
          btn,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: MyColors.orangeDivider,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: bgColor, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    }
    return btn;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: MyColors.orangeDivider)),
      );
    }
    if (_entry == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(backgroundColor: bgColor, foregroundColor: textPrimary),
        body: const Center(child: Text('Workspace not found', style: TextStyle(color: textMuted))),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: GestureDetector(
          onTap: _renameWorkspace,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _entry!.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit_outlined, size: 16, color: textMuted),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _formatBar(),
          Expanded(
            child: _showLinkedPanel
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxHeight;
                      final topFlex = (_splitRatio * 1000).round().clamp(200, 800);
                      final botFlex = ((1 - _splitRatio) * 1000).round().clamp(200, 800);
                      return Column(
                        children: [
                          Expanded(
                            flex: topFlex,
                            child: Container(color: cardColor, child: _docEditor()),
                          ),
                          _splitHandle(h),
                          Expanded(
                            flex: botFlex,
                            child: Container(
                              color: bgColor,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Linked Notes',
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: MyColors.orangeDivider.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_linked.length}',
                                            style: const TextStyle(
                                              color: MyColors.orangeDivider,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: _openAddSheet,
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: MyColors.orangeDivider,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: _linkedPanel()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : Container(color: cardColor, child: _docEditor()),
          ),
          _bottomTools(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Linked Note Card — text only, no title (FIX #4)
// ──────────────────────────────────────────────────────────────────────────────

class _LinkedNoteCard extends StatefulWidget {
  const _LinkedNoteCard({required this.record, required this.onRemove, this.showSwipeHint = false});
  final Record record;
  final VoidCallback onRemove;
  final bool showSwipeHint;

  @override
  State<_LinkedNoteCard> createState() => _LinkedNoteCardState();
}

class _LinkedNoteCardState extends State<_LinkedNoteCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  AnimationController? _hintAnim;
  Animation<Offset>? _hintSlide;

  @override
  void initState() {
    super.initState();
    if (widget.showSwipeHint) {
      _hintAnim = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      _hintSlide = TweenSequence<Offset>([
        TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.08, 0))
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: const Offset(-0.08, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.elasticIn)),
          weight: 50,
        ),
      ]).animate(_hintAnim!);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _hintAnim!.forward();
      });
    }
  }

  @override
  void dispose() {
    _hintAnim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final displayText = r.text.isNotEmpty ? r.text : '(empty note)';
    final hasLongText = displayText.length > 150;

    Widget card = Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: MyColors.remove.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: MyColors.remove, size: 24),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder.withValues(alpha: 0.3)),
        ),
        child: GestureDetector(
          onTap: hasLongText ? () => setState(() => _expanded = !_expanded) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCrossFade(
                  firstChild: Text(
                    displayText,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
                  ),
                  secondChild: Text(
                    displayText,
                    style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
                  ),
                  crossFadeState:
                      _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
                if (hasLongText) ...[
                  const SizedBox(height: 6),
                  Text(
                    _expanded ? 'Show less' : 'Show more…',
                    style: TextStyle(
                      color: MyColors.orangeDivider.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap with slide animation for swipe hint
    if (_hintSlide != null) {
      card = SlideTransition(position: _hintSlide!, child: card);
    }

    return card;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Add Notes Panel — Redesigned (FIX #5: premium look)
// ──────────────────────────────────────────────────────────────────────────────

class _WorkspaceAddNotesPanel extends StatefulWidget {
  const _WorkspaceAddNotesPanel({
    required this.workspaceId,
    required this.alreadyLinkedIds,
    required this.scrollController,
    required this.cachedSearchResults,
    required this.cachedAiResults,
    required this.onCacheUpdated,
    required this.onAdded,
  });

  final int workspaceId;
  final Set<int> alreadyLinkedIds;
  final ScrollController scrollController;
  final List<Record> cachedSearchResults;
  final List<Record> cachedAiResults;
  final void Function(List<Record> search, List<Record> ai) onCacheUpdated;
  final VoidCallback onAdded;

  @override
  State<_WorkspaceAddNotesPanel> createState() => _WorkspaceAddNotesPanelState();
}

class _WorkspaceAddNotesPanelState extends State<_WorkspaceAddNotesPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _search = TextEditingController();
  final _aiPrompt = TextEditingController();
  final _db = DatabaseHelper.instance;
  final _recordService = RecordService();
  final _ws = WorkspaceService.instance;

  List<Tag> _allTags = [];
  List<int> _filterTagIds = [];
  late List<Record> _searchResults;
  late List<Record> _aiResults;
  late Set<int> _sessionLinkedIds;
  bool _searchLoading = false;
  bool _aiLoading = false;
  FilterSettings? _filterSettings;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _searchResults = List<Record>.from(widget.cachedSearchResults);
    _aiResults = List<Record>.from(widget.cachedAiResults);
    _sessionLinkedIds = Set<int>.from(widget.alreadyLinkedIds);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final tags = await _recordService.queryAllTagsJust();
    final fs = await FilterService.instance.getFilterSettings();
    if (mounted) {
      setState(() {
        _allTags = tags;
        _filterSettings = fs;
      });
    }
    if (_searchResults.isEmpty) _runSearch();
  }

  @override
  void dispose() {
    widget.onCacheUpdated(_searchResults, _aiResults);
    _tabs.dispose();
    _search.dispose();
    _aiPrompt.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() => _searchLoading = true);
    final fs = _filterSettings ??
        FilterSettings(showGoalRecords: false, showRoutineRecords: false, showCompletedTodos: true);
    final q = _search.text.trim();
    List<Record> rows;

    if (_filterTagIds.isEmpty) {
      rows = await _db.getRecordsWithTag(null, 120, 0,
          searchText: q.isEmpty ? null : q,
          showGoalRecords: fs.showGoalRecords,
          showRoutineRecords: fs.showRoutineRecords);
    } else if (_filterTagIds.length == 1) {
      rows = await _db.getRecordsWithTag(_filterTagIds.first, 120, 0,
          searchText: q.isEmpty ? null : q,
          showGoalRecords: fs.showGoalRecords,
          showRoutineRecords: fs.showRoutineRecords);
    } else {
      rows = await _db.getRecordsByMultipleTags(_filterTagIds);
      if (q.isNotEmpty) {
        final lower = q.toLowerCase();
        rows = rows
            .where((r) =>
                r.title.toLowerCase().contains(lower) || r.text.toLowerCase().contains(lower))
            .toList();
      }
    }

    if (mounted) setState(() { _searchResults = rows; _searchLoading = false; });
  }

  Future<void> _runAi() async {
    final fs = _filterSettings ??
        FilterSettings(showGoalRecords: false, showRoutineRecords: false, showCompletedTodos: true);
    List<Record> pool;
    if (_filterTagIds.isEmpty) {
      final all = await _db.getRecordsWithTag(null, 500, 0,
          showGoalRecords: fs.showGoalRecords, showRoutineRecords: fs.showRoutineRecords);
      pool = all.where((r) => !r.isLocked).toList();
      if (pool.length > 80) {
        if (!mounted) return;
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: cardColor,
            title: const Text('Large search', style: TextStyle(color: textPrimary)),
            content: Text(
              'No tags selected — AI will scan ${pool.length} notes.\nPick tags to narrow scope.',
              style: TextStyle(color: textMuted.withValues(alpha: 0.95)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: textMuted))),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Continue', style: TextStyle(color: MyColors.orangeDivider))),
            ],
          ),
        );
        if (go != true) return;
      }
    } else if (_filterTagIds.length == 1) {
      pool = await _db.getRecordsWithTag(_filterTagIds.first, 500, 0,
          showGoalRecords: fs.showGoalRecords, showRoutineRecords: fs.showRoutineRecords);
      pool = pool.where((r) => !r.isLocked).toList();
    } else {
      pool = await _db.getRecordsByMultipleTags(_filterTagIds);
      pool = pool.where((r) => !r.isLocked).toList();
    }

    setState(() { _aiLoading = true; _aiResults = []; });
    try {
      final ids = await WorkspaceAiService.findRelatedNoteIds(
        candidates: pool, allTags: _allTags, userPrompt: _aiPrompt.text);
      final byId = {for (final r in pool) r.id: r};
      final list = ids.map((id) => byId[id]).whereType<Record>().toList();
      if (mounted) setState(() { _aiResults = list; _aiLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _aiLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI search failed: $e')));
      }
    }
  }

  Future<void> _pickTags() async {
    final result = await showDialog<List<int>?>(
      context: context,
      builder: (ctx) => TagSelectionDialog(
          availableTags: _allTags, initialSelectedTagIds: _filterTagIds),
    );
    if (result != null) {
      setState(() => _filterTagIds = result);
      _runSearch();
    }
  }

  Future<void> _addRecord(Record r) async {
    if (_sessionLinkedIds.contains(r.id)) return;
    await _ws.addRecord(widget.workspaceId, r.id);
    setState(() => _sessionLinkedIds.add(r.id));
    widget.onAdded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Note added to workspace'),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceElevated,
      ));
    }
  }

  List<Record> _filterLinked(List<Record> records) {
    return records.where((r) => !_sessionLinkedIds.contains(r.id)).toList();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Find Notes',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Tag filter chip
                _buildTagFilterChip(),
              ],
            ),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: TabBar(
              controller: _tabs,
              labelColor: textPrimary,
              unselectedLabelColor: textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              indicator: BoxDecoration(
                color: surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Search', height: 38),
                Tab(text: 'AI Find', height: 38),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_searchTab(), _aiTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilterChip() {
    return InkWell(
      onTap: _pickTags,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _filterTagIds.isEmpty
              ? cardColor
              : MyColors.orangeDivider.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _filterTagIds.isEmpty
                ? cardBorder
                : MyColors.orangeDivider.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.label_outline,
              size: 16,
              color: _filterTagIds.isEmpty ? textMuted : MyColors.orangeDivider,
            ),
            const SizedBox(width: 4),
            Text(
              _filterTagIds.isEmpty ? 'Filter' : '${_filterTagIds.length}',
              style: TextStyle(
                color: _filterTagIds.isEmpty ? textMuted : MyColors.orangeDivider,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_filterTagIds.isNotEmpty) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _filterTagIds = []);
                  _runSearch();
                },
                child: Icon(Icons.close, size: 14, color: MyColors.orangeDivider),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Search Tab ──

  Widget _searchTab() {
    final visible = _filterLinked(_searchResults);
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _search,
              style: const TextStyle(color: textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                hintStyle: const TextStyle(color: textHint),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search_rounded, color: textMuted, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: textMuted, size: 18),
                        onPressed: () { _search.clear(); _runSearch(); })
                    : null,
              ),
              onSubmitted: (_) => _runSearch(),
              onChanged: (_) {
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted) _runSearch();
                });
              },
            ),
          ),
        ),
        if (_searchLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: MyColors.orangeDivider)),
          )
        else if (visible.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    _searchResults.isEmpty ? 'No notes found' : 'All matching notes already linked',
                    style: const TextStyle(color: textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _noteResultCard(visible[i]),
                childCount: visible.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── AI Tab ──

  Widget _aiTab() {
    final visible = _filterLinked(_aiResults);
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Describe what you\'re looking for',
                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _aiPrompt,
                  maxLines: 2,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'e.g. Notes about productivity techniques',
                    hintStyle: const TextStyle(color: textHint),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _aiLoading ? null : _runAi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.orangeDivider,
                      foregroundColor: bgColor,
                      disabledBackgroundColor: MyColors.orangeDivider.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _aiLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: bgColor)),
                              const SizedBox(width: 10),
                              const Text('Searching…', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, size: 18),
                              const SizedBox(width: 8),
                              const Text('Find with AI', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (_aiResults.isEmpty && !_aiLoading)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 48, color: textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter a prompt and tap Find',
                    style: TextStyle(color: textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else if (visible.isEmpty && !_aiLoading && _aiResults.isNotEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: successColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    'All found notes already linked',
                    style: TextStyle(color: textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _noteResultCard(visible[i]),
                childCount: visible.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Note result card — text only, no title (FIX #4), premium design (FIX #5) ──

  Widget _noteResultCard(Record r) {
    final displayText = r.text.isNotEmpty ? r.text : '(empty note)';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _addRecord(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent bar
                Container(
                  width: 3,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: MyColors.orangeDivider.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Text (FIX #2: lighter text)
                Expanded(
                  child: Text(
                    displayText,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                // Add button
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MyColors.orangeDivider.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, size: 18, color: MyColors.orangeDivider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
