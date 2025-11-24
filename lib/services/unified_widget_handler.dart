import 'dart:developer' as developer;
import 'package:chrono/services/goal_widget_service.dart';
import 'package:chrono/services/routine_widget_service.dart';
import 'package:chrono/services/widget_service.dart';

/// Unified callback for all widget interactions
/// MUST be top-level function for background execution
@pragma('vm:entry-point')
Future<void> unifiedWidgetCallback(Uri? uri) async {
  developer.log('[UnifiedWidgetHandler] Widget interaction received: $uri', name: 'unified_widget');

  if (uri == null) return;

  // Route to appropriate service based on action (host)
  final host = uri.host;
  
  // Goal Widget Actions
  if (['start_goal', 'stop_goal', 'open_goals'].contains(host)) {
    developer.log('[UnifiedWidgetHandler] Routing to GoalWidgetService', name: 'unified_widget');
    await goalWidgetCallback(uri);
  } 
  // Routine Widget Actions
  else if (['toggle_routine', 'open_routines'].contains(host)) {
    developer.log('[UnifiedWidgetHandler] Routing to RoutineWidgetService', name: 'unified_widget');
    await routineWidgetCallback(uri);
  }
  // Insight/Note Widget Actions (Default/Original Widget)
  else {
    developer.log('[UnifiedWidgetHandler] Routing to WidgetService', name: 'unified_widget');
    await WidgetService.handleWidgetInteraction(uri);
  }
}


