import 'package:flutter/material.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/instructions.model.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/shared/chrono_ui.dart';

class InstructionsPage extends StatefulWidget {
  @override
  _InstructionsPageState createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<Instruction> instructions = [];

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    List<Instruction> loadedInstructions =
        await dbHelper.queryAllInstructions();
    setState(() {
      instructions = loadedInstructions;
    });
  }

  Future<void> _showCreateInstructionModal() async {
    TextEditingController textController = TextEditingController();
    bool autoSend = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MyColors.forthyColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                MyColors.orangeDivider.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: MyColors.orangeDivider,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context).promptsNewTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Text field
                    TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).promptsEnterText,
                        hintStyle: const TextStyle(color: textHint),
                        filled: true,
                        fillColor: surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cardBorder.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cardBorder.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MyColors.orangeDivider,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action type selector
                    Text(
                      AppLocalizations.of(context).promptsOnTapBehavior,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildActionSelector(
                      autoSend: autoSend,
                      onChanged: (value) {
                        setModalState(() {
                          autoSend = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (textController.text.trim().isEmpty) return;
                          await dbHelper.insertInstruction(Instruction(
                            text: textController.text.trim(),
                            visibility: true,
                            autoSend: autoSend,
                          ));
                          Navigator.pop(context);
                          _loadInstructions();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: MyColors.orangeDivider,
                          foregroundColor: bgColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).promptsCreate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditInstructionModal(Instruction instruction) async {
    TextEditingController textController =
        TextEditingController(text: instruction.text);
    bool autoSend = instruction.autoSend;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MyColors.forthyColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title row with delete button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: infoColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: infoColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).promptsEditTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        // Delete button
                        IconButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: cardColor,
                                title: Text(
                                  AppLocalizations.of(ctx).promptsDeleteTitle,
                                  style: const TextStyle(color: textPrimary),
                                ),
                                content: Text(
                                  AppLocalizations.of(ctx)
                                      .promptsDeleteMessage(instruction.text),
                                  style: const TextStyle(color: textSecondary),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(
                                      AppLocalizations.of(ctx).commonCancel,
                                      style: const TextStyle(color: textMuted),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(
                                      AppLocalizations.of(ctx).commonDelete,
                                      style: const TextStyle(
                                          color: MyColors.remove),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await dbHelper
                                  .deleteInstruction(instruction.id!);
                              Navigator.pop(context);
                              _loadInstructions();
                            }
                          },
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: MyColors.remove.withValues(alpha: 0.7),
                            size: 22,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                MyColors.remove.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Text field
                    TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).promptsEnterText,
                        hintStyle: const TextStyle(color: textHint),
                        filled: true,
                        fillColor: surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cardBorder.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cardBorder.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MyColors.orangeDivider,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action type selector
                    Text(
                      AppLocalizations.of(context).promptsOnTapBehavior,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildActionSelector(
                      autoSend: autoSend,
                      onChanged: (value) {
                        setModalState(() {
                          autoSend = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (textController.text.trim().isEmpty) return;
                          await dbHelper.updateInstruction(Instruction(
                            id: instruction.id,
                            text: textController.text.trim(),
                            visibility: instruction.visibility,
                            autoSend: autoSend,
                          ));
                          Navigator.pop(context);
                          _loadInstructions();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: MyColors.orangeDivider,
                          foregroundColor: bgColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).promptsSaveChanges,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionSelector({
    required bool autoSend,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        // Send immediately option
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: autoSend
                    ? MyColors.orangeDivider.withValues(alpha: 0.12)
                    : surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: autoSend
                      ? MyColors.orangeDivider.withValues(alpha: 0.5)
                      : cardBorder.withValues(alpha: 0.3),
                  width: autoSend ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.send_rounded,
                    size: 22,
                    color: autoSend ? MyColors.orangeDivider : textMuted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context).promptsSendInstantly,
                    style: TextStyle(
                      color: autoSend ? MyColors.orangeDivider : textSecondary,
                      fontSize: 12,
                      fontWeight:
                          autoSend ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).promptsSendInstantlyDesc,
                    style: TextStyle(
                      color: textMuted.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Insert into input option
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: !autoSend
                    ? infoColor.withValues(alpha: 0.12)
                    : surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !autoSend
                      ? infoColor.withValues(alpha: 0.5)
                      : cardBorder.withValues(alpha: 0.3),
                  width: !autoSend ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 22,
                    color: !autoSend ? infoColor : textMuted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context).promptsInsertToInput,
                    style: TextStyle(
                      color: !autoSend ? infoColor : textSecondary,
                      fontSize: 12,
                      fontWeight:
                          !autoSend ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).promptsInsertToInputDesc,
                    style: TextStyle(
                      color: textMuted.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).promptsTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: bgColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: instructions.isEmpty
          ? ChronoEmptyState(
              icon: Icons.bolt_rounded,
              title: AppLocalizations.of(context).promptsEmptyTitle,
              subtitle: AppLocalizations.of(context).promptsEmptyDesc,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
              itemCount: instructions.length,
              itemBuilder: (context, index) {
                final instruction = instructions[index];
                return ChronoCard(
                  onTap: () => _showEditInstructionModal(instruction),
                  leftIndicator: instruction.autoSend
                      ? MyColors.orangeDivider
                      : infoColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              instruction.text,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  instruction.autoSend
                                      ? Icons.send_rounded
                                      : Icons.edit_note_rounded,
                                  size: 12,
                                  color: instruction.autoSend
                                      ? MyColors.orangeDivider
                                          .withValues(alpha: 0.7)
                                      : infoColor.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  instruction.autoSend
                                      ? AppLocalizations.of(context).promptsSendsInstantly
                                      : AppLocalizations.of(context).promptsInsertsToInput,
                                  style: TextStyle(
                                    color: instruction.autoSend
                                        ? MyColors.orangeDivider
                                            .withValues(alpha: 0.6)
                                        : infoColor.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: textMuted,
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateInstructionModal,
        backgroundColor: MyColors.orangeDivider,
        foregroundColor: bgColor,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
