import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/models/hint_range.dart';
import 'package:flutter/material.dart';

/// Bottom sheet that displays hint ranges with descriptions
class ScaleHintPopup extends StatelessWidget {
  final String metricLabel;
  final List<HintRange> hints;

  const ScaleHintPopup({
    Key? key,
    required this.metricLabel,
    required this.hints,
  }) : super(key: key);

  /// Show the hint popup as a bottom sheet
  static void show(BuildContext context, String metricLabel, List<HintRange> hints) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ScaleHintPopup(
        metricLabel: metricLabel,
        hints: hints,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            metricLabel,
            style: const TextStyle(
              color: white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: MyColors.trecondaryColor, height: 1),
          const SizedBox(height: 16),

          // Hint ranges
          ...hints.map((hint) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Range indicator
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MyColors.secondaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hint.rangeString,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MyColors.fivyColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Description
                    Expanded(
                      child: Text(
                        hint.description,
                        style: const TextStyle(
                          color: MyColors.fivyColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
