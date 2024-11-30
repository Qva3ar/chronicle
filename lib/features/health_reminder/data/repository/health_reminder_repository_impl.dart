import 'package:Chrono/features/health_reminder/data/db/health_reminder_db_service.dart';
import 'package:Chrono/features/health_reminder/data/db/models/health_reminder_entity.dart';
import 'package:Chrono/features/health_reminder/domain/models/health_reminder_data.dart';

import '../../domain/repository/health_reminder_repository.dart';
import '../mappers/health_reminder_data_mapper.dart';

class HealthReminderRepositoryImpl extends HealthReminderRepository {
  final HealthReminderDbService _healthReminderDbService;
  final HealthReminderDataMapper _healthReminderDataMapper;

  HealthReminderRepositoryImpl({
    required HealthReminderDbService healthReminderDbService,
    required HealthReminderDataMapper healthReminderDataMapper,
  })  : _healthReminderDbService = healthReminderDbService,
        _healthReminderDataMapper = healthReminderDataMapper;

  @override
  Future<int?> saveReminder(HealthReminderData data) {
    HealthReminderEntity entity = _healthReminderDataMapper.mapToEntity(data);
    final id = _healthReminderDbService.insertReminder(entity);
    return id;
  }

  @override
  Future<List<HealthReminderData>> getReminders() async {
    final entities = await _healthReminderDbService.getReminders();
    return entities.map(_healthReminderDataMapper.mapToData).toList();
  }

  @override
  Future deleteReminder(String id) {
    return _healthReminderDbService.deleteReminder(id);
  }

  @override
  Future<HealthReminderData?> getReminderById(String id) {
    final entity = _healthReminderDbService.getReminderById(id);
    return entity.then((e) => e == null ? null : _healthReminderDataMapper.mapToData(e));
  }

  @override
  Future saveRemindersList(List<HealthReminderData> remindersList) async {
    final entities = remindersList.map(_healthReminderDataMapper.mapToEntity).toList();
    return await _healthReminderDbService.insertRemindersList(entities);
  }

  @override
  Future deleteAllReminders() {
    return _healthReminderDbService.deleteAllReminders();
  }
}
