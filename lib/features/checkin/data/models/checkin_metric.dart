import 'package:chrono/features/checkin/data/models/hint_range.dart';
import 'package:chrono/features/checkin/data/models/metric_input_type.dart';

/// Model representing a single metric in a checkin
class CheckinMetric {
  /// Unique key for this metric (e.g., "sleep_quality")
  final String key;

  /// Display label shown to user
  final String label;

  /// Type of input (slider or number)
  final MetricInputType inputType;

  /// List of hint ranges with descriptions (null for number inputs)
  final List<HintRange>? hints;

  /// Unit text for number inputs (e.g., "шагов", "минут")
  final String? unit;

  /// Minimum value for slider (default 1)
  final int minValue;

  /// Maximum value for slider (default 10)
  final int maxValue;

  const CheckinMetric({
    required this.key,
    required this.label,
    required this.inputType,
    this.hints,
    this.unit,
    this.minValue = 1,
    this.maxValue = 10,
  });

  /// Check if this metric has hints
  bool get hasHints => hints != null && hints!.isNotEmpty;

  /// Get hint description for a specific value
  String? getHintForValue(int value) {
    if (!hasHints) return null;

    for (final range in hints!) {
      if (range.contains(value)) {
        return range.description;
      }
    }
    return null;
  }
}
