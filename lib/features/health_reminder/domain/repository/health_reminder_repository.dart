import 'package:Chrono/features/health_reminder/domain/models/health_reminder_data.dart';

abstract class HealthReminderRepository {
  Future<int?> saveReminder(HealthReminderData data);

  Future<List<HealthReminderData>> getReminders();

  Future deleteReminder(String id);

  Future<HealthReminderData?> getReminderById(String id);

  Future saveRemindersList(List<HealthReminderData> notesList);

  Future deleteAllReminders();
}
