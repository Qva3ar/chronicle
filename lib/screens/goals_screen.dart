import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'dart:async';
import '../db_manager.dart';
import '../models/goal.model.dart';
import '../widgets/goal_card.dart';
import '../shared/chrono_ui.dart';
import 'add_goal_screen.dart';
import '../services/timer_service.dart';
import '../services/daily_reset_service.dart';
import '../services/goal_service.dart'; // Added import
import '../colors.dart';
import '../shared/premium_gate.dart';
import 'goal_calendar_screen.dart';

class GoalsScreen extends StatefulWidget {
  /// When set (e.g. inside [DraggableScrollableSheet]), list scroll is linked to sheet drag so
  /// pulling down on content dismisses the sheet while keeping the list scrollable.
  final ScrollController? sheetScrollController;

  const GoalsScreen({Key? key, this.sheetScrollController}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with WidgetsBindingObserver {
  List<Goal> _activeGoals = [];
  List<Goal> _archivedGoals = [];
  // Active goals scheduled for today (reorderable, timer-enabled).
  List<Goal> _todayGoals = [];
  // Active goals not scheduled for today (dimmed, non-reorderable section).
  List<Goal> _otherDayGoals = [];
  bool _showArchived = false;
  bool _isLoading = true;
  final dbHelper = DatabaseHelper.instance;
  late final GoalService _goalService; // Added GoalService
  StreamSubscription? _resetSubscription;
  int _loadRequestId = 0;

  // Snapshot TimerService state to avoid reloading DB on every tick.
  int? _lastTimerActiveGoalId;
  bool? _lastTimerIsRunning;

  @override
  void initState() {
    super.initState();
    _goalService = GoalService(dbHelper); // Initialize GoalService
    WidgetsBinding.instance.addObserver(this);
    _loadGoals(showLoading: true);

    // Prime snapshot before subscribing (avoids an extra reload on first tick).
    _lastTimerActiveGoalId = TimerService.instance.activeGoal?.id;
    _lastTimerIsRunning = TimerService.instance.isRunning;

    // Listen to timer service updates
    TimerService.instance.addListener(_onTimerUpdate);

    // 🎯 Listen for daily reset events to update UI
    _resetSubscription = DailyResetService.instance.onResetComplete.listen((_) {
      print("🔄 GoalsScreen: Daily reset detected, reloading goals");
      _loadGoals();
    });
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_onTimerUpdate);
    WidgetsBinding.instance.removeObserver(this);
    _resetSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("App resumed, reloading goals.");
      _loadGoals();
    }
  }

  void _onTimerUpdate() {
    // TimerService notifies every second; don't hit DB every tick.
    //
    // GoalCard already rebuilds from TimerService for real-time UI.
    // We only reload goals when timer *state* changes (start/stop/switch goal),
    // because DB fields like isActive / timeSpentSeconds may change at those moments.
    final timerService = TimerService.instance;
    final currentActiveGoalId = timerService.activeGoal?.id;
    final currentIsRunning = timerService.isRunning;

    final hasChanged =
        currentActiveGoalId != _lastTimerActiveGoalId || currentIsRunning != _lastTimerIsRunning;

    _lastTimerActiveGoalId = currentActiveGoalId;
    _lastTimerIsRunning = currentIsRunning;

    if (hasChanged) {
      _loadGoals();
    }
  }

  Future<void> _loadGoals({bool showLoading = false}) async {
    final requestId = ++_loadRequestId;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final goals = await dbHelper.getAllGoals();
      // Load saved order
      final savedOrder = await _goalService.getGoalOrder();

      if (mounted && requestId == _loadRequestId) {
        setState(() {
          final active = goals.where((g) => !g.isArchived).toList();

          // Sort active goals based on saved order
          if (savedOrder.isNotEmpty) {
            final goalMap = {for (var g in active) g.id!: g};
            final sortedActive = <Goal>[];

            // Add goals matching the saved order
            for (var id in savedOrder) {
              if (goalMap.containsKey(id)) {
                sortedActive.add(goalMap.remove(id)!);
              }
            }

            // Append any remaining goals (newly created or lost IDs)
            sortedActive.addAll(goalMap.values);
            _activeGoals = sortedActive;
          } else {
            _activeGoals = active;
          }

          _splitByDay();
          _archivedGoals = goals.where((g) => g.isArchived).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).goalsErrorLoading(e.toString()))),
        );
      }
    }
  }

  Future<void> _toggleGoalSession(Goal goal) async {
    if (goal.isArchived) return;
    if (!checkPremiumOrShowPaywall(context)) return;
    final timerService = TimerService.instance;

    if (timerService.activeGoal?.id == goal.id && timerService.isRunning) {
      await timerService.stopSession();
    } else {
      await timerService.startSession(goal);
    }

    await _loadGoals();
  }

  Future<void> _openCalendar(Goal goal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GoalCalendarScreen(goal: goal)),
    );
  }

  Future<void> _toggleArchived(Goal goal) async {
    final timerService = TimerService.instance;
    if (timerService.activeGoal?.id == goal.id && timerService.isRunning) {
      await timerService.stopSession();
    }

    final updated = goal.isArchived
        ? goal.copyWith(clearArchivedAt: true)
        : goal.copyWith(
            archivedAt: DateTime.now().millisecondsSinceEpoch,
            isActive: false,
            sessionResumedTimestampSeconds: null,
            clearSessionResumedTimestamp: true,
            clearCurrentDayRecordId: true,
          );

    await dbHelper.updateGoal(updated);
    await _loadGoals();
  }

  Future<void> _deleteGoal(Goal goal) async {
    try {
      final timerService = TimerService.instance;
      if (timerService.activeGoal?.id == goal.id && timerService.isRunning) {
        await timerService.stopSession();
      }

      await dbHelper.deleteGoal(goal.id!);

      // Reload to keep UI fully consistent with DB state.
      await _loadGoals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).goalDeletedSuccess(goal.title)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).goalErrorDeleting(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddGoalForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddGoalScreen(),
      ),
    );

    if (result == true) {
      await _loadGoals();
    }
  }

  Future<void> _showEditGoalForm(Goal goal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGoalScreen(existingGoal: goal),
      ),
    );

    if (result == true) {
      await _loadGoals();
    }
  }

  /// Partition [_activeGoals] into today's scheduled goals and the rest,
  /// preserving the saved global order within each group.
  void _splitByDay() {
    final todayIndex = DateTime.now().weekday - 1;
    _todayGoals =
        _activeGoals.where((g) => g.isActiveOnDay(todayIndex)).toList();
    _otherDayGoals =
        _activeGoals.where((g) => !g.isActiveOnDay(todayIndex)).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      // Reordering only affects today's goals; other-day goals keep their
      // relative order and are appended after them in the saved order.
      final Goal item = _todayGoals.removeAt(oldIndex);
      _todayGoals.insert(newIndex, item);
      _activeGoals = [..._todayGoals, ..._otherDayGoals];
    });

    // Save the new order
    final ids = _activeGoals.map((g) => g.id!).toList();
    _goalService.saveGoalOrder(ids);
  }

  Widget _buildHeader() {
    return ChronoSheetHeader(
      title: AppLocalizations.of(context).navGoals,
      titleIcon: Icons.flag_rounded,
      itemCount: _activeGoals.length,
      actions: [
        IconButton(
          icon: Icon(
            _showArchived ? Icons.visibility : Icons.visibility_off,
            color: _showArchived ? textPrimary : textMuted,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _showArchived = !_showArchived;
            });
          },
          tooltip: _showArchived
              ? AppLocalizations.of(context).goalsHideCompleted
              : AppLocalizations.of(context).goalsShowCompleted,
        ),
        IconButton(
          icon: const Icon(Icons.add, color: textPrimary),
          onPressed: () {
            if (!checkPremiumOrShowPaywall(context)) return;
            _showAddGoalForm();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtrl = widget.sheetScrollController;

    if (sheetCtrl != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: cardColor,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? ListView(
                        controller: sheetCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(
                            height: 280,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ],
                      )
                    : (_activeGoals.isEmpty && (!_showArchived || _archivedGoals.isEmpty))
                        ? ListView(
                            controller: sheetCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _buildEmptyState(),
                            ],
                          )
                        : ReorderableListView(
                            scrollController: sheetCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            onReorder: _onReorder,
                            footer: _buildListFooter(),
                            children: [
                              ..._todayGoals.map((goal) => _goalCard(goal)),
                            ],
                          ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: (_activeGoals.isEmpty && (!_showArchived || _archivedGoals.isEmpty))
                      ? _buildEmptyState()
                      : ReorderableListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onReorder: _onReorder,
                          footer: _buildListFooter(),
                          children: [
                            ..._todayGoals.map((goal) => _goalCard(goal)),
                          ],
                        ),
                ),
        ],
      ),
    );
  }

  Widget _goalCard(Goal goal, {bool scheduledToday = true}) {
    return GoalCard(
      key: ValueKey(goal.id),
      goal: goal,
      scheduledToday: scheduledToday,
      onTap: () => _toggleGoalSession(goal),
      onDelete: _deleteGoal,
      onEdit: _showEditGoalForm,
      onCalendar: () => _openCalendar(goal),
      onToggleArchived: () => _toggleArchived(goal),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: MyColors.fivyColor,
        ),
      ),
    );
  }

  /// Footer for the reorderable list: dimmed other-day goals section followed
  /// by the (optional) archived/completed section.
  Widget? _buildListFooter() {
    final showOther = _otherDayGoals.isNotEmpty;
    final showArchived = _showArchived && _archivedGoals.isNotEmpty;
    if (!showOther && !showArchived) return null;

    return Column(
      children: [
        if (showOther) ...[
          _sectionHeader(AppLocalizations.of(context).routineOtherDays),
          ..._otherDayGoals.map((g) => _goalCard(g, scheduledToday: false)),
        ],
        if (showArchived) ...[
          _sectionHeader(AppLocalizations.of(context).goalCompleted),
          ..._archivedGoals.map((g) => _goalCard(g)),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return ChronoEmptyState(
      icon: Icons.track_changes_outlined,
      title: AppLocalizations.of(context).goalsEmptyTitle,
      subtitle: AppLocalizations.of(context).goalsEmptyDesc,
      buttonLabel: AppLocalizations.of(context).goalsCreateFirst,
      onButton: _showAddGoalForm,
    );
  }
}
