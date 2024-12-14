import 'package:Chrono/features/health_reminder/data/db/models/health_reminder_entity.dart';
import 'package:Chrono/features/health_reminder/domain/models/health_reminder_data.dart';

class HealthReminderDataMapper {
  HealthReminderData mapToData(HealthReminderEntity entity) {
    return HealthReminderData(
      id: entity.id,
      date: DateTime.parse(entity.date),
      description: entity.description,
      isChecked: entity.isChecked == 0 ? false : true,
      selectedDays: entity.selectedDays.split(' '),
    );
  }

  HealthReminderEntity mapToEntity(HealthReminderData data) {
    return HealthReminderEntity(
      id: data.id,
      date: data.date.toIso8601String(),
      description: data.description,
      isChecked: data.isChecked ? 1 : 0,
      selectedDays: data.selectedDays.join(' '),
    );
  }
}
