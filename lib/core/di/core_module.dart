import 'package:Chrono/core/db/db_manager.dart';
import 'package:Chrono/core/navigation/router.dart';

import 'dependency_injection.dart';

void initCoreModule() {
  getIt.registerSingleton(DatabaseHelper());
  getIt.registerSingleton(ChronoRouter());
}
