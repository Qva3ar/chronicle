import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/features/notes/data/db/record.service.dart';

void initNotesModule() {
  getIt.registerFactory(() => RecordService());
}
