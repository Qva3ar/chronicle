import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/features/health_center/domain/inderactor/health_center_interactor.dart';
import 'package:Chrono/features/health_center/presentation/bloc/health_center_bloc.dart';
import 'package:Chrono/features/health_center/presentation/models/data_stream.dart';

void initHealthCenterModule() {
  getIt.registerFactory(() => HealthCenterInteractor(healthReminderRepository: getIt()));
  getIt.registerFactory(
      () => HealthCenterBloc(healthCenterInteractor: getIt(), recordService: getIt()));
  getIt.registerSingleton(DataStream());
}
