import 'package:flutter/material.dart';
import 'package:Chrono/db_manager.dart';
import 'package:Chrono/models/instructions.model.dart';

class InstructionsPage extends StatefulWidget {
  @override
  _InstructionsPageState createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  DatabaseHelper dbHelper = DatabaseHelper();
  List<Instruction> instructions = [];

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

  Future<void> _showCreateInstructionModal() async {
    TextEditingController textController = TextEditingController();
    bool visibility = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Create Prompt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: InputDecoration(labelText: 'Prompt Text'),
                ),
                // SizedBox(height: 16),
                // CheckboxListTile(
                //   title: Text('Visible'),
                //   value: visibility,
                //   onChanged: (value) {
                //     setState(() {
                //       visibility = value!;
                //     });
                //   },
                // ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await dbHelper.insertInstruction(
                        new Instruction(text: textController.text, visibility: visibility));
                    Navigator.pop(context);
                    _loadInstructions();
                  },
                  child: Text('Create'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditInstructionModal(int id, String text, bool visibility) async {
    TextEditingController textController = TextEditingController(text: text);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit Prompt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: InputDecoration(labelText: 'Prompt Text'),
                ),
                SizedBox(height: 16),
                // CheckboxListTile(
                //   title: Text('Visible'),
                //   value: visibility,
                //   onChanged: (value) {
                //     setState(() {
                //       visibility = value!;
                //     });
                //   },
                // ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await dbHelper.updateInstruction(new Instruction(
                            id: id, text: textController.text, visibility: visibility));
                        Navigator.pop(context);
                        _loadInstructions();
                      },
                      child: Text('Save Changes'),
                    ),
                    //elevated button for delete
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        await dbHelper.deleteInstruction(id);
                        Navigator.pop(context);
                        _loadInstructions();
                      },
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PROMPTS'),
      ),
      body: ListView.builder(
        itemCount: instructions.length,
        itemBuilder: (context, index) {
          Instruction instruction = instructions[index];
          return ListTile(
            title: Text(instruction.text),
            //divider
            subtitle: Divider(
              color: Colors.grey,
            ),
            // subtitle: Text('Visible: ${instruction.visibility == 1 ? 'Yes' : 'No'}'),
            onTap: () {
              _showEditInstructionModal(
                instruction.id!,
                instruction.text,
                instruction.visibility == 1,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateInstructionModal();
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
