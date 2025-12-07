import 'dart:developer';
import 'package:chrono/db_manager.dart';
import 'package:chrono/features/checkin/data/constants/evening_metrics.dart';
import 'package:chrono/features/checkin/data/constants/morning_metrics.dart';
import 'package:chrono/features/checkin/data/models/checkin_metric.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/models/record_type.dart';

/// Repository for saving checkins as notes/records in the database
class CheckinRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Build checkin text from metrics and values
  String buildCheckinText(List<CheckinMetric> metrics, Map<String, int> values) {
    final buffer = StringBuffer();

    for (final metric in metrics) {
      if (values.containsKey(metric.key)) {
        final value = values[metric.key];
        if (metric.unit != null) {
          // Number input with unit
          buffer.writeln('${metric.label}: $value ${metric.unit}');
        } else {
          // Slider input
          buffer.writeln('${metric.label}: $value');
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Save a checkin as a record/note in the database
  /// Returns the record ID
  Future<int> saveCheckin({
    required CheckinType type,
    required Map<String, int> values,
    List<int> tagIds = const [],
  }) async {
    // Get metrics based on type
    final metrics = type == CheckinType.morning
        ? MorningMetrics.all
        : EveningMetrics.all;

    // Build text representation
    final text = buildCheckinText(metrics, values);

    // Determine record type
    final recordType = type == CheckinType.morning
        ? RecordType.morningCheckin
        : RecordType.eveningCheckin;

    // Create record
    final record = {
      DatabaseColumns.recordTitle: type.displayName,
      DatabaseColumns.recordText: text,
      DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
      DatabaseColumns.recordType: recordType.toDbValue(),
      DatabaseColumns.recordIsLocked: 0,
    };

    // Save to database
    final recordId = await _db.insertRecord(record, tagIds);
    return recordId;
  }

  /// Get checkins for a specific date range
  /// Can be filtered by type (morning/evening)
  Future<List<Map<String, dynamic>>> getCheckins({
    DateTime? startDate,
    DateTime? endDate,
    CheckinType? type,
  }) async {
    // This would require a custom query to filter by date and record_type
    // For now, we can use the existing getAllRecords and filter in memory
    // In a production app, you'd want to add a specific database query

    final allRecords = await _db.queryAllRecords();

    return allRecords
        .where((record) {
          // Filter by type if specified
          if (type != null) {
            final expectedType = type == CheckinType.morning
                ? RecordType.morningCheckin
                : RecordType.eveningCheckin;
            if (record.recordType != expectedType) {
              return false;
            }
          } else {
            // Only include checkin records
            if (record.recordType != RecordType.morningCheckin &&
                record.recordType != RecordType.eveningCheckin) {
              return false;
            }
          }

          // Filter by date range if specified
          if (startDate != null && record.createdAtDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && record.createdAtDate.isAfter(endDate)) {
            return false;
          }

          return true;
        })
        .map((record) => record.toMap())
        .toList();
  }

  /// Get the last (most recent) checkin of a specific type from a PREVIOUS day
  /// Excludes checkins created today to show yesterday's values for comparison
  /// Returns null if no previous checkin exists
  Future<Map<String, dynamic>?> getLastCheckin(CheckinType type) async {
    final allRecords = await _db.queryAllRecords();

    final expectedRecordType = type == CheckinType.morning
        ? RecordType.morningCheckin
        : RecordType.eveningCheckin;

    // Get start of today (00:00:00)
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTodayMs = startOfToday.millisecondsSinceEpoch;

    log('🔍 getLastCheckin - Type: $type, Expected RecordType: $expectedRecordType');
    log('🔍 Start of today: $startOfToday (${startOfTodayMs}ms)');
    log('🔍 Total records in DB: ${allRecords.length}');

    // Filter by type, exclude today's checkins, and sort by createdAt descending
    final checkins = allRecords
        .where((record) {
          final matches = record.recordType == expectedRecordType &&
              record.createdAt < startOfTodayMs;
          if (record.recordType == expectedRecordType) {
            log('🔍 Found matching type record: createdAt=${record.createdAt}, before today=${record.createdAt < startOfTodayMs}');
          }
          return matches;
        })
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    log('🔍 Filtered checkins count: ${checkins.length}');

    if (checkins.isEmpty) {
      log('🔍 No previous checkins found');
      return null;
    }

    log('🔍 Returning most recent checkin: ${checkins.first.toMap()}');
    return checkins.first.toMap();
  }

  /// Parse checkin text back into metric values
  /// Format: "Label: value" or "Label: value unit"
  /// Example: "Качество сна: 7" or "Шаги: 8450 шагов"
  Map<String, int> parseCheckinValues(
    String text,
    List<CheckinMetric> metrics,
  ) {
    log('📝 Parsing checkin text: $text');
    log('📝 Available metrics: ${metrics.map((m) => '${m.key}:${m.label}').join(', ')}');

    final values = <String, int>{};
    final lines = text.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      // Split by ": "
      final parts = line.split(': ');
      if (parts.length != 2) {
        log('📝 Skipping line (wrong format): $line');
        continue;
      }

      final label = parts[0].trim();
      final valueStr = parts[1].trim();

      log('📝 Processing line - label: "$label", valueStr: "$valueStr"');

      // Find matching metric by label
      final metric = metrics.firstWhere(
        (m) => m.label == label,
        orElse: () => metrics.first, // fallback
      );

      log('📝 Matched metric: ${metric.key} (${metric.label})');

      try {
        // Extract number (first sequence of digits)
        final numberMatch = RegExp(r'\d+').firstMatch(valueStr);
        if (numberMatch != null) {
          final value = int.parse(numberMatch.group(0)!);
          values[metric.key] = value;
          log('📝 Extracted value: $value for key ${metric.key}');
        } else {
          log('📝 No number found in valueStr: $valueStr');
        }
      } catch (e) {
        // Skip if parsing fails
        log('📝 Error parsing: $e');
        continue;
      }
    }

    log('📝 Final parsed values: $values');
    return values;
  }
}
