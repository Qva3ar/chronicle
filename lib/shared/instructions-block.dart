import 'package:flutter/material.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/instructions.model.dart';
import 'package:chrono/colors.dart';

class InstructionsBlockWidget extends StatefulWidget {
  final Function(String) onSubmitted;
  final TextEditingController? textController;

  const InstructionsBlockWidget({
    super.key,
    required this.onSubmitted,
    this.textController,
  });

  @override
  State<InstructionsBlockWidget> createState() =>
      _InstructionsBlockWidgetState();
}

class _InstructionsBlockWidgetState extends State<InstructionsBlockWidget>
    with SingleTickerProviderStateMixin {
  List<Instruction> instructions = [];
  DatabaseHelper dbHelper = DatabaseHelper.instance;
  bool isVisible = false;
  late AnimationController _animController;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadInstructions();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadInstructions() async {
    List<Instruction> loadedInstructions =
        await dbHelper.queryAllInstructions();
    setState(() {
      instructions = loadedInstructions;
    });
  }

  void _toggleVisibility() {
    setState(() {
      isVisible = !isVisible;
    });
    if (isVisible) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _handlePromptTap(Instruction instruction) {
    final existingText = widget.textController?.text.trim() ?? '';

    if (instruction.autoSend) {
      // Combine existing input text with prompt text and send
      final combined = existingText.isNotEmpty
          ? '$existingText\n${instruction.text}'
          : instruction.text;
      widget.textController?.clear();
      widget.onSubmitted(combined);
    } else {
      // Just insert into the input field
      final newText = existingText.isNotEmpty
          ? '$existingText ${instruction.text}'
          : instruction.text;
      widget.textController?.text = newText;
      widget.textController?.selection = TextSelection.collapsed(
        offset: newText.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (instructions.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle button
        GestureDetector(
          onTap: _toggleVisibility,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isVisible
                  ? MyColors.orangeDivider.withValues(alpha: 0.08)
                  : surfaceElevated.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isVisible
                    ? MyColors.orangeDivider.withValues(alpha: 0.25)
                    : cardBorder.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: isVisible ? MyColors.orangeDivider : textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Quick Prompts',
                  style: TextStyle(
                    color: isVisible ? MyColors.orangeDivider : textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: isVisible ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: isVisible ? MyColors.orangeDivider : textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Prompts panel
        SizeTransition(
          sizeFactor: _slideAnim,
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: instructions.map((instruction) {
                return GestureDetector(
                  onTap: () => _handlePromptTap(instruction),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cardBorder.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          instruction.autoSend
                              ? Icons.send_rounded
                              : Icons.edit_note_rounded,
                          size: 14,
                          color: instruction.autoSend
                              ? MyColors.orangeDivider
                              : infoColor,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            instruction.text,
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
