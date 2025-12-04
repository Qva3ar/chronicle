/// Represents a range of values with a description for metric hints
class HintRange {
  /// Minimum value in the range (inclusive)
  final int min;

  /// Maximum value in the range (inclusive)
  final int max;

  /// Description of what this range means
  final String description;

  const HintRange({
    required this.min,
    required this.max,
    required this.description,
  });

  /// Check if a value falls within this range
  bool contains(int value) {
    return value >= min && value <= max;
  }

  /// Get formatted range string (e.g., "1-3")
  String get rangeString => '$min-$max';
}
