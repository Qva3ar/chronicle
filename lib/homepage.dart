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
import 'package:chrono/shared/instructions.dart';
import 'package:chrono/tag_color_picker.dart';
import 'package:chrono/widgets/record_list_item.dart';
import 'package:chrono/services/filter_service.dart';
import 'package:chrono/widgets/insight_banner.dart';
import 'package:chrono/widgets/productivity_banner.dart';
import 'package:chrono/screens/productivity_screen.dart';
import 'package:chrono/features/checkin/presentation/widgets/checkin_dialog.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/onboarding/primary_goal_screen.dart';
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
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load filter settings first, then load records
    await _loadFilterSettings();
    await _maybeShowOnboarding();

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
        print('[HomePage] Widget launch detected: $uri');

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
        } else if (uri.host == 'open_insight') {
          // Show latest insight banner (already displayed on home page)
          print('[HomePage] Opening insight view');
        }
      }
    } catch (e) {
      print('[HomePage] Error handling widget launch: $e');
    }
  }

  Future<void> _maybeShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (done) return;
    final db = await DatabaseHelper.instance.database;
    final settings = await db.query(DatabaseTables.appSettings, limit: 1);
    final hasPrimary =
        settings.isNotEmpty && settings.first[DatabaseColumns.settingPrimaryGoalId] != null;
    if (hasPrimary) {
      await prefs.setBool('onboarding_done', true);
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrimaryGoalScreen()),
    );
    if (result == true) {
      // refresh anything if needed
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
      setState(() {
        _needsRefresh = true;
      });
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

  Widget _buildChronoQuickInputBar() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        elevation: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MyColors.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Chrono',
                  style: TextStyle(color: white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _chronoQuickController,
                  focusNode: _chronoQuickFocusNode,
                  style: const TextStyle(color: white, fontSize: 14),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitChronoQuickNote(),
                  decoration: const InputDecoration(
                    hintText: 'Quick chrono note…',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _isSubmittingChronoQuick ? null : _submitChronoQuickNote,
                icon: Icon(
                  Icons.send_rounded,
                  color: _isSubmittingChronoQuick ? Colors.white38 : MyColors.fivyColor,
                ),
                tooltip: 'Send',
              ),
            ],
          ),
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
      floatingActionButtonAnimator: _NoFabAnimation(),
      floatingActionButtonLocation: _CenterFloatAboveContent(
        bottomMargin: 12,
        keyboardHeight: MediaQuery.of(context).viewInsets.bottom,
      ),
      appBar: AppBar(
        backgroundColor: MyColors.primaryColor,
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.import_export),
            tooltip: 'Export Notes',
            onPressed: () async {
              var dataExporter = DataExporter();
              File file = await dataExporter.exportData();
              await sendEmailWithAttachment(file);
            },
          ),
        ],
        leading: widget.recordIds != null
            ? BackButton()
            : Builder(builder: (context) {
                return IconButton(
                  color: Color.fromARGB(255, 190, 190, 190),
                  icon: Icon(Icons.menu), // Change to your desired icon
                  onPressed: () {
                    // Handle the onPressed action for the alternate leading widget
                    //open drawer
                    Scaffold.of(context).openDrawer();
                  },
                );
              }),
        title: Text("CHRONO", style: TextStyle(color: Color.fromARGB(255, 190, 190, 190))),
      ),
      floatingActionButton: SizedBox(
          width: MediaQuery.of(context).size.width - 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton(
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
              ),
              const SizedBox(height: 10),
              _buildChronoQuickInputBar(),
            ],
          ),
      ),
      bottomNavigationBar: BottomAppBar(
        //bottom navigation bar on scaffold
        color: MyColors.primaryColor,
        height: 60, // Устанавливаем фиксированную высоту
        // notchMargin:
        //     5, //notche margin between floating button and bottom appbar
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Row(
            //children inside bottom appbar
            // mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showPersistentSheet((context) => const GoalsScreen(), id: 'goals');
                  },
                  icon: const Icon(
                    Icons.flag,
                    color: Colors.white,
                    size: 24.0,
                  )),
              IconButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showPersistentSheet((context) => const RoutineManagerScreen(), id: 'routines');
                  },
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 24.0,
                  )),
              IconButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showPersistentSheet((context) => const TodoListScreen(), id: 'todos');
                  },
                  icon: const Icon(
                    Icons.checklist,
                    color: Colors.white,
                    size: 24.0,
                  )),
              IconButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showPersistentSheet(
                      (context) => TagsManager(
                        selectedTag: selectedChipIndex,
                        onTagSelected: onTagSelected,
                      ),
                      id: 'tags',
                    );
                  },
                  tooltip: 'Tags',
                  icon: const Icon(
                    Icons.category,
                    color: Colors.white,
                    size: 24.0,
                  )),
              IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/chat.svg', // Replace with the path to your SVG file
                  width: 28, // Specify the width
                  height: 28,
                  // colorFilter: // <-- Use the color filter property to specify the
                  //     ColorFilter.mode(Color.fromARGB(255, 67, 0, 79), BlendMode.srcIn),
                ),
                onPressed: () {
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
      body: Stack(
        children: [
          Column(
            children: [
              const InsightBanner(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        // focusNode: FocusNode(canRequestFocus: false),
                        decoration: InputDecoration(
                          labelText: 'Search',
                          border: OutlineInputBorder(),
                          prefixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 12),
                              Icon(Icons.search, color: Colors.white70),
                              Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.filter_list, color: Colors.white70),
                                    onPressed: () => _showFilterDialog(),
                                    tooltip: 'Filter records',
                                  ),
                                  if (currentFilterSettings != null &&
                                      (!currentFilterSettings!.showGoalRecords ||
                                          !currentFilterSettings!.showRoutineRecords))
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
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
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      searchController.clear();
                                    });
                                  },
                                ),
                        ),
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white),
                        // onChanged: filterRecords,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ProductivityBanner(
                      onTap: () {
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
      content: Column(
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
        ],
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

    final normalY = geometry.contentBottom -
        fabHeight -
        geometry.bottomSheetSize.height -
        bottomMargin;

    if (keyboardHeight > 0) {
      final aboveKeyboard =
          geometry.scaffoldSize.height - keyboardHeight - fabHeight;
      return Offset(x, aboveKeyboard < normalY ? aboveKeyboard : normalY);
    }

    return Offset(x, normalY);
  }
}

class _NoFabAnimation extends FloatingActionButtonAnimator {
  @override
  Offset getOffset({required Offset begin, required Offset end, required double progress}) {
    return end;
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    return const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) {
    return const AlwaysStoppedAnimation<double>(0.0);
  }
}
