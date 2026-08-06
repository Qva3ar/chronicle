import 'dart:io';
import 'dart:math';

import 'package:live_activities/live_activities.dart';

/// iOS Live Activity for the active goal session (lock screen / Dynamic Island).
///
/// The activity shows a native countdown to the session end rendered by iOS
/// itself (Text(timerInterval:) in the widget extension), so it stays accurate
/// with no updates from the app - the same idea as the Android chronometer
/// notification. All methods are no-ops on non-iOS platforms and on devices
/// where Live Activities are unavailable (iOS < 16.1 or disabled by the user).
class LiveActivityService {
  static final LiveActivityService instance = LiveActivityService._();
  LiveActivityService._();

  static const String _appGroupId = 'group.com.aturdi.chrono.widget';

  final LiveActivities _plugin = LiveActivities();
  bool _initialized = false;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      await _plugin.init(appGroupId: _appGroupId);
      _initialized = true;
      return true;
    } catch (e) {
      print('❌ LIVE ACTIVITY: init failed: $e');
      return false;
    }
  }

  /// Starts (or restarts) the session activity. Only one session can run at a
  /// time, so any previous activity is ended first.
  Future<void> startSessionActivity({
    required String goalTitle,
    required int sessionStartTimeSeconds,
    required int sessionEndTimeSeconds,
    required int totalSpentSeconds,
    required int goalTargetSeconds,
  }) async {
    if (!Platform.isIOS) return;
    try {
      if (!await _ensureInitialized()) return;
      if (!await _plugin.areActivitiesEnabled()) {
        print('ℹ️ LIVE ACTIVITY: Live Activities are disabled/unsupported on this device');
        return;
      }

      await _plugin.endAllActivities();

      final activityId = await _plugin.createActivity(_generateUuidV4(), {
        'goalTitle': goalTitle,
        'sessionStartMs': sessionStartTimeSeconds * 1000,
        'sessionEndMs': sessionEndTimeSeconds * 1000,
        'totalSpentSeconds': totalSpentSeconds,
        'goalTargetSeconds': goalTargetSeconds,
      });
      print('✅ LIVE ACTIVITY: Started session activity $activityId for "$goalTitle"');
    } catch (e) {
      print('❌ LIVE ACTIVITY: Failed to start session activity: $e');
    }
  }

  // The plugin expects a caller-supplied UUID that becomes the ActivityKit
  // attributes id (used to prefix keys in the shared UserDefaults).
  String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Ends every session activity (also cleans up leftovers from a previous
  /// app run, whose ids we no longer know).
  Future<void> endSessionActivity() async {
    if (!Platform.isIOS) return;
    try {
      if (!await _ensureInitialized()) return;
      await _plugin.endAllActivities();
      print('✅ LIVE ACTIVITY: Ended session activities');
    } catch (e) {
      print('❌ LIVE ACTIVITY: Failed to end session activities: $e');
    }
  }
}
