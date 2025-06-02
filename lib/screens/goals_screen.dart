import 'package:flutter/material.dart';
import '../models/goal.model.dart';
import '../widgets/goal_card.dart';
import '../widgets/add_goal_form.dart';
import '../widgets/active_session_widget.dart';
import '../services/database_helper.dart';
import '../services/timer_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    // Listen to timer service updates to refresh goal progress
    TimerService.instance.addListener(_onTimerUpdate);
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_onTimerUpdate);
    super.dispose();
  }

  void _onTimerUpdate() {
    // Refresh goals when timer updates to show latest progress
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await DatabaseHelper.instance.getAllGoals();
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading goals: $e')),
        );
      }
    }
  }

  Future<void> _addGoal(Goal goal) async {
    try {
      final id = await DatabaseHelper.instance.insertGoal(goal);
      final newGoal = goal.copyWith(id: id);
      setState(() {
        _goals.add(newGoal);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding goal: $e')),
        );
      }
    }
  }

  Future<void> _toggleGoalSession(Goal goal) async {
    final timerService = TimerService.instance;

    if (timerService.activeGoal?.id == goal.id && timerService.isRunning) {
      // Stop the current session
      await timerService.stopSession();
    } else {
      // Start a new session
      await timerService.startSession(goal);
    }

    await _loadGoals(); // Refresh the goals list
  }

  Future<void> _deleteGoal(Goal goal) async {
    try {
      // If this goal is currently active, stop the session first
      final timerService = TimerService.instance;
      if (timerService.activeGoal?.id == goal.id && timerService.isRunning) {
        await timerService.stopSession();
      }

      // Delete from database
      await DatabaseHelper.instance.deleteGoal(goal.id!);

      // Remove from local list
      setState(() {
        _goals.removeWhere((g) => g.id == goal.id);
      });

      if (mounted) {
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

  void _showAddGoalForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddGoalForm(onGoalAdded: _addGoal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Goals'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Active session widget (shows only when session is running)
                const ActiveSessionWidget(),

                // Goals list
                Expanded(
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
                              onDelete: (goal) => _deleteGoal(goal),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalForm,
        child: const Icon(Icons.add),
        tooltip: 'Add New Goal',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.track_changes_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Goals Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first goal to start tracking your progress and building better habits.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
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
    );
  }
}
