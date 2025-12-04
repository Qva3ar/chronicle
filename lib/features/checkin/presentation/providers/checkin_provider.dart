import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:chrono/features/checkin/data/models/checkin_metric.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/features/checkin/data/models/checkin_config.dart';
import 'package:chrono/features/checkin/data/models/metric_input_type.dart';
import 'package:chrono/features/checkin/data/repositories/checkin_config_repository.dart';
import 'package:chrono/features/checkin/data/repositories/checkin_repository.dart';
import 'package:chrono/features/checkin/data/constants/morning_metrics.dart';
import 'package:chrono/features/checkin/data/constants/evening_metrics.dart';

/// Provider for managing checkin state (metric values, config, saving)
class CheckinProvider with ChangeNotifier {
  final CheckinConfigRepository _configRepo = CheckinConfigRepository();
  final CheckinRepository _checkinRepo = CheckinRepository();

  // Current checkin type
  CheckinType _checkinType;

  // Metric values (key -> value)
  final Map<String, int> _values = {};

  // Previous checkin values (for comparison)
  Map<String, int>? _previousValues;

  // Configuration (hidden metrics)
  CheckinConfig _config = const CheckinConfig();

  // Loading state
  bool _isLoading = false;
  bool _isSaving = false;

  CheckinProvider({required CheckinType checkinType}) : _checkinType = checkinType {
    _initializeValues();
    _loadConfig();
    _loadPreviousCheckin();
  }

  // Getters
  CheckinType get checkinType => _checkinType;
  Map<String, int> get values => Map.unmodifiable(_values);
  CheckinConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  /// Get all metrics for current checkin type
  List<CheckinMetric> get allMetrics {
    return _checkinType == CheckinType.morning
        ? MorningMetrics.all
        : EveningMetrics.all;
  }

  /// Get visible (non-hidden) metrics
  List<CheckinMetric> get visibleMetrics {
    return allMetrics.where((metric) => !_isMetricHidden(metric.key)).toList();
  }

  /// Get hidden metrics
  List<CheckinMetric> get hiddenMetrics {
    return allMetrics.where((metric) => _isMetricHidden(metric.key)).toList();
  }

  /// Check if a metric is hidden
  bool _isMetricHidden(String key) {
    return _checkinType == CheckinType.morning
        ? _config.isMorningMetricHidden(key)
        : _config.isEveningMetricHidden(key);
  }

  /// Initialize default values for all metrics
  void _initializeValues() {
    for (final metric in allMetrics) {
      if (metric.inputType == MetricInputType.slider) {
        // For sliders, use middle of the range
        _values[metric.key] = ((metric.minValue + metric.maxValue) / 2).round();
      } else {
        // For number inputs, start with 0
        _values[metric.key] = 0;
      }
    }
  }

  /// Load configuration from repository
  Future<void> _loadConfig() async {
    _isLoading = true;
    notifyListeners();

    try {
      _config = await _configRepo.loadConfig();
    } catch (e) {
      log('Error loading config: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load previous checkin values for comparison
  Future<void> _loadPreviousCheckin() async {
    try {
      final previousCheckin = await _checkinRepo.getLastCheckin(_checkinType);
      if (previousCheckin != null) {
        final text = previousCheckin['record_text'] as String;
        _previousValues = _checkinRepo.parseCheckinValues(text, allMetrics);
        notifyListeners();
      }
    } catch (e) {
      log('Error loading previous checkin: $e');
    }
  }

  /// Update value for a metric
  void updateValue(String key, int value) {
    _values[key] = value;
    notifyListeners();
  }

  /// Get value for a metric
  int getValue(String key) {
    return _values[key] ?? 0;
  }

  /// Get previous value for a metric (for comparison)
  /// Returns null if no previous checkin exists
  int? getPreviousValue(String key) {
    return _previousValues?[key];
  }

  /// Toggle metric visibility (hide/show)
  Future<void> toggleMetricVisibility(String key) async {
    if (_checkinType == CheckinType.morning) {
      _config = _config.toggleMorningMetric(key);
    } else {
      _config = _config.toggleEveningMetric(key);
    }

    // Save to repository
    await _configRepo.saveConfig(_config);
    notifyListeners();
  }

  /// Save checkin to database
  Future<bool> saveCheckin({List<int> tagIds = const []}) async {
    _isSaving = true;
    notifyListeners();

    try {
      // Only save non-hidden metrics
      final valuesToSave = <String, int>{};
      for (final metric in visibleMetrics) {
        valuesToSave[metric.key] = _values[metric.key] ?? 0;
      }

      await _checkinRepo.saveCheckin(
        type: _checkinType,
        values: valuesToSave,
        tagIds: tagIds,
      );

      return true;
    } catch (e) {
      log('Error saving checkin: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Reset all values to defaults
  void resetValues() {
    _initializeValues();
    notifyListeners();
  }
}
