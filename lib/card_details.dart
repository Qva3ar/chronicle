import 'dart:convert';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_crud/chat_page_note.dart';
import 'package:flutter_crud/models/enums.dart';
import 'package:flutter_crud/services/gpt-note-bind.service.dart';
import 'package:flutter_crud/services/messages.service.dart';
import 'package:flutter_crud/tags_manager.dart';
import 'package:flutter_crud/chat_page.dart';
import 'package:flutter_crud/colors.dart';
import 'package:flutter_crud/record.service.dart';
import 'package:flutter_crud/services/gpt.service.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:flutter_svg/svg.dart';

class CardDetailPage extends StatefulWidget {
  final String title;
  final String text;
  final int? recordId;
  final List<int>? recordsTag;

  const CardDetailPage({
    Key? key,
    required this.title,
    required this.text,
    this.recordId,
    this.recordsTag,
  }) : super(key: key);
  @override
  _CardDetailPageState createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  TextEditingController _titleController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();

  RecordService recordService = new RecordService();
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();
  MessageService messageServie = MessageService();

  List<MultiSelectCard<dynamic>> allRecordTags = [];
  List<MultiSelectCard<dynamic>> allTags = [];
  List<MultiSelectCard<dynamic>> gptTags = [];
  List<int>? selectedTags = [];

  GPTService gpt = GPTService();

  bool _isListeningToStream = false;

  @override
  void initState() {
    super.initState();
    if (!_isListeningToStream) {
      _isListeningToStream = true;

      recordService.setCurrentRecordId(widget.recordId ?? null);
      selectedTags = widget.recordsTag;
      getTags();
      getAllTags();

      setState(() {
        _titleController.text = widget.title;
        _descriptionController.text = widget.text;
      });

      askGpt();
      listenToTagSelection();

      gptNoteBindService.messageStream.listen((event) {
        switch (event.action) {
          case ContextActions.paste:
            _descriptionController.text =
                _descriptionController.text + '\n' + event.content;
            break;
          case ContextActions.replace:
            _descriptionController.text = event.content;
            break;
        }

        handleText(_descriptionController.text);
      });
    }

    // _titleController.addListener(() {
    //   print(_titleController.text);
    // });
  }

  askGpt() async {
    // final response = await generateResponse(
    //     'Привет, GPT-3.5!'); // Замените строку на ввод пользователя
    // print(response);
    // gpt.startStream();
  }

  listenToTagSelection() {
    recordService.gptSelectedTags.listen((value) {
      print(value);
      if (value.isNotEmpty) {
        value = value.replaceAll('[', '').replaceAll(']', '');
        // Парсим строку в List<dynamic>
        List<dynamic> dynamicList = jsonDecode('[$value]');

        // Преобразуем dynamicList в List<int>
        List<int> myList = dynamicList.map((item) => item as int).toList();
        gptTags =
            allTags.where((element) => myList.contains(element.value)).toList();
        setState(() {});
      }
    });
  }

  getTags() async {
    final tags = await recordService.queryTags(selectedTags);
    // allRows.forEach(print);
    allRecordTags = tags;
    setState(() {});
  }

  handleTitle(String title) {
    recordService.handleTitle(title);
  }

  handleText(String text) {
    recordService.handleText(text);
  }

  setTagIds() {
    allRecordTags = allRecordTags.map((e) {
      if (selectedTags != null && selectedTags!.contains(e.value)) {
        e.selected = true;
        return e;
      } else {
        return e;
      }
    }).toList();
    recordService.setTagIds(selectedTags);
  }

  void getAllTags() async {
    allTags = await recordService.queryAllTags();
    setState(() {});
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardColor,
      appBar: getAppBar(),
      body: getBody(),
      // bottomSheet: getFooter(),
      bottomNavigationBar: BottomAppBar(
        //bottom navigation bar on scaffold
        color: Color.fromARGB(255, 80, 80, 80),
        shape: CircularNotchedRectangle(), //shape of notch
        notchMargin:
            5, //notche margin between floating button and bottom appbar
        child: Row(
          //children inside bottom appbar
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            child: Card(
                              color: MyColors.primaryColor,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Open AI"),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: MultiSelectContainer(
                                          key: UniqueKey(),
                                          itemsPadding: EdgeInsets.all(10),
                                          prefix: MultiSelectPrefix(
                                              selectedPrefix: const Padding(
                                                padding:
                                                    EdgeInsets.only(right: 5),
                                                child: Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                              disabledPrefix: const Padding(
                                                padding:
                                                    EdgeInsets.only(right: 5),
                                                child: Icon(
                                                  Icons.do_disturb_alt_sharp,
                                                  size: 14,
                                                ),
                                              )),
                                          items: gptTags,
                                          // itemsDecoration: MultiSelectDecorations(decoration: InputDecoration( contentPadding: 10)),
                                          textStyles: MultiSelectTextStyles(
                                              textStyle:
                                                  TextStyle(fontSize: 16)),
                                          onChange:
                                              (allSelectedItems, selectedItem) {
                                            // var selected = selectedItem as MultiSelectCard;
                                            selectedTags = allSelectedItems
                                                .whereType<
                                                    int>() // Отфильтровать только целые числа
                                                .toList();
                                            ;
                                            setTagIds();
                                            // setState(() {
                                            //   _animals.add(MultiSelectCard(value: 1, label: "1"));
                                            // });
                                            // print(_animals.length);
                                          }),
                                    ),
                                    Text("All tags"),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: MultiSelectContainer(
                                          key: UniqueKey(),
                                          itemsPadding: EdgeInsets.all(10),
                                          prefix: MultiSelectPrefix(
                                              selectedPrefix: const Padding(
                                                padding:
                                                    EdgeInsets.only(right: 5),
                                                child: Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                              disabledPrefix: const Padding(
                                                padding:
                                                    EdgeInsets.only(right: 5),
                                                child: Icon(
                                                  Icons.do_disturb_alt_sharp,
                                                  size: 14,
                                                ),
                                              )),
                                          items: allRecordTags,
                                          // itemsDecoration: MultiSelectDecorations(decoration: InputDecoration( contentPadding: 10)),
                                          textStyles: MultiSelectTextStyles(
                                              textStyle:
                                                  TextStyle(fontSize: 16)),
                                          onChange:
                                              (allSelectedItems, selectedItem) {
                                            // var selected = selectedItem as MultiSelectCard;
                                            selectedTags = allSelectedItems
                                                .whereType<
                                                    int>() // Отфильтровать только целые числа
                                                .toList();
                                            ;
                                            setTagIds();
                                            // setState(() {
                                            //   _animals.add(MultiSelectCard(value: 1, label: "1"));
                                            // });
                                            // print(_animals.length);
                                          }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
            // IconButton(
            //   icon: Icon(
            //     Icons.menu,
            //     color: Colors.white,
            //   ),
            //   onPressed: () {},
            // ),

            IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/chat.svg', // Replace with the path to your SVG file
                  width: 30, // Specify the width
                  height: 30,
                ),
                onPressed: () {
                  showModalBottomSheet(
                      context: context,
                      backgroundColor: MyColors.secondaryColor,
                      isScrollControlled: true,
                      builder: (context) {
                        return SingleChildScrollView(
                            child: Padding(
                          padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: ChatPageNote(
                            noteText: _descriptionController.text,
                            messageService: messageServie,
                          ),
                        ));
                      });
                }),

            Padding(
              padding: const EdgeInsets.only(right: 90),
              child: IconButton(
                icon: Icon(
                  Icons.people,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget getAppBar() {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: Icon(
          Icons.arrow_back_ios,
          size: 22,
          color: white.withOpacity(0.7),
        ),
      ),
      actions: [
        IconButton(
          onPressed: null,
          icon: Icon(
            EvaIcons.pin,
            color: white.withOpacity(0.7),
            size: 22,
          ),
        ),
        IconButton(
          onPressed: null,
          icon: Icon(
            EvaIcons.wifi,
            color: white.withOpacity(0.7),
            size: 22,
          ),
        ),
        IconButton(
          onPressed: null,
          icon: Icon(
            Icons.archive,
            color: white.withOpacity(0.7),
            size: 22,
          ),
        )
      ],
    );
  }

  Widget getBody() {
    return Column(children: [
      Expanded(
        child: ListView(
          padding: EdgeInsets.only(top: 25, right: 15, bottom: 25, left: 15),
          children: [
            TextField(
              maxLines: null,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  helperStyle: TextStyle(color: Colors.white),
                  hintText: "Write your note",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3))),
              controller: _descriptionController,
              onChanged: handleText,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget getFooter() {
    var size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: 80,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: black.withOpacity(0.2), spreadRadius: 1, blurRadius: 3)
        ],
        color: cardColor,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 25, right: 10, left: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: null,
              icon: Icon(
                EvaIcons.plusSquare,
                size: 22,
                color: white.withOpacity(0.7),
              ),
            ),
            Text(
              "Edited Apr 3",
              style: TextStyle(fontSize: 12, color: white.withOpacity(0.7)),
            ),
            IconButton(
              onPressed: null,
              icon: Icon(
                EvaIcons.moreVerticalOutline,
                size: 22,
                color: white.withOpacity(0.7),
              ),
            )
          ],
        ),
      ),
    );
  }
}
