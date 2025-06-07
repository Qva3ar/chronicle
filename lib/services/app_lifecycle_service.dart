import 'package:flutter/material.dart';
import 'timer_service.dart';

class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService instance = AppLifecycleService._init();
  AppLifecycleService._init();

  bool _isInitialized = false;

  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      print('AppLifecycleService initialized');
    }
  }

  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
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
    final timerService = TimerService.instance;

    // Refresh timer state from database in case session was completed in background
    timerService.refreshState();

    // The timer service will automatically handle any background completion
    // when it calculates elapsed time based on timestamps
    if (timerService.isRunning) {
      print(
          'Session was running in background - time will be calculated automatically');
    }
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
