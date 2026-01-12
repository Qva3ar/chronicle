import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'package:chrono/db_manager.dart';
import 'package:chrono/models/routine.model.dart';
import 'package:chrono/services/notification_service.dart';

/// Top-level callback for routine widget interactions
/// MUST be top-level function for background execution
@pragma('vm:entry-point')
Future<void> routineWidgetCallback(Uri? uri) async {
  developer.log('[RoutineWidgetService] Widget interaction received: $uri', name: 'routine_widget');

  if (uri == null) return;

  // Handle different widget actions
  if (uri.host == 'toggle_routine') {
    final routineId = uri.queryParameters['id'];
    developer.log('[RoutineWidgetService] Toggle routine action triggered: $routineId',
        name: 'routine_widget');

    if (routineId != null) {
      try {
        // Toggle routine in database
        final db = DatabaseHelper.instance;
        final notificationService = NotificationService();

        // Initialize notification service for background use
        await notificationService.initialize(calledFromBackgroundTask: true);

        // Get routine current state
        final routinesData = await db.getAllRoutines();
        final routines = routinesData.map((r) => Routine.fromMap(r)).toList();
        final routine = routines.firstWhere((r) => r.id.toString() == routineId);

        final newIsDone = !routine.isDone;

        // Toggle status using the database method (handles streaks)
        await db.toggleRoutineDone(routine.id!, newIsDone);

        if (newIsDone) {
          // 1. Create completion record (Note)
          final record = {
            DatabaseColumns.recordText: 'Completed routine: ${routine.name}',
            DatabaseColumns.recordCreatedAt: DateTime.now().millisecondsSinceEpoch,
            DatabaseColumns.recordType: 'routine',
            DatabaseColumns.recordRoutineId: routine.id,
          };
          await db.insertRecord(record, []);

          // 2. Mark done in notifications (cancels alarms)
          await notificationService.markRoutineDone(routine.id!);

          developer.log('[RoutineWidgetService] Routine completed and note created',
              name: 'routine_widget');
        } else {
          // 1. Reschedule notification if undone
          final nextOccurrence = routine.getNextOccurrence();
          await notificationService.scheduleRoutineNotification(
            routineId: routine.id!,
            routineName: routine.name,
            scheduledTime: nextOccurrence,
            periodAfter: routine.periodAfter,
            interval: routine.interval,
            calledFromBackgroundTask: true,
          );
          developer.log('[RoutineWidgetService] Routine unchecked and rescheduled',
              name: 'routine_widget');
        }

        // Update widget
        final service = RoutineWidgetService(db);
        await service.updateWidget();
      } catch (e) {
        developer.log('[RoutineWidgetService] Error toggling routine: $e',
            name: 'routine_widget', error: e);
      }
    }
  } else if (uri.host == 'open_routines') {
    developer.log('[RoutineWidgetService] Open routines action triggered', name: 'routine_widget');
    // The main app will handle this through initial URI
  }
}

/// Service for managing routines home screen widget on iOS and Android
/// Displays today's routines and allows toggling completion status
class RoutineWidgetService {
  static const String _iosWidgetName = 'ChronoRoutinesWidget';

  // Widget data keys
  static const String _keyRoutinesData = 'routines_data';
  static const String _keyRoutinesCount = 'routines_count';
  static const String _keyCompletedCount = 'completed_count';
  static const String _keyAppName = 'app_name';

  final DatabaseHelper _db;

  RoutineWidgetService(this._db);

  /// Initialize widget service and set up callbacks
  Future<void> initialize() async {
    try {
      developer.log('[RoutineWidgetService] Initializing routine widget service',
          name: 'routine_widget');

      // Callback registration is now handled centrally in main.dart
      // via UnifiedWidgetHandler to support multiple widgets
      // HomeWidget.registerInteractivityCallback(routineWidgetCallback);

      // Initial widget update
      await updateWidget();

      developer.log('[RoutineWidgetService] Routine widget service initialized',
          name: 'routine_widget');
    } catch (e) {
      developer.log('[RoutineWidgetService] Error initializing: $e',
          name: 'routine_widget', error: e);
    }
  }

  /// Update widget with latest routine data
  Future<void> updateWidget() async {
    try {
      developer.log('[RoutineWidgetService] Updating routine widget', name: 'routine_widget');

      // Fetch today's routines
      final routinesData = await _db.getAllRoutines();
      final routines = routinesData.map((r) => Routine.fromMap(r)).toList();
      final now = DateTime.now();
      final currentDay = now.weekday - 1; // Convert to 0-based index (Monday = 0)

      // Filter routines active today
      final todayRoutines = routines.where((routine) {
        return routine.isActiveOnDay(currentDay);
      }).toList();

      // Sort by time
      // Sort by status (completed last) then by time
      todayRoutines.sort((a, b) {
        // 1. Status check: completed items go to bottom
        if (a.isDone && !b.isDone) return 1;
        if (!a.isDone && b.isDone) return -1;

        // 2. Time check
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });

      // Calculate completed count
      final completedCount = todayRoutines.where((r) => r.isDone).length;

      // Convert routines to JSON
      final routinesJson = todayRoutines.take(10).map((routine) {
        return {
          'id': routine.id,
          'name': routine.name,
          'time':
              '${routine.time.hour.toString().padLeft(2, '0')}:${routine.time.minute.toString().padLeft(2, '0')}',
          'isDone': routine.isDone,
          'streak': routine.streak,
          'showStreak': routine.showStreak,
        };
      }).toList();

      // Save widget data
      await HomeWidget.saveWidgetData<String>(_keyRoutinesData, jsonEncode(routinesJson));
      await HomeWidget.saveWidgetData<int>(_keyRoutinesCount, todayRoutines.length);
      await HomeWidget.saveWidgetData<int>(_keyCompletedCount, completedCount);
      await HomeWidget.saveWidgetData<String>(_keyAppName, 'Chrono');

      // Trigger widget update on platform
      await HomeWidget.updateWidget(
        name: 'ChronoRoutinesWidgetProvider',
        iOSName: _iosWidgetName,
      );

      developer.log(
          '[RoutineWidgetService] Routine widget updated with ${todayRoutines.length} routines',
          name: 'routine_widget');
    } catch (e) {
      developer.log('[RoutineWidgetService] Error updating widget: $e',
          name: 'routine_widget', error: e);
    }
  }

  /// Clear all widget data
  Future<void> clearWidget() async {
    try {
      developer.log('[RoutineWidgetService] Clearing routine widget data', name: 'routine_widget');

      await HomeWidget.saveWidgetData<String>(_keyRoutinesData, jsonEncode([]));
      await HomeWidget.saveWidgetData<int>(_keyRoutinesCount, 0);
      await HomeWidget.saveWidgetData<int>(_keyCompletedCount, 0);

      await HomeWidget.updateWidget(
        name: 'ChronoRoutinesWidgetProvider',
        iOSName: _iosWidgetName,
      );

      developer.log('[RoutineWidgetService] Routine widget cleared', name: 'routine_widget');
    } catch (e) {
      developer.log('[RoutineWidgetService] Error clearing widget: $e',
          name: 'routine_widget', error: e);
    }
  }

  /// Get the launch URI if the app was opened from widget
  static Future<Uri?> getWidgetLaunchUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      developer.log('[RoutineWidgetService] Error getting launch URI: $e',
          name: 'routine_widget', error: e);
      return null;
    }
  }
}
