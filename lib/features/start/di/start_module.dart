import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/features/start/presentation/cubit/start_cubit.dart';

void initStartModule() {
  getIt.registerFactory(() => StartCubit());
}
