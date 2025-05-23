import 'package:chrono/db_manager.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoutineService {
  final DatabaseHelper _dbManager;

  RoutineService(this._dbManager);

  Future<List<Routine>> getAllRoutines() async {
    final routines = await _dbManager.getAllRoutines();
    return routines.map((r) => Routine.fromMap(r)).toList();
  }

  Future<void> resetRoutine(int? id) async {
    if (id == null) return;

    // Reset in database
    await _dbManager.toggleRoutineDone(id, false);

    // Reset in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('routine_${id}_done');
  }
}
