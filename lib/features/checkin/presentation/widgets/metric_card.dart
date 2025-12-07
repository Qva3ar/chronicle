import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/models/checkin_metric.dart';
import 'package:chrono/features/checkin/data/models/metric_input_type.dart';
import 'package:chrono/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:chrono/features/checkin/presentation/providers/edit_mode_provider.dart';
import 'package:chrono/features/checkin/presentation/widgets/hint_icon.dart';
import 'package:chrono/features/checkin/presentation/widgets/number_input.dart';
import 'package:chrono/features/checkin/presentation/widgets/scale_hint_popup.dart';
import 'package:chrono/features/checkin/presentation/widgets/slider_input.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Card displaying a single metric with input and optional edit controls
class MetricCard extends StatelessWidget {
  final CheckinMetric metric;
  final bool isHidden;

  const MetricCard({
    Key? key,
    required this.metric,
    this.isHidden = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final checkinProvider = context.watch<CheckinProvider>();
    final editModeProvider = context.watch<EditModeProvider>();
    final isEditMode = editModeProvider.isEditMode;

    return Opacity(
      opacity: isHidden && isEditMode ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with label, hint icon, and toggle button
            Row(
              children: [
                // Label
                Expanded(
                  child: Text(
                    metric.label,
                    style: const TextStyle(
                      color: white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Hint icon (only if metric has hints and not hidden)
                if (metric.hasHints && !isHidden)
                  HintIcon(
                    onTap: () {
                      ScaleHintPopup.show(
                        context,
                        metric.label,
                        metric.hints!,
                      );
                    },
                  ),

                const SizedBox(width: 8),

                // Toggle visibility button (only in edit mode)
                if (isEditMode)
                  InkWell(
                    onTap: () {
                      checkinProvider.toggleMetricVisibility(metric.key);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isHidden ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        size: 24,
                        color: isHidden ? MyColors.contactDivider : MyColors.remove,
                      ),
                    ),
                  ),
              ],
            ),

            // Input (only show if not hidden)
            if (!isHidden) ...[
              const SizedBox(height: 16),

              if (metric.inputType == MetricInputType.slider)
                // Slider input
                SliderInput(
                  value: checkinProvider.getValue(metric.key),
                  // Only show previous values when NOT in read-only mode
                  previousValue: checkinProvider.isReadOnly
                      ? null
                      : checkinProvider.getPreviousValue(metric.key),
                  hints: metric.hints,
                  minValue: metric.minValue,
                  maxValue: metric.maxValue,
                  enabled: !checkinProvider.isReadOnly,
                  onChanged: (value) {
                    checkinProvider.updateValue(metric.key, value);
                  },
                )
              else
                // Number input
                NumberInput(
                  value: checkinProvider.getValue(metric.key),
                  // Only show previous values when NOT in read-only mode
                  previousValue: checkinProvider.isReadOnly
                      ? null
                      : checkinProvider.getPreviousValue(metric.key),
                  enabled: !checkinProvider.isReadOnly,
                  onChanged: (value) {
                    checkinProvider.updateValue(metric.key, value);
                  },
                  unit: metric.unit,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
