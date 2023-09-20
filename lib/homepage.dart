import 'package:flutter/material.dart';
import 'package:flutter_crud/services/messages.service.dart';
import 'package:flutter_crud/shared/extensions.dart';
import 'package:flutter_crud/tags_manager.dart';
import 'package:flutter_crud/api/chat-api.dart';
import 'package:flutter_crud/card_details.dart';
import 'package:flutter_crud/chat_page.dart';
import 'package:flutter_crud/colors.dart';
import 'package:flutter_crud/models/category.dart';
import 'package:flutter_crud/models/record.dart';
import 'package:flutter_crud/record.service.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> allCategoryData = [];
  List<Tag> allTags = [];
  List<Record> allRecords = [];
  TextEditingController _categoryName = TextEditingController();
  final formGlobalKey = GlobalKey<FormState>();
  List<int>? selectedTags = [];
  int? selectedChipIndex = null;
  int currentPage = 0;
  final MultiSelectController<dynamic> _controller = MultiSelectController();
  ScrollController _scrollController = ScrollController();
  MessageService messageServie = MessageService();

  @override
  void initState() {
    recordService.getCountOfRecords();
    getAllTags();
    super.initState();
    if (widget.recordIds != null && widget.recordIds!.isNotEmpty) {
      print("SEARCH FOR NOTES" + widget.recordIds.toString());
      getRecordsById(widget.recordIds!);
    } else {
      _loadMoreData();
    }
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreData();
      }
    });
  }

  getRecordsById(String recordIds) async {
    final newRecords = await dbHelper.getRecordsByIds(recordIds);
    allRecords.addAll(newRecords);
    setState(() {});
  }

  Future<void> loadRecords() async {
    final nextPage = currentPage + 1;
    final newRecords = await dbHelper.getRecordsWithTag(1, selectedChipIndex);
    allRecords.clear();
    if (newRecords.isNotEmpty) {
      allRecords.addAll(newRecords);
      currentPage = nextPage;
    } else {
      // allRecords = [];
      currentPage = 0;
    }
    setState(() {});
  }

  Future<void> _loadMoreData() async {
    final nextPage = currentPage + 1;
    final newRecords =
        await dbHelper.getRecordsWithTag(nextPage, selectedChipIndex);

    if (newRecords.isNotEmpty) {
      allRecords.addAll(newRecords);
      currentPage = nextPage;
    }
    setState(() {});
  }

  void onTagSelected(int selectedTag) {
    // Perform actions when a tag is selected
    print('Selected Tag in Parent: $selectedTag');
    currentPage = 0;
    selectedChipIndex = selectedTag;
    loadRecords();
  }

  void getAllTags() async {
    allTags = await recordService.queryAllTagsJust();
    // allTags = await recordService.queryAllTagsJust();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: cardColor,
      drawer: MyDrawal(),
      appBar: AppBar(
        backgroundColor: MyColors.primaryColor,
        centerTitle: true,
        leading: widget.recordIds != null
            ? BackButton()
            : IconButton(
                icon: Icon(Icons.menu), // Change to your desired icon
                onPressed: () {
                  // Handle the onPressed action for the alternate leading widget
                },
              ),
        title: Text("CHRONICLE"),
      ),
      floatingActionButton: FloatingActionButton(
        //Floating action button on Scaffold
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CardDetailPage(
                        title: "",
                        text: "",
                        recordId: null,
                      ))).then((value) => loadRecords());

          //code to execute on button press
        },
        child: Icon(Icons.add), //icon inside button
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      //floating action button location to left

      bottomNavigationBar: BottomAppBar(
        //bottom navigation bar on scaffold
        color: MyColors.trecondaryColor,
        shape: CircularNotchedRectangle(), //shape of notch
        // notchMargin:
        //     5, //notche margin between floating button and bottom appbar
        child: Row(
          //children inside bottom appbar
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                      context: context,
                      backgroundColor: MyColors.secondaryColor,
                      isScrollControlled: true,
                      builder: (context) {
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: TagsManager(
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
            ),
            Padding(
              padding: const EdgeInsets.only(left: 70),
              child: IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/chat.svg', // Replace with the path to your SVG file
                  width: 30, // Specify the width
                  height: 30,
                ),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatPage(
                                messageService: messageServie,
                              )));
                },
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: formGlobalKey,
        child: ListView.builder(
          itemCount: allRecords.length,
          padding: EdgeInsets.zero,
          controller: _scrollController,
          physics: BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            var item = allRecords[index];
            return GestureDetector(
              onTap: () {
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
                ).then((value) => loadRecords());
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
                      children: [
                        Container(
                          height: 35,
                          width: 250,
                          child: Center(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: item.tagIds.length,
                              // controller: _scrollController,
                              itemBuilder: (context, index) {
                                int tagId = item.tagIds[index];

                                // Find the corresponding Tag object from allTags list
                                Tag tag = allTags
                                    .firstWhere((tag) => tag.id == tagId);

                                // Display the tag information, for example, the tag's name
                                return Container(
                                  // width: 20,
                                  // height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(tag!
                                        .color!)), // Convert color from int to Color
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(tag!.name),
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
                        ButtonBar(
                          children: [
                            IconButton(
                              onPressed: () {
                                _delete(item.id);
                              },
                              icon: Icon(Icons.delete),
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
        ),
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
  //   print('insert stRT');

  //   final id = await dbHelper.insertRecord(row);
  //   print('inserted row id: $id');
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
    print('deleted $rowsDeleted row(s): row $id');
    _queryRecords();
  }
}
