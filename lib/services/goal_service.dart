import 'package:chrono/db_manager.dart';

class GoalService {
  final DatabaseHelper _dbManager;

  GoalService(this._dbManager);

  Future<void> resetAllGoals() async {
    await _dbManager.resetGoalsStatus();
  }
}
