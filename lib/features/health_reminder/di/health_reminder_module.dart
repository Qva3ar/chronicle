import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/features/health_reminder/data/db/health_reminder_db_service.dart';
import 'package:Chrono/features/health_reminder/data/mappers/health_reminder_data_mapper.dart';
import 'package:Chrono/features/health_reminder/data/repository/health_reminder_repository_impl.dart';
import 'package:Chrono/features/health_reminder/domain/interactor/health_reminder_interactor.dart';
import 'package:Chrono/features/health_reminder/domain/repository/health_reminder_repository.dart';
import 'package:Chrono/features/health_reminder/presentation/bloc/health_reminder_bloc.dart';

void initHealthReminderModule() {
  getIt.registerLazySingleton(() => HealthReminderDbService(databaseHelper: getIt()));
  getIt.registerFactory(() => HealthReminderDataMapper());
  getIt.registerLazySingleton<HealthReminderRepository>(() => HealthReminderRepositoryImpl(
      healthReminderDbService: getIt(), healthReminderDataMapper: getIt()));
  getIt.registerFactory(() => HealthReminderInteractor(healthReminderRepository: getIt()));
  getIt.registerFactory(() => HealthReminderBloc(healthReminderInteractor: getIt()));
}
