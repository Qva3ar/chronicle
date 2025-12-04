import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/models/checkin_metric.dart';
import 'package:chrono/features/checkin/presentation/widgets/metric_card.dart';
import 'package:flutter/material.dart';

/// Section showing hidden metrics (only visible in edit mode)
class HiddenMetricsSection extends StatelessWidget {
  final List<CheckinMetric> hiddenMetrics;

  const HiddenMetricsSection({
    Key? key,
    required this.hiddenMetrics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (hiddenMetrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider with label
        Row(
          children: [
            const Expanded(
              child: Divider(
                color: MyColors.trecondaryColor,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Скрытые',
                style: TextStyle(
                  color: MyColors.forthyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(
              child: Divider(
                color: MyColors.trecondaryColor,
                height: 1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Hidden metric cards
        ...hiddenMetrics.map(
          (metric) => MetricCard(
            metric: metric,
            isHidden: true,
          ),
        ),
      ],
    );
  }
}
