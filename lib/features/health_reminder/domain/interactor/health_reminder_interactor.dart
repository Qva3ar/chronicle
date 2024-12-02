import 'package:Chrono/features/health_reminder/domain/models/health_reminder_data.dart';
import 'package:Chrono/features/health_reminder/domain/repository/health_reminder_repository.dart';

class HealthReminderInteractor {
  final HealthReminderRepository _healthReminderRepository;

  HealthReminderInteractor({
    required HealthReminderRepository healthReminderRepository,
  }) : _healthReminderRepository = healthReminderRepository;

  Future saveReminder(HealthReminderData reminder) async {
    print('INTERACTOR');
    _healthReminderRepository.saveReminder(reminder);
  }

  Future<List<HealthReminderData>> getReminders() async {
    return await _healthReminderRepository.getReminders();
  }

  Future<HealthReminderData?> getReminderById(String id) {
    return _healthReminderRepository.getReminderById(id);
  }
}
