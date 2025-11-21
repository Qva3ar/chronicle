import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import '../db_manager.dart';

/// Service for managing home screen widgets on iOS and Android
/// Displays latest AI insights and provides quick note creation
class WidgetService {
  static const String _iosWidgetName = 'ChronoWidget';

  // Widget data keys
  static const String _keyHasInsight = 'has_insight';
  static const String _keyInsightTitle = 'insight_title';
  static const String _keyInsightBody = 'insight_body';
  static const String _keyInsightTags = 'insight_tags';
  static const String _keyAppName = 'app_name';
  static const String _keyPlaceholder = 'placeholder_text';

  final DatabaseHelper _db;

  WidgetService(this._db);

  /// Initialize widget service and set up callbacks
  Future<void> initialize() async {
    try {
      developer.log('[WidgetService] Initializing widget service', name: 'widget');

      // Register callback for widget interactions
      HomeWidget.registerInteractivityCallback(_handleWidgetInteraction);

      // Initial widget update
      await updateWidget();

      developer.log('[WidgetService] Widget service initialized', name: 'widget');
    } catch (e) {
      developer.log('[WidgetService] Error initializing: $e', name: 'widget', error: e);
    }
  }

  /// Update widget with latest insight data
  Future<void> updateWidget() async {
    try {
      developer.log('[WidgetService] Updating widget', name: 'widget');

      // Fetch latest insight
      final insights = await _db.getInsightsForWidget();

      if (insights.isNotEmpty) {
        final insight = insights.first;

        // Widget has insight
        await HomeWidget.saveWidgetData<bool>(_keyHasInsight, true);
        await HomeWidget.saveWidgetData<String>(_keyInsightTitle, insight['title'] ?? 'Insight');
        await HomeWidget.saveWidgetData<String>(_keyInsightBody, insight['body'] ?? '');
        await HomeWidget.saveWidgetData<String>(_keyInsightTags, insight['tags'] ?? '[]');

        developer.log('[WidgetService] Widget updated with insight: ${insight['title']}', name: 'widget');
      } else {
        // No insights available
        await HomeWidget.saveWidgetData<bool>(_keyHasInsight, false);
        await HomeWidget.saveWidgetData<String>(_keyInsightTitle, '');
        await HomeWidget.saveWidgetData<String>(_keyInsightBody, '');
        await HomeWidget.saveWidgetData<String>(_keyInsightTags, '[]');

        developer.log('[WidgetService] Widget updated with no insights', name: 'widget');
      }

      // Set app metadata
      await HomeWidget.saveWidgetData<String>(_keyAppName, 'Chrono');
      await HomeWidget.saveWidgetData<String>(_keyPlaceholder, 'No insights yet');

      // Trigger widget update on platform - update all three Android widget sizes
      await HomeWidget.updateWidget(
        name: 'ChronoSmallWidgetProvider',
        iOSName: _iosWidgetName,
      );
      await HomeWidget.updateWidget(
        name: 'ChronoMediumWidgetProvider',
        iOSName: _iosWidgetName,
      );
      await HomeWidget.updateWidget(
        name: 'ChronoLargeWidgetProvider',
        iOSName: _iosWidgetName,
      );

      developer.log('[WidgetService] Widget update completed', name: 'widget');
    } catch (e) {
      developer.log('[WidgetService] Error updating widget: $e', name: 'widget', error: e);
    }
  }

  /// Clear all widget data
  Future<void> clearWidget() async {
    try {
      developer.log('[WidgetService] Clearing widget data', name: 'widget');

      await HomeWidget.saveWidgetData<bool>(_keyHasInsight, false);
      await HomeWidget.saveWidgetData<String>(_keyInsightTitle, '');
      await HomeWidget.saveWidgetData<String>(_keyInsightBody, '');
      await HomeWidget.saveWidgetData<String>(_keyInsightTags, '[]');

      await HomeWidget.updateWidget(
        name: 'ChronoSmallWidgetProvider',
        iOSName: _iosWidgetName,
      );
      await HomeWidget.updateWidget(
        name: 'ChronoMediumWidgetProvider',
        iOSName: _iosWidgetName,
      );
      await HomeWidget.updateWidget(
        name: 'ChronoLargeWidgetProvider',
        iOSName: _iosWidgetName,
      );

      developer.log('[WidgetService] Widget cleared', name: 'widget');
    } catch (e) {
      developer.log('[WidgetService] Error clearing widget: $e', name: 'widget', error: e);
    }
  }

  /// Handle widget interaction callbacks
  static Future<void> _handleWidgetInteraction(Uri? uri) async {
    developer.log('[WidgetService] Widget interaction received: $uri', name: 'widget');

    if (uri == null) return;

    // Handle different widget actions
    if (uri.host == 'create_note') {
      developer.log('[WidgetService] Create note action triggered', name: 'widget');
      // The main app will handle this through initial URI
    } else if (uri.host == 'open_insight') {
      developer.log('[WidgetService] Open insight action triggered', name: 'widget');
      // The main app will handle this through initial URI
    }
  }

  /// Get the launch URI if the app was opened from widget
  static Future<Uri?> getWidgetLaunchUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      developer.log('[WidgetService] Error getting launch URI: $e', name: 'widget', error: e);
      return null;
    }
  }
}
