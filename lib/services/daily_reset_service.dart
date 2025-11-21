import 'package:chrono/db_manager.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/ai/summarizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Service for managing daily reset operations for routines and goals
/// Supports both WorkManager (Android) and manual fallback (all platforms)
class DailyResetService {
  static final DailyResetService instance = DailyResetService._init();
  DailyResetService._init();

  static const String _lastResetDateKey = 'last_daily_reset_date';

  // Test mode disabled - resets at midnight (start of new day)
  static const bool _testMode = false;
  static const Duration _testInterval = Duration(hours: 2);
  static const String _lastResetTimestampKey = 'last_reset_timestamp';

  /// Run daily reset if needed (fallback mechanism for all platforms)
  /// This checks if today's date is different from the last reset date
  /// If different, performs the full daily reset and updates the stored date
  /// If same, does nothing
  ///
  /// Should be called:
  /// - On app startup (after DB and services initialized)
  /// - On app resume (AppLifecycleState.resumed)
  Future<bool> runDailyResetIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_testMode) {
        // TEST MODE: Check if 2 hours have passed since last reset
        final lastResetTimestamp = prefs.getInt(_lastResetTimestampKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final timeSinceLastReset = Duration(milliseconds: now - lastResetTimestamp);

        print('[DailyResetService] 🧪 TEST MODE: Checking if reset needed');
        print('   - Last reset: ${_formatTimestamp(lastResetTimestamp)}');
        print('   - Current time: ${_formatTimestamp(now)}');
        print('   - Time since last reset: ${timeSinceLastReset.inMinutes} minutes');
        print('   - Required interval: ${_testInterval.inHours} hours');

        if (timeSinceLastReset < _testInterval) {
          final minutesRemaining = (_testInterval - timeSinceLastReset).inMinutes;
          print('[DailyResetService] ✅ Reset already done recently. Next reset in $minutesRemaining minutes');
          return false;
        }

        // Need to perform reset
        print('[DailyResetService] 🌅 Starting fallback reset (TEST MODE - 2 hour interval)');
        await _performDailyReset();

        // Update the last reset timestamp
        await prefs.setInt(_lastResetTimestampKey, now);
        print('[DailyResetService] ✅ Fallback reset completed and timestamp stored');
        return true;
      } else {
        // PRODUCTION MODE: Check if date has changed
        final today = _getTodayDateString();
        final lastResetDate = prefs.getString(_lastResetDateKey);

        print('[DailyResetService] Checking if reset needed - today: $today, last reset: $lastResetDate');

        if (lastResetDate == today) {
          // Already reset today, no action needed
          print('[DailyResetService] ✅ Daily reset already completed for today');
          return false;
        }

        // Need to perform daily reset
        print('[DailyResetService] 🌅 Starting fallback daily reset for $today');
        await _performDailyReset();

        // Update the last reset date
        await prefs.setString(_lastResetDateKey, today);
        print('[DailyResetService] ✅ Fallback daily reset completed and date stored');
        return true;
      }
    } catch (e, stackTrace) {
      print('[DailyResetService] ❌ Error in runDailyResetIfNeeded: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Perform the actual daily reset operations
  /// Called by both WorkManager background task and fallback mechanism
  ///
  /// This method:
  /// - Resets all routines (mark is_done = 0)
  /// - Resets all goals' daily progress
  /// - Re-schedules routine notifications for the new day
  /// - Updates the last reset date in SharedPreferences
  Future<void> performDailyResetAndStoreDate() async {
    try {
      if (_testMode) {
        print('[DailyResetService] 🧪 TEST MODE: Starting reset (from background task)');
      } else {
        print('[DailyResetService] 🌅 Starting daily reset (from background task)');
      }

      await _performDailyReset();

      // Store timestamp to prevent duplicate resets
      final prefs = await SharedPreferences.getInstance();

      if (_testMode) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_lastResetTimestampKey, now);
        print('[DailyResetService] ✅ Reset completed and timestamp stored: ${_formatTimestamp(now)}');
      } else {
        final today = _getTodayDateString();
        await prefs.setString(_lastResetDateKey, today);
        print('[DailyResetService] ✅ Daily reset completed and date stored: $today');
      }
    } catch (e, stackTrace) {
      print('[DailyResetService] ❌ Error in performDailyResetAndStoreDate: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Internal method that performs the actual reset logic
  Future<void> _performDailyReset() async {
    final db = DatabaseHelper.instance;
    final goalService = GoalService(db);

    // Reset routines - IMPORTANT: Use resetRoutinesDoneStatus() NOT toggleRoutineDone()
    // toggleRoutineDone() will corrupt streaks during midnight reset (see DAILY_RESET_README.md)
    await db.resetRoutinesDoneStatus();
    print('[DailyResetService] ✅ Routines reset complete');

    // Reset goals' daily progress
    await goalService.resetAllGoals();
    print('[DailyResetService] ✅ Goals reset complete');

    // Reschedule routine notifications for the new day
    final notificationService = NotificationService();
    await notificationService.checkAndRescheduleRoutines(fromBackgroundTask: true);
    print('[DailyResetService] ✅ Routine notifications rescheduled');

    // Run optional summarization rollup
    try {
      await Summarizer.instance.runDailySummary();
      print('[DailyResetService] ✅ Daily summary completed');
    } catch (e) {
      print('[DailyResetService] ⚠️ Summary generation failed (non-critical): $e');
      // Don't rethrow - summary is optional
    }
  }

  /// Get today's date as YYYY-MM-DD string
  String _getTodayDateString() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  /// Format timestamp for logging
  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'never';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  /// Get the last reset date (for debugging/testing)
  Future<String?> getLastResetDate() async {
    final prefs = await SharedPreferences.getInstance();
    if (_testMode) {
      final timestamp = prefs.getInt(_lastResetTimestampKey);
      return timestamp != null ? _formatTimestamp(timestamp) : null;
    }
    return prefs.getString(_lastResetDateKey);
  }

  /// Clear the last reset date (for testing purposes)
  Future<void> clearLastResetDate() async {
    final prefs = await SharedPreferences.getInstance();
    if (_testMode) {
      await prefs.remove(_lastResetTimestampKey);
      print('[DailyResetService] 🧪 TEST MODE: Last reset timestamp cleared');
    } else {
      await prefs.remove(_lastResetDateKey);
      print('[DailyResetService] Last reset date cleared');
    }
  }

  /// Get test mode status
  bool get isTestMode => _testMode;

  /// Get test interval
  Duration get testInterval => _testInterval;
}
