import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:chrono/db_manager.dart';
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
  final CheckinType _checkinType;

  // Existing record data (if viewing/editing existing checkin)
  final Map<String, dynamic>? _existingRecord;

  // Metric values (key -> value)
  final Map<String, int> _values = {};

  // Previous checkin values (for comparison)
  Map<String, int>? _previousValues;

  // Configuration (hidden metrics)
  CheckinConfig _config = const CheckinConfig();

  // Loading state
  bool _isLoading = false;
  bool _isSaving = false;

  // Read-only mode (when viewing locked checkin)
  late final bool isReadOnly;

  // Existing record ID (for updating instead of creating new)
  int? _existingRecordId;

  CheckinProvider({
    required CheckinType checkinType,
    Map<String, dynamic>? existingRecord,
  })  : _checkinType = checkinType,
        _existingRecord = existingRecord {
    // Set read-only mode if:
    // 1. Record is locked OR
    // 2. Record is from a previous day (not today)
    bool isLocked = existingRecord != null && (existingRecord[DatabaseColumns.recordIsLocked] == 1);
    bool isOldRecord = false;

    if (existingRecord != null) {
      // Check if record is from a previous day
      final recordCreatedAt = existingRecord[DatabaseColumns.recordCreatedAt] as int;
      final recordDate = DateTime.fromMillisecondsSinceEpoch(recordCreatedAt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final recordDay = DateTime(recordDate.year, recordDate.month, recordDate.day);

      isOldRecord = recordDay.isBefore(today);
    }

    isReadOnly = isLocked || isOldRecord;

    // Store existing record ID for updates
    if (existingRecord != null) {
      _existingRecordId = existingRecord[DatabaseColumns.id] as int?;
    }

    _initializeValues();
    _loadData();
  }

  /// Load both config and previous checkin data
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load config always, but only load previous checkin if NOT in read-only mode
      if (isReadOnly) {
        // In read-only mode, only load config
        await _loadConfigInternal();
      } else {
        // In edit mode, load both config and previous checkin in parallel
        await Future.wait([
          _loadConfigInternal(),
          _loadPreviousCheckin(),
        ]);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  /// Initialize values - either from existing record or with defaults
  void _initializeValues() {
    if (_existingRecord != null) {
      // Load values from existing record
      final text = _existingRecord![DatabaseColumns.recordText] as String;
      final parsedValues = _checkinRepo.parseCheckinValues(text, allMetrics);

      // Set parsed values
      for (final entry in parsedValues.entries) {
        _values[entry.key] = entry.value;
      }

      // Fill missing metrics with defaults
      for (final metric in allMetrics) {
        if (!_values.containsKey(metric.key)) {
          if (metric.inputType == MetricInputType.slider) {
            _values[metric.key] = ((metric.minValue + metric.maxValue) / 2).round();
          } else {
            _values[metric.key] = 0;
          }
        }
      }

      log('Loaded ${_values.length} values from existing record');
    } else {
      // Initialize with default values
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
  }

  /// Load configuration from repository (internal, without managing loading state)
  Future<void> _loadConfigInternal() async {
    try {
      _config = await _configRepo.loadConfig();
    } catch (e) {
      log('Error loading config: $e');
    }
  }

  /// Load previous checkin values for comparison
  Future<void> _loadPreviousCheckin() async {
    try {
      log('Loading previous checkin for type: $_checkinType');
      final previousCheckin = await _checkinRepo.getLastCheckin(_checkinType);
      log('Previous checkin found: ${previousCheckin != null}');

      if (previousCheckin != null) {
        final text = previousCheckin[DatabaseColumns.recordText] as String;
        log('Previous checkin text: $text');

        _previousValues = _checkinRepo.parseCheckinValues(text, allMetrics);
        log('Parsed previous values: $_previousValues');
      } else {
        log('No previous checkin found for type: $_checkinType');
      }
    } catch (e) {
      log('Error loading previous checkin: $e');
    }
  }

  /// Update value for a metric (ignored in read-only mode)
  void updateValue(String key, int value) {
    if (isReadOnly) {
      log('Ignoring value update in read-only mode');
      return;
    }
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
    final value = _previousValues?[key];
    log('getPreviousValue($key) = $value, _previousValues = $_previousValues');
    return value;
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
