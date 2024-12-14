import 'package:Chrono/core/di/core_module.dart';
import 'package:Chrono/features/health_center/di/health_center_module.dart';
import 'package:Chrono/features/health_reminder/di/health_reminder_module.dart';
import 'package:Chrono/features/notes/di/notes_module.dart';
import 'package:Chrono/features/start/di/start_module.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void initDependencyInjection() {
  initCoreModule();
  initHealthCenterModule();
  initHealthReminderModule();
  initStartModule();
  initNotesModule();
}
