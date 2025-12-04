import 'package:chrono/features/checkin/data/models/checkin_metric.dart';
import 'package:chrono/features/checkin/data/models/hint_range.dart';
import 'package:chrono/features/checkin/data/models/metric_input_type.dart';

/// Morning checkin metrics
class MorningMetrics {
  /// All morning metrics in order
  static const List<CheckinMetric> all = [
    sleepQuality,
    energyLevel,
    mood,
    anxietyLevel,
  ];

  /// Sleep quality metric
  static const CheckinMetric sleepQuality = CheckinMetric(
    key: 'sleep_quality',
    label: 'Качество сна',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Плохо спал, разбитость'),
      HintRange(min: 4, max: 6, description: 'Нормально, но мог лучше'),
      HintRange(min: 7, max: 10, description: 'Отлично выспался'),
    ],
  );

  /// Energy level metric
  static const CheckinMetric energyLevel = CheckinMetric(
    key: 'energy_level',
    label: 'Уровень энергии',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Еле встал, хочется в кровать'),
      HintRange(min: 4, max: 6, description: 'Средне, разгоняюсь'),
      HintRange(min: 7, max: 10, description: 'Бодрый, полон сил'),
    ],
  );

  /// Mood metric
  static const CheckinMetric mood = CheckinMetric(
    key: 'mood',
    label: 'Настроение',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Подавленность'),
      HintRange(min: 4, max: 6, description: 'Нейтрально'),
      HintRange(min: 7, max: 10, description: 'Хорошее, позитив'),
    ],
  );

  /// Anxiety level metric
  static const CheckinMetric anxietyLevel = CheckinMetric(
    key: 'anxiety_level',
    label: 'Уровень тревожности',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Спокойствие'),
      HintRange(min: 4, max: 6, description: 'Немного беспокоит'),
      HintRange(min: 7, max: 10, description: 'Сильная тревога'),
    ],
  );

  /// Get metric by key
  static CheckinMetric? getByKey(String key) {
    try {
      return all.firstWhere((metric) => metric.key == key);
    } catch (e) {
      return null;
    }
  }

  /// Get all metric keys
  static List<String> get allKeys => all.map((m) => m.key).toList();
}
