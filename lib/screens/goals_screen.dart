import 'package:flutter/material.dart';
import 'dart:async';
import '../db_manager.dart';
import '../models/goal.model.dart';
import '../widgets/goal_card.dart';
import 'add_goal_screen.dart';
import '../services/timer_service.dart';
import '../services/daily_reset_service.dart';
import '../colors.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with WidgetsBindingObserver {
  List<Goal> _goals = [];
  bool _isLoading = true;
  final dbHelper = DatabaseHelper.instance;
  StreamSubscription? _resetSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGoals();
    // Listen to timer service updates to refresh goal progress
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
    // Refresh goals when timer updates to show latest progress
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await dbHelper.getAllGoals();
      if (mounted) {
        setState(() {
          _goals = goals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading goals: $e')),
        );
      }
    }
  }


  Future<void> _toggleGoalSession(Goal goal) async {
    final timerService = TimerService.instance;

    if (timerService.activeGoal?.id == goal.id && timerService.isRunning) {
      await timerService.stopSession();
    } else {
      await timerService.startSession(goal);
    }

    await _loadGoals();
  }

  Future<void> _deleteGoal(Goal goal) async {
    try {
      final timerService = TimerService.instance;
      if (timerService.activeGoal?.id == goal.id && timerService.isRunning) {
        await timerService.stopSession();
      }

      await dbHelper.deleteGoal(goal.id!);

      if (mounted) {
        setState(() {
          _goals.removeWhere((g) => g.id == goal.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal "${goal.title}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting goal: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MyColors.forthyColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Goal Manager',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: white),
                  onPressed: _showAddGoalForm,
                ),
              ],
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: _goals.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _goals.length,
                          itemBuilder: (context, index) {
                            final goal = _goals[index];
                            return GoalCard(
                              goal: goal,
                              onTap: () => _toggleGoalSession(goal),
                              onDelete: _deleteGoal,
                              onEdit: _showEditGoalForm,
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.track_changes_outlined,
                size: 80,
                color: MyColors.forthyColor,
              ),
              const SizedBox(height: 24),
              Text(
                'No Goals Yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create your first goal to start tracking your progress and building better habits.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MyColors.fivyColor,
                    ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showAddGoalForm,
                icon: const Icon(Icons.add),
                label: const Text('Create Your First Goal'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
