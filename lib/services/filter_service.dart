import 'package:shared_preferences/shared_preferences.dart';

class FilterService {
  static const String _showGoalRecordsKey = 'show_goal_records';
  static const String _showRoutineRecordsKey = 'show_routine_records';

  static FilterService? _instance;
  SharedPreferences? _prefs;

  FilterService._();

  static FilterService get instance {
    _instance ??= FilterService._();
    return _instance!;
  }

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> getShowGoalRecords() async {
    await _initPrefs();
    return _prefs!.getBool(_showGoalRecordsKey) ?? false;
  }

  Future<bool> getShowRoutineRecords() async {
    await _initPrefs();
    return _prefs!.getBool(_showRoutineRecordsKey) ?? false;
  }

  Future<void> setShowGoalRecords(bool value) async {
    await _initPrefs();
    await _prefs!.setBool(_showGoalRecordsKey, value);
  }

  Future<void> setShowRoutineRecords(bool value) async {
    await _initPrefs();
    await _prefs!.setBool(_showRoutineRecordsKey, value);
  }

  Future<FilterSettings> getFilterSettings() async {
    final showGoalRecords = await getShowGoalRecords();
    final showRoutineRecords = await getShowRoutineRecords();

    return FilterSettings(
      showGoalRecords: showGoalRecords,
      showRoutineRecords: showRoutineRecords,
    );
  }

  Future<void> saveFilterSettings(FilterSettings settings) async {
    await setShowGoalRecords(settings.showGoalRecords);
    await setShowRoutineRecords(settings.showRoutineRecords);
  }
}

class FilterSettings {
  final bool showGoalRecords;
  final bool showRoutineRecords;

  FilterSettings({
    required this.showGoalRecords,
    required this.showRoutineRecords,
  });

  FilterSettings copyWith({
    bool? showGoalRecords,
    bool? showRoutineRecords,
  }) {
    return FilterSettings(
      showGoalRecords: showGoalRecords ?? this.showGoalRecords,
      showRoutineRecords: showRoutineRecords ?? this.showRoutineRecords,
    );
  }
}
