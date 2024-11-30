import 'package:Chrono/features/health_reminder/domain/repository/health_reminder_repository.dart';

import '../../../health_reminder/domain/models/health_reminder_data.dart';

class HealthCenterInteractor {
  final HealthReminderRepository _healthReminderRepository;

  HealthCenterInteractor({
    required HealthReminderRepository healthReminderRepository,
  }) : _healthReminderRepository = healthReminderRepository;

  Future<List<HealthReminderData>> getReminders() async {
    return _healthReminderRepository.getReminders();
  }

  Future deleteNote(String id) async {
    await _healthReminderRepository.deleteReminder(id);
  }

  Future<List<HealthReminderData>> updateReminders(List<HealthReminderData> reminders) async {
    await _healthReminderRepository.deleteAllReminders();
    await _healthReminderRepository.saveRemindersList(reminders);
    return await _healthReminderRepository.getReminders();
  }
}
