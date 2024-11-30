import 'package:flutter/material.dart';
import 'package:Chrono/db_manager.dart';
import 'package:Chrono/models/instructions.model.dart';

class InstructionsBlockWidget extends StatefulWidget {
  final Function(String) onSubmitted;

  InstructionsBlockWidget({required this.onSubmitted});

  @override
  State<InstructionsBlockWidget> createState() => _InstructionsBlockWidgetState();
}

class _InstructionsBlockWidgetState extends State<InstructionsBlockWidget> {
  List<Instruction> instructions = [];
  DatabaseHelper dbHelper = DatabaseHelper();
  bool isVisible = false;

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    List<Instruction> loadedInstructions = await dbHelper.queryAllInstructions();
    setState(() {
      instructions = loadedInstructions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              isVisible = !isVisible;
            });
          },
          child: Text(isVisible ? 'Hide Prompts' : 'Show Prompts'),
        ),
        AnimatedOpacity(
          duration: Duration(milliseconds: 500),
          opacity: isVisible ? 1.0 : 0.0,
          child: Visibility(
            visible: isVisible,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 87, 87, 87),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.vertical,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Wrap(
                            spacing: 8.0,
                            children: instructions.map((instruction) {
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                onPressed: () {
                                  // Handle button press
                                  widget.onSubmitted(instruction.text);
                                },
                                child: Text(instruction.text),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
