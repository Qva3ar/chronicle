import 'dart:convert';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:Chrono/chat_page_note.dart';
import 'package:Chrono/models/enums.dart';
import 'package:Chrono/services/gpt-note-bind.service.dart';
import 'package:Chrono/services/messages.service.dart';
import 'package:Chrono/shared/api-key-popup.dart';
import 'package:Chrono/colors.dart';
import 'package:Chrono/features/notes/data/db/record.service.dart';
import 'package:Chrono/services/gpt.service.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:flutter_svg/svg.dart';

class CardDetailPage extends StatefulWidget {
  final String title;
  final String text;
  final int? recordId;
  final List<int>? recordsTag;
  final bool isGenerated;

  const CardDetailPage({
    Key? key,
    required this.title,
    required this.text,
    this.recordId,
    this.recordsTag,
    required this.isGenerated
  }) : super(key: key);
  @override
  _CardDetailPageState createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  TextEditingController _titleController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  RecordService recordService = new RecordService();
  GPTNoteBindService gptNoteBindService = GPTNoteBindService();
  MessageService messageServie = MessageService();

  List<MultiSelectCard<dynamic>> allRecordTags = [];
  List<MultiSelectCard<dynamic>> allTags = [];
  List<MultiSelectCard<dynamic>> gptTags = [];
  List<int>? selectedTags = [];

  GPTService gpt = GPTService();

  bool _isListeningToStream = false;
  int _isGenerated = 0;


  List<String> undoStack = [];
  List<String> redoStack = [];

  @override
  void initState() {
    super.initState();
    recordService.clearTagIds();
    if (!_isListeningToStream) {
      _isListeningToStream = true;

      recordService.setCurrentRecordId(widget.recordId ?? null);
      selectedTags = widget.recordsTag;
      recordService.setTagIds(selectedTags);
      getTags();
      getAllTags();

      setState(() {
        _titleController.text = widget.title;
        _descriptionController.text = widget.text;
        _isGenerated = widget.isGenerated ? 1 : 0;
      });

      askGpt();
      listenToTagSelection();

      gptNoteBindService.messageStream.listen((event) {
        switch (event.action) {
          case ContextActions.paste:
            _descriptionController.text = _descriptionController.text + '\n' + event.content;
            break;
          case ContextActions.replace:
            _descriptionController.text = event.content;
            break;
        }

        handleText(_descriptionController.text);
      });
    }

    // _titleController.addListener(() {
    //   //print(_titleController.text);
    // });

    undoRedoListen();
  }

  undoRedoListen() {
    // Добавляем начальный текст в стек undo
    undoStack.add(_descriptionController.text);

    // Добавляем слушатель изменений текста
    _descriptionController.addListener(() {
      if (_descriptionController.text != (undoStack.isEmpty ? '' : undoStack.last)) {
        undoStack.add(_descriptionController.text);
        redoStack.clear(); // Очищаем redoStack, если появляется новое состояние текста
        setState(() {});
      }
    });
  }

  askGpt() async {
    // final response = await generateResponse(
    //     'Привет, GPT-3.5!'); // Замените строку на ввод пользователя
    // //print(response);
    // gpt.startStream();
  }

  listenToTagSelection() {
    recordService.gptSelectedTags.listen((value) {
      // //print(value);
      if (value.isNotEmpty) {
        value = value.replaceAll('[', '').replaceAll(']', '');
        // Парсим строку в List<dynamic>
        List<dynamic> dynamicList = jsonDecode('[$value]');

        // Преобразуем dynamicList в List<int>
        List<int> myList = dynamicList.map((item) => item as int).toList();
        gptTags = allTags.where((element) => myList.contains(element.value)).toList();
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

  handleIsGenerated(int isGenerated) {
    recordService.handleIsGenerated(isGenerated);
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

  void undo() {
    if (undoStack.length > 1) {
      setState(() {
        redoStack.add(undoStack.removeLast());
        _descriptionController.text = undoStack.last;
        _descriptionController.selection =
            TextSelection.fromPosition(TextPosition(offset: _descriptionController.text.length));
      });
      handleText(_descriptionController.text);
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      setState(() {
        String restoredText = redoStack.removeLast();
        undoStack.add(restoredText);
        _descriptionController.text = restoredText;
        _descriptionController.selection =
            TextSelection.fromPosition(TextPosition(offset: _descriptionController.text.length));
      });
      handleText(_descriptionController.text);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  showTagsModal() {
    showModalBottomSheet(
        context: context,
        backgroundColor: MyColors.secondaryColor,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      // Text("Open AI"),
                      // Padding(
                      //   padding: const EdgeInsets.only(bottom: 16),
                      //   child: MultiSelectContainer(
                      //       key: UniqueKey(),
                      //       itemsPadding: EdgeInsets.all(10),
                      //       prefix: MultiSelectPrefix(
                      //           selectedPrefix: const Padding(
                      //             padding: EdgeInsets.only(right: 5),
                      //             child: Icon(
                      //               Icons.check,
                      //               color: Colors.white,
                      //               size: 14,
                      //             ),
                      //           ),
                      //           disabledPrefix: const Padding(
                      //             padding: EdgeInsets.only(right: 5),
                      //             child: Icon(
                      //               Icons.do_disturb_alt_sharp,
                      //               size: 14,
                      //             ),
                      //           )),
                      //       items: gptTags,
                      //       // itemsDecoration: MultiSelectDecorations(decoration: InputDecoration( contentPadding: 10)),
                      //       textStyles: MultiSelectTextStyles(textStyle: TextStyle(fontSize: 16)),
                      //       onChange: (allSelectedItems, selectedItem) {
                      //         // var selected = selectedItem as MultiSelectCard;
                      //         selectedTags = allSelectedItems
                      //             .whereType<int>() // Отфильтровать только целые числа
                      //             .toList();
                      //         ;
                      //         setTagIds();
                      //         // setState(() {
                      //         //   _animals.add(MultiSelectCard(value: 1, label: "1"));
                      //         // });
                      //         // //print(_animals.length);
                      //       }),
                      // ),
                      Text("All tags"),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: MultiSelectContainer(
                            key: UniqueKey(),
                            itemsPadding: EdgeInsets.all(10),
                            prefix: MultiSelectPrefix(
                                selectedPrefix: const Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                disabledPrefix: const Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(
                                    Icons.do_disturb_alt_sharp,
                                    size: 14,
                                  ),
                                )),
                            items: allRecordTags,
                            // itemsDecoration: MultiSelectDecorations(decoration: InputDecoration( contentPadding: 10)),
                            textStyles: MultiSelectTextStyles(textStyle: TextStyle(fontSize: 16)),
                            onChange: (allSelectedItems, selectedItem) {
                              // var selected = selectedItem as MultiSelectCard;
                              selectedTags = allSelectedItems
                                  .whereType<int>() // Отфильтровать только целые числа
                                  .toList();
                              ;
                              setTagIds();
                              // setState(() {
                              //   _animals.add(MultiSelectCard(value: 1, label: "1"));
                              // });
                              // //print(_animals.length);
                            }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  showChatModal() {
    showModalBottomSheet(
        context: context,
        backgroundColor: MyColors.secondaryColor,
        isScrollControlled: true,
        builder: (context) {
          return SingleChildScrollView(
              child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: ChatPageNote(
              noteText: _descriptionController.text,
              messageService: messageServie,
            ),
          ));
        });
  }

  Future<void> _showApiKeyPopup(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return ApiKeyPopup();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardColor,
      appBar: getAppBar(),
      body: getBody(),
      resizeToAvoidBottomInset: true,
      // bottomSheet: getFooter(),
      // bottomNavigationBar: BottomAppBar(
      //   //bottom navigation bar on scaffold
      //   color: Color.fromARGB(255, 80, 80, 80),
      //   shape: CircularNotchedRectangle(), //shape of notch
      //   notchMargin: 5, //notche margin between floating button and bottom appbar
      //   child: Padding(
      //     padding: const EdgeInsets.symmetric(horizontal: 16),
      //     child: Row(
      //       //children inside bottom appbar
      //       mainAxisSize: MainAxisSize.max,
      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //       children: <Widget>[
      //         ElevatedButton.icon(
      //           onPressed: () {
      //             showTagsModal();
      //           },
      //           icon: Icon(
      //             // <-- Icon
      //             Icons.category,
      //             size: 24.0,
      //           ),
      //           label: Text('Tags'), // <-- Text
      //         ),
      //         ElevatedButton.icon(
      //           icon: SvgPicture.asset(
      //             'assets/icons/chat.svg', // Replace with the path to your SVG file
      //             width: 30, // Specify the width
      //             height: 30,
      //             colorFilter: // <-- Use the color filter property to specify the
      //                 ColorFilter.mode(Colors.grey, BlendMode.srcIn),
      //           ),
      //           onPressed: () {
      //             if (gptNoteBindService.isKeyProvided()) {
      //               showChatModal();
      //             } else {
      //               _showApiKeyPopup(context);
      //             }
      //           },
      //           label: Text('GPT'), // <-- Text
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
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
      // actions: [
      //   IconButton(
      //     onPressed: null,
      //     icon: Icon(
      //       EvaIcons.pin,
      //       color: white.withOpacity(0.7),
      //       size: 22,
      //     ),
      //   ),
      //   IconButton(
      //     onPressed: null,
      //     icon: Icon(
      //       EvaIcons.wifi,
      //       color: white.withOpacity(0.7),
      //       size: 22,
      //     ),
      //   ),
      //   IconButton(
      //     onPressed: null,
      //     icon: Icon(
      //       Icons.archive,
      //       color: white.withOpacity(0.7),
      //       size: 22,
      //     ),
      //   )
      // ],
    );
  }

  Widget getBody() {
    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            maxLines: null,
            maxLength: 2000,
            autofocus: true,
            scrollController: _scrollController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                helperStyle: TextStyle(color: Colors.white),
                hintText: "Write your note",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3))),
            controller: _descriptionController,
            onChanged: (value) {
             handleText(value);
             handleIsGenerated(_isGenerated);
            },
            style: TextStyle(
                fontWeight: FontWeight.w500, fontSize: 14, height: 1.5, color: Colors.white),
          ),
        ),
      ),
      Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.undo),
              disabledColor: Colors.white30, // Цвет для неактивной иконки
              color: undoStack.length > 1 ? Colors.white70 : Colors.white30,
              onPressed: undoStack.length > 1
                  ? undo
                  : null, // Кнопка undo активна, если есть история изменений
            ),
            IconButton(
              icon: Icon(Icons.redo),
              disabledColor: Colors.white30, // Цвет для неактивной иконки
              color: undoStack.length > 1 ? Colors.white70 : Colors.white30,
              onPressed: redoStack.isNotEmpty
                  ? redo
                  : null, // Кнопка redo активна, если есть отмененные изменения
            ),
          ],
        ),
      ),
      Container(
        height: 70, // Height of the bottom bar
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 80, 80, 80),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: () {
                  showTagsModal();
                },
                icon: Icon(
                  Icons.category,
                  size: 24.0,
                ),
                label: Text('Tags'),
              ),
              ElevatedButton.icon(
                icon: SvgPicture.asset(
                  'assets/icons/chat.svg',
                  width: 30,
                  height: 30,
                  colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                ),
                onPressed: () {
                  if (gptNoteBindService.isKeyProvided()) {
                    showChatModal();
                  } else {
                    _showApiKeyPopup(context);
                  }
                },
                label: Text('GPT'),
              ),
            ],
          ),
        ),
      )
    ]);
  }

  Widget getFooter() {
    var size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: 80,
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: black.withOpacity(0.2), spreadRadius: 1, blurRadius: 3)],
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
