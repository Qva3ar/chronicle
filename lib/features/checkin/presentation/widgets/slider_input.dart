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

  const SliderInput({
    Key? key,
    required this.value,
    required this.onChanged,
    this.hints,
    this.minValue = 0,
    this.maxValue = 10,
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
              return Text(
                '$number',
                style: TextStyle(
                  color: isSelected
                      ? MyColors.orangeDivider
                      : MyColors.fivyColor.withOpacity(0.5),
                  fontSize: isSelected ? 14 : 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }),
          ),
        ),

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
