import 'package:flutter/material.dart';
import 'package:Chrono/colors.dart';

import 'models/tag.dart';

class ColorPickerWidget extends StatefulWidget {
  final Function(Color) onColorSelected;
  final Tag? selected;
  ColorPickerWidget({required this.onColorSelected, this.selected});

  @override
  _ColorPickerWidgetState createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
  ScrollController _scrollController = ScrollController();

  List<Color> availableColors = [
    Colors.green,
    Colors.red,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.cyan,
    Colors.amber,
    Colors.indigo,
    Colors.brown,
    Colors.grey,
    Colors.lightGreen,
    Colors.lime,
    Colors.deepOrange,
    Colors.deepPurple,
    Colors.blueGrey,
    Colors.yellow,
    Colors.lightBlue,
    Colors.greenAccent,
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setSelectedTag();
    if (widget.selected == null) {
      widget.onColorSelected(selectedColor);
    }
  }

  Color selectedColor = Colors.green; // Начальный выбранный цвет
  // Начальный выбранный цвет
  int _currentIndex = 0;
  @override
  void didUpdateWidget(covariant ColorPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    setSelectedTag();
  }

  setSelectedTag() {
    if (widget.selected != null && widget.selected!.color != null) {
      // If a selected color is provided, set it initially
      final color = availableColors.where((color) {
        return color.value == int.parse(widget.selected!.color ?? "0");
      }).toList();
      if (color.length > 0) {
        _currentIndex = availableColors.indexOf(color[0]);

        _scrollController.animateTo(
          _currentIndex * (50 + 8.0), // Calculate the position based on item width and spacing
          duration: Duration(milliseconds: 500), // Adjust the duration as needed
          curve: Curves.easeInOut, // Use a different curve if desired
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color.fromARGB(96, 76, 76, 76), borderRadius: BorderRadius.circular(10)),
      height: 100, // Высота виджета
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableColors.length,
        controller: _scrollController,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0), // Отступ между цветами
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                  selectedColor = availableColors[index];
                });
                widget.onColorSelected(selectedColor);
              },
              child: Container(
                width: 50, // Ширина цвета
                height: 30, // Высота цвета
                decoration: BoxDecoration(
                  // borderRadius: BorderRadius.circular(30),
                  color: availableColors[index],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _currentIndex == index ? MyColors.fivyColor : Colors.transparent,
                    width: 2,
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
