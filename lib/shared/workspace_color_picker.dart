import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';

const List<Color> workspaceColors = [
  MyColors.orangeDivider,
  Color(0xFF7B8CDE),
  MyColors.contactDivider,
  Color(0xFFE57373),
  Color(0xFFAB47BC),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFFF59D),
  Color(0xFF4DB6AC),
  Color(0xFFFF8A65),
  Color(0xFF8D6E63),
  Color(0xFF78909C),
];

String _colorToHex(Color c) =>
    '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

class WorkspaceColorPicker extends StatelessWidget {
  final String? selectedColorHex;
  final ValueChanged<String?> onColorSelected;

  const WorkspaceColorPicker({
    super.key,
    required this.selectedColorHex,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: workspaceColors.map((color) {
        final hex = _colorToHex(color);
        final isSelected = selectedColorHex == hex;
        return GestureDetector(
          onTap: () => onColorSelected(isSelected ? null : hex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
