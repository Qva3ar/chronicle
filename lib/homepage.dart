import 'dart:developer';
import 'dart:io';

import 'package:chrono/screens/goals_screen.dart';
import 'package:chrono/services/data-exporter.dart';
import 'package:flutter/material.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/services/messages.service.dart';
import 'package:chrono/shared/api-key-popup.dart';
import 'package:chrono/tags_manager.dart';
import 'package:chrono/card_details.dart';
import 'package:chrono/chat_page.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/models/record_type.dart';
import 'package:chrono/record.service.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:intl/intl.dart';
import 'models/tag.dart';
import 'mydrawal.dart';
import 'db_manager.dart';
import 'package:chrono/screens/routine_manager_screen.dart';
import 'package:chrono/screens/goal_manager_screen.dart';
import 'package:chrono/screens/todo_list_screen.dart';
import 'package:chrono/screens/workspace_list_sheet.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/shared/instructions.dart';
import 'package:chrono/tag_color_picker.dart';
import 'package:chrono/widgets/record_list_item.dart';
import 'package:chrono/services/filter_service.dart';
import 'package:chrono/shared/premium_gate.dart';
import 'package:chrono/widgets/productivity_banner.dart';
import 'package:chrono/screens/productivity_screen.dart';
import 'package:chrono/features/checkin/presentation/widgets/checkin_dialog.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/services/widget_service.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

class HomePage extends StatefulWidget {
  HomePage({Key? key, this.recordIds}) : super(key: key);

  String? recordIds = "";

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  PersistentBottomSheetController? _bottomSheetController;
  String? _activeSheetId;
  RecordService recordService = new RecordService();
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();

  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> allCategoryData = [];
  List<Tag> allTags = [];
  List<Record> allRecords = [];
  final formGlobalKey = GlobalKey<FormState>();
  List<int>? selectedTags = [];
  int? selectedChipIndex = null;
  int currentPage = 0;
  int pageSize = 20;
  TextEditingController searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  MessageService messageServie = MessageService();
  bool isLoading = false; // Add a loading flag
  bool _needsRefresh = false;
  bool isRefreshing = false;
  StreamSubscription<Record>? _recordCreatedSubscription;
  StreamSubscription<int>? _productivityUpdatedSubscription;
  FilterService filterService = FilterService.instance;
  FilterSettings? currentFilterSettings;
  final TextEditingController _chronoQuickController = TextEditingController();
  final FocusNode _chronoQuickFocusNode = FocusNode();
  bool _isSubmittingChronoQuick = false;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    recordService.getCountOfRecords();
    getAllTags();
    // Route notification taps through the Scaffold sheet so they open attached
    // to the bottom nav bar, like tapping the nav menu.
    NotificationService.openHomeSheet = _openSheetFromNotification;
    super.initState();
    _initializeApp();
  }

  /// Opens a nav-bar sheet in response to a notification tap. Returns true when
  /// handled so [NotificationService] skips its root modal fallback.
  bool _openSheetFromNotification(String sheetId, {int? highlightTodoId}) {
    if (!mounted) return false;
    // Already showing this sheet — treat the tap as a no-op rather than toggling
    // it closed (which is what re-tapping the nav item would do).
    if (_activeSheetId == sheetId) return true;

    switch (sheetId) {
      case 'goals':
        _showDraggablePersistentSheet(
          id: 'goals',
          builder: (context, scrollController, _) =>
              GoalsScreen(sheetScrollController: scrollController),
        );
        return true;
      case 'routines':
        _showDraggablePersistentSheet(
          id: 'routines',
          builder: (context, scrollController, _) =>
              RoutineManagerScreen(sheetScrollController: scrollController),
        );
        return true;
      case 'todos':
        _showDraggablePersistentSheet(
          id: 'todos',
          builder: (context, scrollController, _) => TodoListScreen(
            sheetScrollController: scrollController,
            highlightTodoId: highlightTodoId,
          ),
        );
        return true;
    }
    return false;
  }

  Future<void> _initializeApp() async {
    // Load filter settings first, then load records
    await _loadFilterSettings();
    // Onboarding is now handled in main.dart before HomePage loads

    // Check for widget deep link launch
    await _handleWidgetLaunch();

    if (widget.recordIds != null && widget.recordIds!.isNotEmpty) {
      //print("SEARCH FOR NOTES" + widget.recordIds.toString());
      getRecordsById(widget.recordIds!);
    } else {
      loadRecords();
    }

    _setupListeners();
  }

  Future<void> _handleWidgetLaunch() async {
    try {
      final uri = await WidgetService.getWidgetLaunchUri();
      if (uri != null) {
        if (uri.host == 'create_note') {
          // Open create note screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CardDetailPage(
                          title: "",
                          text: "",
                          recordId: null,
                          recordsTag: [],
                        )));
          });
        }
      }
    } catch (e) {
      print('[HomePage] Error handling widget launch: $e');
    }
  }


  void _setupListeners() {
    _scrollController.addListener(_onScroll);
    // _scrollController.addListener(() {
    //   if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
    //     _loadMoreData();
    //   }
    // });

    searchController.addListener(() {
      loadRecords(refresh: true);
    });

    recordService.importStream.listen((success) {
      if (success) {
        // Refresh the homepage or perform other related updates
        currentPage = 0;
        loadRecords(refresh: true);
      }
    });

    _recordCreatedSubscription = recordService.recordCreatedStream.listen((record) {
      if (mounted) {
        setState(() {
          allRecords.insert(0, record);
        });
      }
    });

    _productivityUpdatedSubscription =
        ProductivityService.instance.onProductivityUpdated.listen((recordId) async {
      if (!mounted || recordId < 0) return;
      try {
        final updated = await dbHelper.getRecordsByIds(recordId.toString());
        if (updated.isEmpty) return;
        final newRecord = updated.first;
        if (!mounted) return;
        setState(() {
          final idx = allRecords.indexWhere((r) => r.id == recordId);
          if (idx >= 0) {
            allRecords[idx] = newRecord;
          } else {
            allRecords.insert(0, newRecord);
          }
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    if (identical(NotificationService.openHomeSheet, _openSheetFromNotification)) {
      NotificationService.openHomeSheet = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _recordCreatedSubscription?.cancel();
    _productivityUpdatedSubscription?.cancel();
    _chronoQuickController.dispose();
    _chronoQuickFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately refresh records and productivity score when returning
      // from background. A routine may have been completed via notification
      // action in a background isolate, updating the DB but not the in-memory
      // stream. Without an immediate refresh the stale productivity record
      // would remain visible until the user scrolls to the top.
      loadRecords(refresh: true);
      ProductivityService.instance.createOrUpdateDailyRecord();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == 0 && _needsRefresh) {
      loadRecords(refresh: true);
      setState(() {
        _needsRefresh = false;
      });
    }

    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !isLoading) {
      // Check if not already loading
      loadRecords();
    }
  }

  getRecordsById(String recordIds) async {
    final newRecords = await dbHelper.getRecordsByIds(recordIds);
    allRecords.addAll(newRecords);
    setState(() {});
  }

  Future<void> loadRecords({bool refresh = false}) async {
    if (isLoading || isRefreshing) return;

    if (refresh) {
      setState(() {
        isRefreshing = true;
        currentPage = 0; // Reset page counter
      });

      getAllTags();

      // Load records with the current tag filter from the beginning
      final newRecords = await dbHelper.getRecordsWithTag(
        selectedChipIndex,
        pageSize,
        0,
        searchText: searchController.text,
        showGoalRecords: currentFilterSettings?.showGoalRecords,
        showRoutineRecords: currentFilterSettings?.showRoutineRecords,
        showTodoRecords: currentFilterSettings?.showTodoRecords,
        showProductivityRecords: currentFilterSettings?.showProductivityRecords,
      );

      setState(() {
        allRecords = newRecords; // Replace all records in one atomic operation
        if (newRecords.isNotEmpty) {
          currentPage = 1; // Set to 1 since we loaded the first page
        }
        isRefreshing = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    getAllTags();

    // Calculate offset correctly:
    final offset = currentPage * pageSize; // Offset should be 0 for the initial load and refresh

    final newRecords = await dbHelper.getRecordsWithTag(
      selectedChipIndex,
      pageSize,
      offset,
      searchText: searchController.text,
      showGoalRecords: currentFilterSettings?.showGoalRecords,
      showRoutineRecords: currentFilterSettings?.showRoutineRecords,
      showTodoRecords: currentFilterSettings?.showTodoRecords,
      showProductivityRecords: currentFilterSettings?.showProductivityRecords,
    );

    setState(() {
      if (newRecords.isNotEmpty) {
        allRecords.addAll(newRecords);
        currentPage++; // Increment currentPage after loading
      }
      isLoading = false;
    });
  }

  Future<void> _loadMoreData() async {
    final nextPage = currentPage + 1;
    final offset = nextPage * pageSize;
    final newRecords = await dbHelper.getRecordsWithTag(
      selectedChipIndex,
      pageSize,
      offset,
      showGoalRecords: currentFilterSettings?.showGoalRecords,
      showRoutineRecords: currentFilterSettings?.showRoutineRecords,
      showTodoRecords: currentFilterSettings?.showTodoRecords,
      showProductivityRecords: currentFilterSettings?.showProductivityRecords,
    );

    if (newRecords.isNotEmpty) {
      allRecords.addAll(newRecords);
      this.recordService.setRecords(newRecords);
      currentPage = nextPage;
      setState(() {});
    }
  }

  //save fake record 100 times
  Future<void> saveFakeRecord() async {
    for (var i = 0; i < 100; i++) {
      int count = i * 2;
      Map<String, dynamic> row = {
        DatabaseColumns.recordText:
            "lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam   record $count",
        DatabaseColumns.recordCreatedAt:
            DateTime.now().subtract(Duration(days: i)).millisecondsSinceEpoch
      };
      final id = await dbHelper.insertRecord(row, [2, 3]);
      //print('inserted row id: $id');
    }
  }

  void onTagSelected(int? selectedTag) {
    // Perform actions when a tag is selected
    //print('Selected Tag in Parent: $selectedTag');
    currentPage = 0;
    selectedChipIndex = selectedTag;
    loadRecords(refresh: true);
  }

  void getAllTags() async {
    allTags = await recordService.queryAllTagsJust();
    // allTags = await recordService.queryAllTagsJust();
    setState(() {});
  }

  Tag? findTagById(int id) {
    return allTags.firstWhere((tag) => tag.id == id);
  }

  List<Tag> getTagsForRecord(Record record) {
    return record.tagIds
        .map((id) => findTagById(id))
        .where((tag) => tag != null)
        .cast<Tag>()
        .toList();
  }

  Future<void> sendEmailWithAttachment(File file) async {
    final Email email = Email(
      body: 'Here is the backup of all notes and tags.',
      subject: 'Backup of Notes',
      recipients: [], // Optionally add default recipient email addresses
      attachmentPaths: [file.path],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
  }

  Future<void> _showApiKeyPopup(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return ApiKeyPopup();
      },
    );
  }

  //dialog for delete
  Future<void> _loadFilterSettings() async {
    currentFilterSettings = await filterService.getFilterSettings();
    debugPrint(
        '🔍 Filter settings loaded: showGoals=${currentFilterSettings?.showGoalRecords}, showRoutines=${currentFilterSettings?.showRoutineRecords}');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showFilterDialog() async {
    if (currentFilterSettings == null) {
      await _loadFilterSettings();
    }

    if (!mounted) return;

    final FilterSettings? result = await showDialog<FilterSettings>(
      context: context,
      builder: (BuildContext context) {
        return FilterDialog(initialSettings: currentFilterSettings!);
      },
    );

    if (result != null && mounted) {
      await filterService.saveFilterSettings(result);
      currentFilterSettings = result;
      loadRecords(refresh: true);
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, int id) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete record"),
          content: const Text("Are you sure you want to delete this record?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Delete"),
              onPressed: () {
                _delete(id);

                Navigator.of(context).pop();
                loadRecords(refresh: true);
              },
            ),
          ],
        );
      },
    );
  }

  void _closePersistentBottomSheet() {
    try {
      _bottomSheetController?.close();
    } catch (_) {}
    _bottomSheetController = null;
    _activeSheetId = null;
  }

  void _showPersistentSheet(WidgetBuilder builder, {required String id}) {
    if (_activeSheetId == id) {
      _closePersistentBottomSheet();
      setState(() {});
      return;
    }

    _closePersistentBottomSheet();

    final controller = _scaffoldKey.currentState?.showBottomSheet(
      builder,
      backgroundColor: cardColor,
    );
    if (controller != null) {
      setState(() {
        _bottomSheetController = controller;
        _activeSheetId = id;
      });
      controller.closed.then((_) {
        if (_bottomSheetController == controller) {
          setState(() {
            _bottomSheetController = null;
            _activeSheetId = null;
          });
          loadRecords(refresh: true);
        }
      });
    }
  }

  /// Goals / Routines / Todo: [DraggableScrollableSheet] so pulling down on scrollable content
  /// shrinks and dismisses the sheet; list stays scrollable when not at the top.
  void _showDraggablePersistentSheet({
    required String id,
    required Widget Function(BuildContext context, ScrollController scrollController, DraggableScrollableController dragController) builder,
  }) {
    if (_activeSheetId == id) {
      _closePersistentBottomSheet();
      setState(() {});
      return;
    }

    _closePersistentBottomSheet();

    final dragController = DraggableScrollableController();
    PersistentBottomSheetController? sheetController;
    var dismissScheduled = false;

    void tryDismissSheet() {
      if (!mounted || dismissScheduled) return;
      if (!dragController.isAttached) return;
      if (dragController.size < 0.05) {
        dismissScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final sc = sheetController;
          if (sc != null && _bottomSheetController == sc) {
            sc.close();
          }
        });
      }
    }

    sheetController = _scaffoldKey.currentState?.showBottomSheet(
      (context) => DraggableScrollableSheet(
        controller: dragController,
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.0,
        maxChildSize: 0.92,
        builder: (context, scrollController) => builder(context, scrollController, dragController),
      ),
      backgroundColor: Colors.transparent,
    );

    dragController.addListener(tryDismissSheet);

    if (sheetController != null) {
      setState(() {
        _bottomSheetController = sheetController;
        _activeSheetId = id;
      });
      sheetController.closed.then((_) {
        dragController.removeListener(tryDismissSheet);
        if (_bottomSheetController == sheetController) {
          setState(() {
            _bottomSheetController = null;
            _activeSheetId = null;
          });
          loadRecords(refresh: true);
        }
      });
    }
  }

  Future<int?> _getChronoTagId() async {
    try {
      for (final t in allTags) {
        if (t.name == 'Chrono') return t.id;
      }

      final rows = await dbHelper.queryAllRows();
      for (final row in rows) {
        if (row[DatabaseColumns.tagName] == 'Chrono') {
          return row[DatabaseColumns.id] as int?;
        }
      }
      // Fallback: use system tag if Chrono was renamed before migration
      for (final row in rows) {
        if ((row[DatabaseColumns.tagIsSystem] ?? 0) == 1) {
          return row[DatabaseColumns.id] as int?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitChronoQuickNote() async {
    if (_isSubmittingChronoQuick) return;
    final text = _chronoQuickController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmittingChronoQuick = true;
    });

    try {
      final chronoId = await _getChronoTagId();
      if (chronoId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chrono tag not found. Please restart the app.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final row = <String, dynamic>{
        DatabaseColumns.recordText: text,
        DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
        DatabaseColumns.recordType: 'regular',
      };

      await recordService.createRecord(row, [chronoId]);

      _chronoQuickController.clear();
      _chronoQuickFocusNode.unfocus();

      if (!mounted) return;

      await loadRecords(refresh: true);

      if (selectedChipIndex != null && selectedChipIndex != chronoId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chrono note added'),
            action: SnackBarAction(
              label: 'Show',
              onPressed: () => onTagSelected(chronoId),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create Chrono note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingChronoQuick = false;
        });
      }
    }
  }

  void _showChronoInfoPopup(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.access_time_rounded, color: MyColors.orangeDivider, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chronological notes',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'The Chrono tag is for timeline notes — quick logs of what happens during your day:\n\n'
            '• visited a place\n'
            '• something happened\n'
            '• currently at a location\n'
            '• met someone\n\n'
            'Use the quick input to capture moments as they happen.',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got it',
                style: TextStyle(color: MyColors.orangeDivider, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChronoQuickInputBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _chronoQuickFocusNode.hasFocus
            ? [
                BoxShadow(
                    color: MyColors.orangeDivider.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 2)
              ]
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
        border: Border.all(
          color: _chronoQuickFocusNode.hasFocus
              ? MyColors.orangeDivider.withValues(alpha: 0.5)
              : cardBorder.withValues(alpha: 0.4),
          width: _chronoQuickFocusNode.hasFocus ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showChronoInfoPopup(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Chrono',
                      style:
                          TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _chronoQuickController,
              focusNode: _chronoQuickFocusNode,
              style: const TextStyle(color: textPrimary, fontSize: 14),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitChronoQuickNote(),
              decoration: const InputDecoration(
                hintText: 'Quick chrono note...',
                hintStyle: TextStyle(color: textHint),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _isSubmittingChronoQuick
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: MyColors.orangeDivider),
                  ),
                )
              : IconButton(
                  onPressed: _submitChronoQuickNote,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.send_rounded,
                    size: 22,
                    color:
                        _chronoQuickController.text.isNotEmpty ? MyColors.orangeDivider : textMuted,
                  ),
                  tooltip: 'Send',
                ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    // Determine if active based on current sheet (for visual feedback)
    bool isActive = false;
    if (label == 'Goals' && _activeSheetId == 'goals') isActive = true;
    if (label == 'Routines' && _activeSheetId == 'routines') isActive = true;
    if (label == 'Todo' && _activeSheetId == 'todos') isActive = true;
    if (label == 'Tags' && _activeSheetId == 'tags') isActive = true;
    if (label == 'Workspace' && _activeSheetId == 'workspaces') isActive = true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color:
                    isActive ? MyColors.orangeDivider.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? MyColors.orangeDivider : textMuted,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: cardColor,
      drawer: const MyDrawal(),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButtonLocation: _CenterFloatAboveContent(
        bottomMargin: 12,
        keyboardHeight: MediaQuery.of(context).viewInsets.bottom,
      ),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0, // Disable material 3 scroll tinting
        centerTitle: true,
        // actions: <Widget>[
        //   IconButton(
        //     icon: const Icon(Icons.import_export, color: textMuted),
        //     tooltip: 'Export Notes',
        //     onPressed: () async {
        //       var dataExporter = DataExporter();
        //       File file = await dataExporter.exportData();
        //       await sendEmailWithAttachment(file);
        //     },
        //   ),
        // ],
        leading: widget.recordIds != null
            ? const BackButton(color: textPrimary)
            : Builder(builder: (context) {
                return IconButton(
                  color: textMuted,
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              }),
        title: const Text(
          "CHRONO",
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: surfaceElevated,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: 'Tags',
                      icon: Icon(
                        Icons.grid_view_rounded,
                        color: _activeSheetId == 'tags' ? MyColors.orangeDivider : textSecondary,
                        size: 26,
                      ),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        _showDraggablePersistentSheet(
                          id: 'tags',
                          builder: (context, scrollController, dragController) => TagsManager(
                            selectedTag: selectedChipIndex,
                            onTagSelected: onTagSelected,
                            sheetScrollController: scrollController,
                            sheetDragController: dragController,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    backgroundColor: MyColors.secondaryColor,
                    heroTag: 'addButton',
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CardDetailPage(
                                    title: "",
                                    text: "",
                                    recordId: null,
                                  ))).then((value) => loadRecords(refresh: true));
                    },
                    child: Icon(Icons.add, color: MyColors.fivyColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildChronoQuickInputBar(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceElevated,
          border: Border(
            top: BorderSide(color: cardBorder.withValues(alpha: 0.5), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icon(
                    Icons.flag_rounded,
                    color: _activeSheetId == 'goals' ? MyColors.orangeDivider : textSecondary,
                    size: 26,
                  ),
                  label: 'Goals',
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showDraggablePersistentSheet(
                      id: 'goals',
                      builder: (context, scrollController, _) =>
                          GoalsScreen(sheetScrollController: scrollController),
                    );
                  },
                ),
                _buildNavItem(
                  icon: Icon(
                    Icons.loop_rounded,
                    color: _activeSheetId == 'routines' ? MyColors.orangeDivider : textSecondary,
                    size: 26,
                  ),
                  label: 'Routines',
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showDraggablePersistentSheet(
                      id: 'routines',
                      builder: (context, scrollController, _) =>
                          RoutineManagerScreen(sheetScrollController: scrollController),
                    );
                  },
                ),
                _buildNavItem(
                  icon: Icon(
                    Icons.checklist_rounded,
                    color: _activeSheetId == 'todos' ? MyColors.orangeDivider : textSecondary,
                    size: 26,
                  ),
                  label: 'Todo',
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showDraggablePersistentSheet(
                      id: 'todos',
                      builder: (context, scrollController, _) =>
                          TodoListScreen(sheetScrollController: scrollController),
                    );
                  },
                ),
                _buildNavItem(
                  icon: Icon(
                    Icons.workspaces_outlined,
                    color: _activeSheetId == 'workspaces' ? MyColors.orangeDivider : textSecondary,
                    size: 26,
                  ),
                  label: 'Workspace',
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showDraggablePersistentSheet(
                      id: 'workspaces',
                      builder: (context, scrollController, _) => WorkspaceListSheet(
                        sheetScrollController: scrollController,
                      ),
                    );
                  },
                ),
                _buildNavItem(
                  icon: SvgPicture.asset(
                    'assets/icons/chat.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                  label: 'AI Chat',
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    if (gptNoteBindService.isKeyProvided()) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatPage(
                                    messageService: messageServie,
                                  )));
                    } else {
                      _showApiKeyPopup(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // InsightBanner hidden - AI insights feature disabled
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: cardColor2,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder, width: 0.5),
                        ),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(color: textPrimary, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Search records...',
                            hintStyle: const TextStyle(color: textHint),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 14),
                                const Icon(Icons.search, color: textMuted, size: 20),
                                const SizedBox(width: 4),
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.tune_rounded,
                                          color: textSecondary, size: 20),
                                      onPressed: _showFilterDialog,
                                      tooltip: 'Filter records',
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                    if (currentFilterSettings != null &&
                                        (!currentFilterSettings!.showGoalRecords ||
                                            !currentFilterSettings!.showRoutineRecords ||
                                            !currentFilterSettings!.showTodoRecords ||
                                            !currentFilterSettings!.showProductivityRecords))
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: MyColors.orangeDivider,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: cardColor2, width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            suffixIcon: searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear, color: textMuted, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        searchController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ProductivityBanner(
                      onTap: () {
                        if (!checkPremiumOrShowPaywall(context)) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProductivityScreen()),
                        ).then((_) {
                          if (mounted) loadRecords(refresh: true);
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: formGlobalKey,
                  child: GroupedListView<Record, String>(
                    controller: _scrollController,
                    elements: allRecords,
                    padding: const EdgeInsets.only(bottom: 160),
                    groupBy: (record) {
                      String groupDate = DateFormat('yyyy-MM-dd').format(record.createdAtDate);
                      return groupDate;
                    },
                    groupSeparatorBuilder: (String dateString) {
                      DateTime date = DateFormat('yyyy-MM-dd').parse(dateString);
                      debugPrint(
                          'Building group separator for date: ${DateFormat('dd MMM yyyy').format(date)}');
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child:
                              //align Text by center
                              Text(
                            DateFormat('dd MMM yyyy').format(date),
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      );
                    },
                    groupHeaderBuilder: (Record record) => SizedBox.shrink(),
                    itemBuilder: (context, item) {
                      List<Tag> tags = getTagsForRecord(item);
                      return RecordListItem(
                        item: item,
                        tags: tags,
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();

                          // Check if it's a checkin - open CheckinDialog instead of CardDetailPage
                          if (item.recordType == RecordType.morningCheckin ||
                              item.recordType == RecordType.eveningCheckin) {
                            // Determine checkin type
                            final checkinType = item.recordType == RecordType.morningCheckin
                                ? CheckinType.morning
                                : CheckinType.evening;

                            // Open checkin dialog with existing record
                            CheckinDialog.show(
                              context,
                              checkinType,
                              existingRecord: item.toMap(),
                            ).then((_) => loadRecords(refresh: true));
                            return;
                          }

                          // For non-checkin records, open normal edit page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CardDetailPage(
                                title: item.title,
                                text: item.text ?? '',
                                recordId: item.id as int,
                                recordsTag: item.tagIds,
                                isLocked: item.isLocked,
                              ),
                            ),
                          ).then((value) => loadRecords(refresh: true));
                        },
                        onDelete: (id) {
                          _showDeleteDialog(context, id);
                        },
                      );
                    },

                    itemComparator: (item1, item2) =>
                        item1.createdAt.compareTo(item2.createdAt), // optional
                    useStickyGroupSeparators: true, // optional
                    floatingHeader: true, // optional
                    order: GroupedListOrder.DESC, // optional
                    reverse: true,
                  ),
                ),
              ),
            ],
          ),
          if (_bottomSheetController != null)
            GestureDetector(
              onTap: () {
                _closePersistentBottomSheet();
                setState(() {});
              },
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
        ],
      ),
    ));
  }

  // void insertRecord() async {
  //   // row to insert
  //   Map<String, dynamic> row = {
  //     DatabaseHelper.columnRecordText: _categoryName.text,
  //     DatabaseHelper.columnRecordCreatedAt:
  //         DateTime.now().millisecondsSinceEpoch
  //   };
  //   //print('insert stRT');

  //   final id = await dbHelper.insertRecord(row);
  //   //print('inserted row id: $id');
  //   _categoryName.text = "";
  //   _queryRecords();
  // }

  void _queryRecords() async {
    final allRecords = await dbHelper.queryAllRecords();
    // allRows.forEach(print);
    // allRecords = allRecords;
    setState(() {});
  }

  void _delete(int id) async {
    // Assuming that the number of rows is the id for the last row.
    final rowsDeleted = await dbHelper.deleteContact(id);
    setState(() {
      allRecords.removeWhere((record) => record.id == id);
    });
    //print('deleted $rowsDeleted row(s): row $id');
  }
}

class FilterDialog extends StatefulWidget {
  final FilterSettings initialSettings;

  const FilterDialog({Key? key, required this.initialSettings}) : super(key: key);

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late FilterSettings settings;

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardColor,
      title: const Text(
        'Filter Records',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select which types of records to show:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(
              'Show records from Goals',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Include records created from goal sessions',
              style: TextStyle(color: Colors.white60),
            ),
            value: settings.showGoalRecords,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(showGoalRecords: value);
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text(
              'Show records from Routines',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Include records created from completed routines',
              style: TextStyle(color: Colors.white60),
            ),
            value: settings.showRoutineRecords,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(showRoutineRecords: value);
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text(
              'Show records from Todos',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Include records created from completed todos',
              style: TextStyle(color: Colors.white60),
            ),
            value: settings.showTodoRecords,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(showTodoRecords: value);
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text(
              'Show Productivity Index',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Include daily productivity score records',
              style: TextStyle(color: Colors.white60),
            ),
            value: settings.showProductivityRecords,
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(showProductivityRecords: value);
              });
            },
          ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Apply'),
          onPressed: () {
            Navigator.of(context).pop(settings);
          },
        ),
      ],
    );
  }
}

class _CenterFloatAboveContent extends FloatingActionButtonLocation {
  final double bottomMargin;
  final double keyboardHeight;

  const _CenterFloatAboveContent({
    required this.bottomMargin,
    this.keyboardHeight = 0,
  });

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final fabWidth = geometry.floatingActionButtonSize.width;
    final fabHeight = geometry.floatingActionButtonSize.height;
    final x = (geometry.scaffoldSize.width - fabWidth) / 2.0;

    final normalY =
        geometry.contentBottom - fabHeight - geometry.bottomSheetSize.height - bottomMargin;

    if (keyboardHeight > 0) {
      final aboveKeyboard = geometry.scaffoldSize.height - keyboardHeight - fabHeight;
      return Offset(x, aboveKeyboard < normalY ? aboveKeyboard : normalY);
    }

    return Offset(x, normalY);
  }
}
