import 'package:chrono/db_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoalService {
  final DatabaseHelper _dbManager;

  GoalService(this._dbManager);

  static const String _goalOrderKey = 'goal_order';

  Future<void> resetAllGoals() async {
    await _dbManager.resetGoalsStatus();
  }

  Future<void> saveGoalOrder(List<int> goalIds) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert list of integers to list of strings for storage
    final stringIds = goalIds.map((id) => id.toString()).toList();
    await prefs.setStringList(_goalOrderKey, stringIds);
  }

  Future<List<int>> getGoalOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final stringIds = prefs.getStringList(_goalOrderKey);
    if (stringIds == null) return [];

    return stringIds
        .map((s) => int.tryParse(s))
        .whereType<int>() // Filter out any nulls from parsing errors
        .toList();
  }
}
