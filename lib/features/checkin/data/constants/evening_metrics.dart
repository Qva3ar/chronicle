import 'package:chrono/features/checkin/data/models/checkin_metric.dart';
import 'package:chrono/features/checkin/data/models/hint_range.dart';
import 'package:chrono/features/checkin/data/models/metric_input_type.dart';

/// Evening checkin metrics
class EveningMetrics {
  /// All evening metrics in order
  static const List<CheckinMetric> all = [
    tiredness,
    stressLevel,
    productivity,
    daySatisfaction,
    waterIntake,
    sugarIntake,
    steps,
    outdoorMinutes,
    socialMediaMinutes,
  ];

  /// Tiredness metric
  static const CheckinMetric tiredness = CheckinMetric(
    key: 'tiredness',
    label: 'Усталость',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Полон сил'),
      HintRange(min: 4, max: 6, description: 'Средняя усталость'),
      HintRange(min: 7, max: 10, description: 'Истощение'),
    ],
  );

  /// Stress level metric
  static const CheckinMetric stressLevel = CheckinMetric(
    key: 'stress_level',
    label: 'Уровень стресса',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Спокойно'),
      HintRange(min: 4, max: 6, description: 'Ощутимое напряжение'),
      HintRange(min: 7, max: 10, description: 'На пределе'),
    ],
  );

  /// Productivity metric
  static const CheckinMetric productivity = CheckinMetric(
    key: 'productivity',
    label: 'Продуктивность',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'День впустую'),
      HintRange(min: 4, max: 6, description: 'Базовые дела'),
      HintRange(min: 7, max: 10, description: 'Очень продуктивно'),
    ],
  );

  /// Day satisfaction metric
  static const CheckinMetric daySatisfaction = CheckinMetric(
    key: 'day_satisfaction',
    label: 'Доволен днём',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Хочу забыть'),
      HintRange(min: 4, max: 6, description: 'Обычный день'),
      HintRange(min: 7, max: 10, description: 'Отличный день'),
    ],
  );

  /// Water intake metric
  static const CheckinMetric waterIntake = CheckinMetric(
    key: 'water_intake',
    label: 'Достаточно воды',
    inputType: MetricInputType.slider,
    hints: [
      HintRange(min: 1, max: 3, description: 'Почти не пил'),
      HintRange(min: 4, max: 6, description: 'Меньше нормы'),
      HintRange(min: 7, max: 10, description: 'Выпил норму'),
    ],
  );

  /// Sugar intake metric
  static const CheckinMetric sugarIntake = CheckinMetric(
    key: 'sugar_intake',
    label: 'Потребление сахара',
    inputType: MetricInputType.slider,
    minValue: 0,
    maxValue: 10,
    hints: [
      HintRange(min: 0, max: 0, description: 'Совсем не ел сладкого'),
      HintRange(min: 1, max: 3, description: 'Минимум (чай с сахаром)'),
      HintRange(min: 4, max: 7, description: 'Умеренно (пара конфет, печенье)'),
      HintRange(min: 8, max: 10, description: 'Много (торт, мороженое и т.д.)'),
    ],
  );

  /// Steps metric
  static const CheckinMetric steps = CheckinMetric(
    key: 'steps',
    label: 'Шаги',
    inputType: MetricInputType.numberInput,
    unit: 'шагов',
  );

  /// Outdoor minutes metric
  static const CheckinMetric outdoorMinutes = CheckinMetric(
    key: 'outdoor_minutes',
    label: 'Время на воздухе',
    inputType: MetricInputType.numberInput,
    unit: 'минут',
  );

  /// Social media minutes metric
  static const CheckinMetric socialMediaMinutes = CheckinMetric(
    key: 'social_media_minutes',
    label: 'Время в соц сетях',
    inputType: MetricInputType.numberInput,
    unit: 'минут',
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
