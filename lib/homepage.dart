import 'dart:io';

import 'package:Chrono/dialogs/confirmation-dialog.dart';
import 'package:Chrono/import_notes.dart';
import 'package:Chrono/services/data-exporter.dart';
import 'package:flutter/material.dart';
import 'package:Chrono/services/gpt-note-bind.service.dart';
import 'package:Chrono/services/messages.service.dart';
import 'package:Chrono/shared/api-key-popup.dart';
import 'package:Chrono/shared/extensions.dart';
import 'package:Chrono/tags_manager.dart';
import 'package:Chrono/api/chat-api.dart';
import 'package:Chrono/card_details.dart';
import 'package:Chrono/chat_page.dart';
import 'package:Chrono/colors.dart';
import 'package:Chrono/models/category.dart';
import 'package:Chrono/models/record.dart';
import 'package:Chrono/record.service.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'contact_list.dart';
import 'models/tag.dart';
import 'mydrawal.dart';
import 'db_manager.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key, this.recordIds}) : super(key: key);

  String? recordIds = "";

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  @override
  void initState() {
    recordService.getCountOfRecords();
    getAllTags();
    super.initState();
    if (widget.recordIds != null && widget.recordIds!.isNotEmpty) {
      //print("SEARCH FOR NOTES" + widget.recordIds.toString());
      getRecordsById(widget.recordIds!);
    } else {
      loadRecords();
    }
    _scrollController.addListener(_onScroll);
    // _scrollController.addListener(() {
    //   if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
    //     _loadMoreData();
    //   }
    // });

    recordService.importStream.listen((success) {
      if (success) {
        // Refresh the homepage or perform other related updates
        currentPage = 0;
        loadRecords(refresh: true);
      }
    });

    searchController.addListener(() {
      loadRecords(refresh: true);
    });
    // saveFakeRecord();
  }

  void _onScroll() {
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
    if (isLoading) return;

    if (refresh) {
      allRecords = [];
      currentPage = 0;
    }

    setState(() {
      isLoading = true;
    });

    getAllTags();

    // Calculate offset correctly:
    final offset = currentPage * pageSize; // Offset should be 0 for the initial load and refresh

    final newRecords = await dbHelper.getRecordsWithTag(selectedChipIndex, pageSize, offset,
        searchText: searchController.text);

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
    final newRecords = await dbHelper.getRecordsWithTag(selectedChipIndex, pageSize, offset);

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
        DatabaseHelper.columnRecordText:
            "lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam   record $count",
        DatabaseHelper.columnRecordCreatedAt:
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
  Future<void> _showDeleteDialog(BuildContext context, int id) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete record"),
          content: Text("Are you sure you want to delete this record?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Delete"),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: cardColor,
      drawer: MyDrawal(),
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
      floatingActionButton: FloatingActionButton(
        //Floating action button on Scaffold
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

          //code to execute on button press
        },
        child: Icon(Icons.add), //icon inside button
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      //floating action button location to left

      bottomNavigationBar: BottomAppBar(
        //bottom navigation bar on scaffold
        color: MyColors.trecondaryColor,
        shape: AutomaticNotchedShape(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(8),
            ),
          ),
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(17)),
          ),
        ), //shape of notch
        // notchMargin:
        //     5, //notche margin between floating button and bottom appbar
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            //children inside bottom appbar
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();

                  showModalBottomSheet(
                      context: context,
                      backgroundColor: MyColors.secondaryColor,
                      isScrollControlled: true,
                      builder: (context) {
                        return Padding(
                          padding:
                              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: TagsManager(
                            selectedTag: selectedChipIndex,
                            onTagSelected: onTagSelected,
                          ),
                        );
                      });
                },
                icon: Icon(
                  // <-- Icon
                  Icons.category,
                  size: 24.0,
                ),
                label: Text('Tags'), // <-- Text
              ),
              ElevatedButton.icon(
                icon: SvgPicture.asset(
                  'assets/icons/chat.svg', // Replace with the path to your SVG file
                  width: 30, // Specify the width
                  height: 30,
                  colorFilter: // <-- Use the color filter property to specify the
                      ColorFilter.mode(Color.fromARGB(255, 67, 0, 79), BlendMode.srcIn),
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
                label: Text('GPT'), // <-- Text
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              // focusNode: FocusNode(canRequestFocus: false),
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
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
                  fontWeight: FontWeight.w500, fontSize: 14, height: 1.5, color: Colors.white),
              // onChanged: filterRecords,
            ),
          ),
          Expanded(
            child: Form(
              key: formGlobalKey,
              child: GroupedListView<Record, DateTime>(
                controller: _scrollController,
                elements: allRecords,
                groupBy: (record) => DateTime(
                  record.createdAtDate.year,
                  record.createdAtDate.month,
                  record.createdAtDate.day,
                ),
                groupSeparatorBuilder: (DateTime date) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child:
                        //align Text by center
                        Text(
                      DateFormat('dd MMM yyyy').format(date),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ),
                itemBuilder: (context, dynamic item) {
                  List<Tag> tags = getTagsForRecord(item);
                  return GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardDetailPage(
                            title: item.title,
                            text: item.text ?? '',
                            recordId: item.id as int,
                            recordsTag: item.tagIds,
                          ),
                        ),
                      ).then((value) => loadRecords(refresh: true));
                    },
                    child: Card(
                      elevation: 0, // Поднятие карточки
                      margin: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ), // Отступы
                      color: Color.fromARGB(255, 80, 80, 80), // Цвет карточки
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // Скругление углов
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              "${item.text}",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                height: 35,
                                width: 250,
                                child: Center(
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: tags.length,
                                    // controller: _scrollController,
                                    itemBuilder: (context, index) {
                                      // Find the corresponding Tag object from allTags list
                                      Tag tag = tags[index];

                                      // Display the tag information, for example, the tag's name
                                      return Container(
                                        // width: 20,
                                        // height: 10,
                                        decoration: BoxDecoration(
                                          color: Color(int.parse(
                                              tag.color!)), // Convert color from int to Color
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(tag.name),
                                        ),
                                      );
                                      // tagIds.map((tagId) {
                                      //   Tag? tag = allTags.firstWhereOrNull(
                                      //       (element) => element.id == tagId);

                                      //   return tag != null

                                      //       : Container();
                                      // }).toList();
                                    },
                                  ),
                                ),
                              ),
                              OverflowBar(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      _showDeleteDialog(context, item.id);
                                    },
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.white30,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
    final allRows = await dbHelper.queryAllRowsofRecords();
    // allRows.forEach(print);
    allRecords = allRows;
    setState(() {});
  }

  void _delete(int id) async {
    // Assuming that the number of rows is the id for the last row.
    final rowsDeleted = await dbHelper.deleteContact(id);
    //print('deleted $rowsDeleted row(s): row $id');
    loadRecords();
  }
}
