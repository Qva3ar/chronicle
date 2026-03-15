import 'dart:convert';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chrono/chat_page_note.dart';
import 'package:chrono/models/enums.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/services/messages.service.dart';
import 'package:chrono/shared/api-key-popup.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/record.service.dart';
import 'package:chrono/services/gpt.service.dart';
import 'package:flutter_multi_select_items/flutter_multi_select_items.dart';
import 'package:chrono/helpers/link_text_span_builder.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:chrono/screens/tag_form_screen.dart';
import 'package:chrono/models/tag.dart';

class CardDetailPage extends StatefulWidget {
  final String title;
  final String text;
  final int? recordId;
  final List<int>? recordsTag;
  final bool isLocked;

  const CardDetailPage({
    Key? key,
    required this.title,
    required this.text,
    this.recordId,
    this.recordsTag,
    this.isLocked = false,
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

  List<Tag> allRecordTags = [];
  List<MultiSelectCard<dynamic>> allTags = [];
  List<MultiSelectCard<dynamic>> gptTags = [];
  List<int>? selectedTags = [];

  GPTService gpt = GPTService();

  bool _isListeningToStream = false;
  bool _isLocked = false;

  List<String> undoStack = [];
  List<String> redoStack = [];

  @override
  void initState() {
    super.initState();
    print("🚀 CardDetailPage: Initializing with recordId: ${widget.recordId}");

    if (!_isListeningToStream) {
      _isListeningToStream = true;
      _isLocked = widget.isLocked;

      // 🎯 CRITICAL: Set record ID and tags FIRST before any other operations
      // This prevents race conditions where auto-save could trigger with empty tags
      recordService.setCurrentRecordId(widget.recordId);
      selectedTags = widget.recordsTag;
      recordService.setTagIds(selectedTags);

      // Now safe to set text which might trigger debounced auto-save
      setState(() {
        _titleController.text = widget.title;
        _descriptionController.text = widget.text;
      });

      getTags();
      getAllTags();

      // 🎯 IMPORTANT: If we have initial text and no record ID, trigger initial save
      if (widget.recordId == null && widget.text.isNotEmpty) {
        print("📝 CardDetailPage: Initial text found in create mode, triggering save");
        // Give the service time to initialize, then process the initial text
        Future.delayed(Duration(milliseconds: 100), () {
          handleText(_descriptionController.text);
        });
      }

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

    undoRedoListen();
  }

  undoRedoListen() {
    // Добавляем начальный текст в стек undo
    undoStack.add(_descriptionController.text);
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
    final tags = await recordService.queryAllTagsJust();
    allRecordTags = tags;
    setState(() {});
  }

  handleTitle(String title) {
    recordService.handleTitle(title);
  }

  // 🎯 ENHANCED: Handle text with validation
  handleText(String text) {
    // Let the RecordService handle all the debouncing and duplicate prevention
    // We just pass through the text - the service will handle the rest
    recordService.handleText(text);
  }

  setTagIds() {
    recordService.setTagIds(selectedTags);
  }

  Future<void> getAllTags() async {
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
      // Save the undone text to database
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
      // Save the redone text to database
      handleText(_descriptionController.text);
    }
  }

  void toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
    recordService.handleLock(_isLocked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLocked ? 'Note locked' : 'Note unlocked'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> navigateToTagForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TagFormScreen(),
      ),
    );

    // Reload tags if a tag was created and show the modal again
    if (result == true) {
      await getAllTags();
      await getTags();
      setState(() {});

      // Automatically reopen the tags modal for better UX
      // Give a small delay to ensure the UI is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          showTagsModal();
        }
      });
    }
  }

  showTagsModal() {
    final tagSearchController = TextEditingController();
    final modalSelected = Set<int>.from(selectedTags ?? []);

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final query = tagSearchController.text.toLowerCase();
              final filteredTags = query.isEmpty
                  ? allRecordTags
                  : allRecordTags
                      .where((tag) => tag.name.toLowerCase().contains(query))
                      .toList();

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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "All tags",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white, size: 24),
                                onPressed: () {
                                  Navigator.pop(context);
                                  navigateToTagForm();
                                },
                                tooltip: 'Create new tag',
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: filteredTags.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        'No tags found',
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: filteredTags.map((tag) {
                                      final isSelected = modalSelected.contains(tag.id);
                                      final tagColor = parseTagColor(tag.color);
                                      return FilterChip(
                                        label: Text(
                                          tag.name,
                                          style: const TextStyle(color: Colors.white, fontSize: 16),
                                        ),
                                        selected: isSelected,
                                        selectedColor: tagColor,
                                        backgroundColor: tagColor.withAlpha(150),
                                        checkmarkColor: Colors.white,
                                        side: isSelected
                                            ? BorderSide(color: Colors.white, width: 1.5)
                                            : BorderSide.none,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        onSelected: (selected) {
                                          setModalState(() {
                                            if (selected) {
                                              modalSelected.add(tag.id);
                                            } else {
                                              modalSelected.remove(tag.id);
                                            }
                                          });
                                          selectedTags = modalSelected.toList();
                                          setTagIds();
                                        },
                                      );
                                    }).toList(),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: tagSearchController,
                              autofocus: false,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search tags...',
                                hintStyle: TextStyle(color: Colors.white38),
                                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                                suffixIcon: tagSearchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                        onPressed: () {
                                          tagSearchController.clear();
                                          setModalState(() {});
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: MyColors.secondaryColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
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
          child: ExtendedTextField(
            maxLines: null,
            maxLength: 2000,
            specialTextSpanBuilder: LinkTextSpanBuilder(),
            autofocus: true,
            scrollController: _scrollController,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: MyColors.fivyColor,
            cursorWidth: 2.0,
            decoration: InputDecoration(
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Colors.transparent, width: 0),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Colors.transparent, width: 0),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Colors.transparent, width: 0),
                ),
                helperStyle: const TextStyle(color: Colors.white),
                hintText: "Write your note",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                counterStyle: TextStyle(color: MyColors.forthyColor)),
            controller: _descriptionController,
            onChanged: (text) {
              // 🎯 ENHANCED: Handle undo/redo stack with better logic
              if (text != (undoStack.isEmpty ? '' : undoStack.last)) {
                undoStack.add(text);
                redoStack.clear(); // Clear redo stack when new text is entered
                setState(() {});
              }

              // 🎯 IMPROVED: Handle text saving with debug info
              // The RecordService now has proper debouncing and duplicate prevention
              print("📝 CardDetailPage: Text changed, length: ${text.length}");
              handleText(text);
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
              color: redoStack.isNotEmpty ? Colors.white70 : Colors.white30,
              onPressed: redoStack.isNotEmpty
                  ? redo
                  : null, // Кнопка redo активна, если есть отмененные изменения
            ),
            IconButton(
              icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
              color: _isLocked ? Colors.redAccent : Colors.white30,
              onPressed: toggleLock,
            ),
          ],
        ),
      ),
      Container(
        height: 70, // Height of the bottom bar
        decoration: BoxDecoration(
          color: MyColors.primaryColor,
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
