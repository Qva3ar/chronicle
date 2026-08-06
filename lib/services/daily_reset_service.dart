import 'dart:developer';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/goal_service.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/services/todo_notification_service.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:chrono/ai/summarizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

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

  final _resetCompletedSubject = PublishSubject<void>();
  Stream<void> get onResetComplete => _resetCompletedSubject.stream;

  /// In-flight guard: concurrent callers (WorkManager task, app startup,
  /// resume, foreground midnight timer) share the same reset future instead
  /// of running the reset twice in parallel.
  Future<bool>? _inFlight;

  /// Run daily reset if needed (fallback mechanism for all platforms)
  /// This checks if today's date is different from the last reset date
  /// If different, performs the full daily reset and updates the stored date
  /// If same, does nothing
  ///
  /// Should be called:
  /// - On app startup (after DB and services initialized)
  /// - On app resume (AppLifecycleState.resumed)
  /// - By the WorkManager midnight task (via [performDailyResetAndStoreDate])
  /// - By the foreground midnight timer
  Future<bool> runDailyResetIfNeeded() {
    final pending = _inFlight;
    if (pending != null) {
      return pending;
    }
    final future = _runDailyResetIfNeeded().whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  Future<bool> _runDailyResetIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_testMode) {
        // TEST MODE: Check if 2 hours have passed since last reset
        final lastResetTimestamp = prefs.getInt(_lastResetTimestampKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final timeSinceLastReset = Duration(milliseconds: now - lastResetTimestamp);

        if (timeSinceLastReset < _testInterval) {
          return false;
        }

        // Need to perform reset
        await _performDailyReset();

        // Update the last reset timestamp
        await prefs.setInt(_lastResetTimestampKey, now);
        return true;
      } else {
        // PRODUCTION MODE: Check if date has changed
        final today = _getTodayDateString();
        final lastResetDate = prefs.getString(_lastResetDateKey);

        if (lastResetDate == today) {
          // Already reset today, no action needed
          return false;
        }

        // Need to perform daily reset
        await _performDailyReset();

        // Update the last reset date
        await prefs.setString(_lastResetDateKey, today);
        return true;
      }
    } catch (e, stackTrace) {
      log('[DailyResetService] Error in runDailyResetIfNeeded: $e\n$stackTrace');
      // Rethrow so the WorkManager task can report failure (and be retried by
      // the OS). The date key is NOT stored on failure, so the next catch-up
      // (startup / resume / periodic check) will attempt the reset again.
      rethrow;
    }
  }

  /// Perform the daily reset from the WorkManager background task.
  ///
  /// Delegates to [runDailyResetIfNeeded] so the WorkManager path is guarded
  /// by the same `last_daily_reset_date` check as startup/resume catch-up.
  /// This makes the reset idempotent by date: a late-firing, retried or
  /// duplicated background task on a day that was already reset is a no-op
  /// instead of a second destructive reset.
  Future<void> performDailyResetAndStoreDate() async {
    try {
      final performed = await runDailyResetIfNeeded();
      if (performed) {
        print('[DailyResetService] ✅ Daily reset completed and date stored');
      } else {
        print('[DailyResetService] ℹ️ Daily reset already done today — skipped');
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

    // Finalize productivity record for YESTERDAY before resetting.
    // The routine `isDone` flags and goal `timeSpentSeconds` still hold yesterday's
    // end state at this point, so we finalize from that LIVE state (useLiveState)
    // instead of reconstructing from records only — a records-only recompute would
    // under-credit goal time that never reached a goal record and overwrite the
    // correct value the live updates already stored during the day.
    // preserveHigherScore guards against a partially-reset live state lowering it.
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      await ProductivityService.instance.createOrUpdateDailyRecord(
        forDate: yesterdayStr,
        useLiveState: true,
        preserveHigherScore: true,
      );
      print('[DailyResetService] ✅ Productivity record finalized for $yesterdayStr');
    } catch (e) {
      print('[DailyResetService] ⚠️ Productivity record finalization failed (non-critical): $e');
    }

    // Reset routines - IMPORTANT: Use resetRoutinesDoneStatus() NOT toggleRoutineDone()
    // toggleRoutineDone() will corrupt streaks during midnight reset (see DAILY_RESET_README.md)
    await db.resetRoutinesDoneStatus();
    print('[DailyResetService] ✅ Routines reset complete');

    // Self-heal any routine streaks that were previously corrupted (e.g. by the
    // non-idempotent reset bug where streak was wrongly zeroed on retry/fallback).
    // Recomputes streak from the actual completion records. No-op when streaks
    // are already consistent. Safe to run on every daily reset.
    try {
      await db.healRoutineStreaksFromRecords();
      print('[DailyResetService] ✅ Routine streaks self-heal pass complete');
    } catch (e) {
      print('[DailyResetService] ⚠️ Streak self-heal failed (non-critical): $e');
    }

    // Reset goals' daily progress
    await goalService.resetAllGoals();
    print('[DailyResetService] ✅ Goals reset complete');

    // Reschedule routine notifications for the new day
    final notificationService = NotificationService();
    await notificationService.checkAndRescheduleRoutines(fromBackgroundTask: true);
    print('[DailyResetService] ✅ Routine notifications rescheduled');

    // Reschedule todo reminders (deadline daily + tomorrow)
    try {
      final todoNotificationService = TodoNotificationService();
      await todoNotificationService.initialize();
      await todoNotificationService.rescheduleAllReminders();
      print('[DailyResetService] ✅ Todo reminders rescheduled');
    } catch (e) {
      print('[DailyResetService] ⚠️ Todo reminder rescheduling failed (non-critical): $e');
    }

    // Run optional summarization rollup
    try {
      await Summarizer.instance.runDailySummary();
      print('[DailyResetService] ✅ Daily summary completed');
    } catch (e) {
      print('[DailyResetService] ⚠️ Summary generation failed (non-critical): $e');
      // Don't rethrow - summary is optional
    }

    // 🎯 Notify listeners that reset is complete
    _resetCompletedSubject.add(null);
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
