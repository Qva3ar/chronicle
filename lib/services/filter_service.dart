import 'package:shared_preferences/shared_preferences.dart';

class FilterService {
  static const String _showGoalRecordsKey = 'show_goal_records';
  static const String _showRoutineRecordsKey = 'show_routine_records';
  static const String _showTodoRecordsKey = 'show_todo_records';

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

  Future<bool> getShowTodoRecords() async {
    await _initPrefs();
    return _prefs!.getBool(_showTodoRecordsKey) ?? false;
  }

  Future<void> setShowTodoRecords(bool value) async {
    await _initPrefs();
    await _prefs!.setBool(_showTodoRecordsKey, value);
  }

  Future<FilterSettings> getFilterSettings() async {
    final showGoalRecords = await getShowGoalRecords();
    final showRoutineRecords = await getShowRoutineRecords();
    final showTodoRecords = await getShowTodoRecords();
    final showCompletedTodos = await getShowCompletedTodos();

    return FilterSettings(
      showGoalRecords: showGoalRecords,
      showRoutineRecords: showRoutineRecords,
      showTodoRecords: showTodoRecords,
      showCompletedTodos: showCompletedTodos,
    );
  }

  Future<void> saveFilterSettings(FilterSettings settings) async {
    await setShowGoalRecords(settings.showGoalRecords);
    await setShowRoutineRecords(settings.showRoutineRecords);
    await setShowTodoRecords(settings.showTodoRecords);
    await setShowCompletedTodos(settings.showCompletedTodos);
  }

  static const String _showCompletedTodosKey = 'show_completed_todos';

  Future<bool> getShowCompletedTodos() async {
    await _initPrefs();
    return _prefs!.getBool(_showCompletedTodosKey) ?? true;
  }

  Future<void> setShowCompletedTodos(bool value) async {
    await _initPrefs();
    await _prefs!.setBool(_showCompletedTodosKey, value);
  }

  static const String _showOtherDayRoutinesKey = 'show_other_day_routines';

  Future<bool> getShowOtherDayRoutines() async {
    await _initPrefs();
    return _prefs!.getBool(_showOtherDayRoutinesKey) ?? false;
  }

  Future<void> setShowOtherDayRoutines(bool value) async {
    await _initPrefs();
    await _prefs!.setBool(_showOtherDayRoutinesKey, value);
  }
}

class FilterSettings {
  final bool showGoalRecords;
  final bool showRoutineRecords;
  final bool showTodoRecords;
  final bool showCompletedTodos;

  FilterSettings({
    required this.showGoalRecords,
    required this.showRoutineRecords,
    this.showTodoRecords = false,
    required this.showCompletedTodos,
  });

  FilterSettings copyWith({
    bool? showGoalRecords,
    bool? showRoutineRecords,
    bool? showTodoRecords,
    bool? showCompletedTodos,
  }) {
    return FilterSettings(
      showGoalRecords: showGoalRecords ?? this.showGoalRecords,
      showRoutineRecords: showRoutineRecords ?? this.showRoutineRecords,
      showTodoRecords: showTodoRecords ?? this.showTodoRecords,
      showCompletedTodos: showCompletedTodos ?? this.showCompletedTodos,
    );
  }
}
