import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/models/hint_range.dart';
import 'package:flutter/material.dart';

/// Slider input for metrics with configurable range
class SliderInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final List<HintRange>? hints;
  final int minValue;
  final int maxValue;
  final int? previousValue;

  const SliderInput({
    Key? key,
    required this.value,
    required this.onChanged,
    this.hints,
    this.minValue = 0,
    this.maxValue = 10,
    this.previousValue,
  }) : super(key: key);

  /// Find hint description for current value
  String? _getHintForValue() {
    if (hints == null || hints!.isEmpty) return null;

    for (final hint in hints!) {
      if (value >= hint.min && value <= hint.max) {
        return hint.description;
      }
    }
    return null;
  }

  /// Check if there's a change from previous value
  bool get _hasChange => previousValue != null && value != previousValue;

  /// Get change icon
  IconData? get _changeIcon {
    if (previousValue == null) return null;
    if (value > previousValue!) return Icons.arrow_upward;
    if (value < previousValue!) return Icons.arrow_downward;
    return Icons.remove;
  }

  /// Get change color
  Color? get _changeColor {
    if (previousValue == null) return null;
    if (value > previousValue!) return Colors.green;
    if (value < previousValue!) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final currentHint = _getHintForValue();

    return Column(
      children: [
        // Slider (full width)
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: MyColors.orangeDivider,
            inactiveTrackColor: MyColors.secondaryColor,
            thumbColor: MyColors.orangeDivider,
            overlayColor: MyColors.orangeDivider.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            trackHeight: 6,
            valueIndicatorColor: MyColors.orangeDivider,
            valueIndicatorTextStyle: const TextStyle(
              color: MyColors.primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            trackShape: const RoundedRectSliderTrackShape(),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value.toDouble(),
            min: minValue.toDouble(),
            max: maxValue.toDouble(),
            divisions: maxValue - minValue,
            label: '$value',
            onChanged: (double newValue) {
              onChanged(newValue.round());
            },
          ),
        ),

        // All divisions with labels (dynamic range)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(maxValue - minValue + 1, (index) {
              final number = minValue + index;
              final isSelected = number == value;
              final isPrevious = number == previousValue;
              return Text(
                '$number',
                style: TextStyle(
                  color: isSelected
                      ? MyColors.orangeDivider
                      : isPrevious
                          ? MyColors.fivyColor.withOpacity(0.7)
                          : MyColors.fivyColor.withOpacity(0.5),
                  fontSize: isSelected ? 14 : isPrevious ? 12 : 11,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : isPrevious
                          ? FontWeight.w500
                          : FontWeight.normal,
                ),
              );
            }),
          ),
        ),

        // Previous value comparison (if exists)
        if (previousValue != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'Прошлый раз: $previousValue',
                  style: TextStyle(
                    color: MyColors.fivyColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                if (_changeIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    _changeIcon,
                    size: 14,
                    color: _changeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(value - previousValue!).abs()}',
                    style: TextStyle(
                      color: _changeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Hint description for current value
        if (currentHint != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MyColors.secondaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MyColors.orangeDivider.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: MyColors.orangeDivider.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentHint,
                    style: TextStyle(
                      color: MyColors.fivyColor.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
