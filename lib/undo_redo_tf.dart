import 'package:flutter/material.dart';

class UndoRedoTextFieldWidget extends StatefulWidget {
  final TextEditingController? controller; // Начальный текст для TextField
  final String initialText; // Начальный текст для TextField
  final TextStyle? textStyle; // Стиль текста (опционально)
  final InputDecoration? inputDecoration; // Декорация TextField (опционально)

  const UndoRedoTextFieldWidget({
    Key? key,
    this.initialText = '',
    this.controller,
    this.textStyle,
    this.inputDecoration,
  }) : super(key: key);

  @override
  _UndoRedoTextFieldWidgetState createState() => _UndoRedoTextFieldWidgetState();
}

class _UndoRedoTextFieldWidgetState extends State<UndoRedoTextFieldWidget> {
  late TextEditingController
      _internalController; // Внутренний контроллер, если не передан родительский

  List<String> undoStack = [];
  List<String> redoStack = [];

  @override
  void initState() {
    super.initState();
    _internalController = widget.controller ?? TextEditingController();
    _internalController = TextEditingController(text: widget.initialText);

    // Добавляем начальный текст в стек undo
    undoStack.add(widget.initialText);

    // Добавляем слушатель изменений текста
    _internalController.addListener(() {
      if (_internalController.text != (undoStack.isEmpty ? '' : undoStack.last)) {
        undoStack.add(_internalController.text);
        redoStack.clear(); // Очищаем redoStack, если появляется новое состояние текста
        setState(() {});
      }
    });
  }

  void undo() {
    if (undoStack.length > 1) {
      setState(() {
        redoStack.add(undoStack.removeLast());
        _internalController.text = undoStack.last;
        _internalController.selection =
            TextSelection.fromPosition(TextPosition(offset: _internalController.text.length));
      });
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      setState(() {
        String restoredText = redoStack.removeLast();
        undoStack.add(restoredText);
        _internalController.text = restoredText;
        _internalController.selection =
            TextSelection.fromPosition(TextPosition(offset: _internalController.text.length));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _internalController,
            maxLines: null,
            decoration: widget.inputDecoration ?? InputDecoration(hintText: 'Enter some text...'),
            style: widget.textStyle,
          ),
        ),
        Text(undoStack.length.toString()),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.undo),
              onPressed: undoStack.length > 1
                  ? undo
                  : null, // Кнопка undo активна, если есть история изменений
            ),
            IconButton(
              icon: Icon(Icons.redo),
              onPressed: redoStack.isNotEmpty
                  ? redo
                  : null, // Кнопка redo активна, если есть отмененные изменения
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }
}
