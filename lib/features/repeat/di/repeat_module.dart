import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/features/health_reminder/presentation/models/repeat_mode.dart';
import 'package:Chrono/features/repeat/presentation/cubit/repeat_cubit/repeat_cubit.dart';

void initRepeatModule() {
  getIt.registerFactoryParam((List<RepeatMode> param1, param2) => RepeatCubit(modes: param1));
}
