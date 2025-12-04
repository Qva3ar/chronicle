/// Configuration for which metrics are hidden in checkins
/// Saved in SharedPreferences
class CheckinConfig {
  /// List of hidden metric keys for morning checkin
  final List<String> hiddenMorningMetrics;

  /// List of hidden metric keys for evening checkin
  final List<String> hiddenEveningMetrics;

  const CheckinConfig({
    this.hiddenMorningMetrics = const [],
    this.hiddenEveningMetrics = const [],
  });

  /// Check if a morning metric is hidden
  bool isMorningMetricHidden(String key) {
    return hiddenMorningMetrics.contains(key);
  }

  /// Check if an evening metric is hidden
  bool isEveningMetricHidden(String key) {
    return hiddenEveningMetrics.contains(key);
  }

  /// Create a new config with a morning metric toggled
  CheckinConfig toggleMorningMetric(String key) {
    final newList = List<String>.from(hiddenMorningMetrics);
    if (newList.contains(key)) {
      newList.remove(key);
    } else {
      newList.add(key);
    }
    return CheckinConfig(
      hiddenMorningMetrics: newList,
      hiddenEveningMetrics: hiddenEveningMetrics,
    );
  }

  /// Create a new config with an evening metric toggled
  CheckinConfig toggleEveningMetric(String key) {
    final newList = List<String>.from(hiddenEveningMetrics);
    if (newList.contains(key)) {
      newList.remove(key);
    } else {
      newList.add(key);
    }
    return CheckinConfig(
      hiddenMorningMetrics: hiddenMorningMetrics,
      hiddenEveningMetrics: newList,
    );
  }

  /// Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'hiddenMorningMetrics': hiddenMorningMetrics,
      'hiddenEveningMetrics': hiddenEveningMetrics,
    };
  }

  /// Create from JSON from SharedPreferences
  factory CheckinConfig.fromJson(Map<String, dynamic> json) {
    return CheckinConfig(
      hiddenMorningMetrics: List<String>.from(json['hiddenMorningMetrics'] ?? []),
      hiddenEveningMetrics: List<String>.from(json['hiddenEveningMetrics'] ?? []),
    );
  }
}
