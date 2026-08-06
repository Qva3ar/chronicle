import 'dart:async';

import 'package:flutter/material.dart';
import 'timer_service.dart';
import 'daily_reset_service.dart';
import 'widget_service.dart';
import 'routine_widget_service.dart';
import 'goal_widget_service.dart';
import '../db_manager.dart';

class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService instance = AppLifecycleService._init();
  AppLifecycleService._init();

  bool _isInitialized = false;

  /// Fires at the next local midnight while the app is in the foreground.
  /// Covers the case where the app is kept open across midnight: neither the
  /// WorkManager task (background-only) nor the resume catch-up would run,
  /// and the UI would keep showing yesterday's routines/goals.
  Timer? _midnightTimer;

  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      _armMidnightTimer();
      print('AppLifecycleService initialized');
    }
  }

  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _midnightTimer?.cancel();
      _midnightTimer = null;
      _isInitialized = false;
    }
  }

  /// (Re)arm a timer for the next local midnight.
  void _armMidnightTimer() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // Small buffer so the timer fires safely after the date has flipped.
    final delay = nextMidnight.difference(now) + const Duration(seconds: 5);

    _midnightTimer = Timer(delay, () {
      print('Foreground midnight timer fired - running daily reset check');
      DailyResetService.instance.runDailyResetIfNeeded().then((resetPerformed) {
        if (resetPerformed) {
          print('Daily reset performed by foreground midnight timer');
        }
      }).catchError((error) {
        print('Error in foreground midnight reset: $error');
      }).whenComplete(_armMidnightTimer);
    });

    print('Foreground midnight timer armed for $nextMidnight');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // App is running in the background
        _onAppBackground();
        break;
      case AppLifecycleState.resumed:
        // App is back in the foreground
        _onAppForeground();
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        _onAppTerminated();
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., during a phone call)
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  void _onAppBackground() {
    print('App backgrounded - timer will continue running in background');

    // Foreground-only timer: in the background midnight is covered by the
    // WorkManager task and by the catch-up on the next resume.
    _midnightTimer?.cancel();
    _midnightTimer = null;

    final timerService = TimerService.instance;
    if (timerService.isRunning && timerService.activeGoal != null) {
      // Save current session state before going to background
      // The timer will continue running using timestamps
      timerService.saveProgress();
      print('Session state saved, timer continues in background');
    }
  }

  void _onAppForeground() {
    print('App resumed - checking for background progress');

    // Re-arm the foreground midnight timer for the (possibly new) next midnight
    _armMidnightTimer();

    // Check if daily reset is needed (fallback mechanism)
    // This ensures reset happens even if WorkManager didn't run
    final timerService = TimerService.instance;
    DailyResetService.instance.runDailyResetIfNeeded().then((resetPerformed) {
      if (resetPerformed) {
        print('Daily reset performed on app resume');
      }
    }).catchError((error) {
      print('Error checking daily reset on resume: $error');
    }).whenComplete(() {
      // Refresh timer state only AFTER the reset settles: refreshing mid-reset
      // could re-adopt a stale yesterday session from the DB that the reset is
      // about to wipe, leaving a ghost timer running in memory. On normal days
      // the reset resolves with a cheap prefs read, so this adds no delay.
      timerService.refreshState();

      // The timer service will automatically handle any background completion
      // when it calculates elapsed time based on timestamps
      if (timerService.isRunning) {
        print(
            'Session was running in background - time will be calculated automatically');
      }
    });

    // Update home screen widgets with latest data
    WidgetService(DatabaseHelper.instance).updateWidget().then((_) {
      print('Insights widget updated on app resume');
    }).catchError((error) {
      print('Error updating insights widget on resume: $error');
    });

    // Update routines widget
    RoutineWidgetService(DatabaseHelper.instance).updateWidget().then((_) {
      print('Routines widget updated on app resume');
    }).catchError((error) {
      print('Error updating routines widget on resume: $error');
    });

    // Update goals widget
    GoalWidgetService(DatabaseHelper.instance).updateWidget().then((_) {
      print('Goals widget updated on app resume');
    }).catchError((error) {
      print('Error updating goals widget on resume: $error');
    });
  }

  void _onAppTerminated() {
    print('App terminated - saving final state');
    final timerService = TimerService.instance;
    if (timerService.isRunning && timerService.activeGoal != null) {
      // Save progress but keep session state for recovery when app restarts
      timerService.saveProgress();
      print(
          'Progress saved on app termination - session will be restored on restart');
    }
  }
}
