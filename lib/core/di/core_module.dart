import 'package:Chrono/core/navigation/router.dart';
import 'package:Chrono/db_manager.dart';

import 'dependency_injection.dart';

void initCoreModule() {
  getIt.registerSingleton(DatabaseHelper());
  getIt.registerSingleton(ChronoRouter());
}
