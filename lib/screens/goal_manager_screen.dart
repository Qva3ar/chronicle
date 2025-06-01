import 'dart:async';
import 'package:flutter/material.dart';
import '../models/goal.model.dart';
import '../services/goal.service.dart';
import 'package:chrono/services/background_timer_service.dart';
import 'package:chrono/models/daily_progress.dart';
import 'package:chrono/screens/add_goal_screen.dart';
import 'package:chrono/screens/goal_details_screen.dart';
import 'package:chrono/widgets/goal_progress_card.dart';
import 'package:chrono/widgets/active_session_widget.dart';

class GoalManagerScreen extends StatefulWidget {
  const GoalManagerScreen({Key? key}) : super(key: key);

  @override
  State<GoalManagerScreen> createState() => _GoalManagerScreenState();
}

class _GoalManagerScreenState extends State<GoalManagerScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '0');
  final _sessionHoursController = TextEditingController(text: '0');
  final _sessionMinutesController = TextEditingController(text: '25');
  final _goalService = GoalService();
  final BackgroundTimerService _timerService = BackgroundTimerService.instance;
  
  List<DailyProgress> _dailyProgress = [];
  bool _isLoading = true;
  bool _hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _sessionHoursController.dispose();
    _sessionMinutesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadDailyProgress();
    }
  }

  Future<void> _initializeScreen() async {
    await _loadDailyProgress();
    await _checkForActiveSession();
  }

  Future<void> _loadDailyProgress() async {
    setState(() => _isLoading = true);

    try {
      final progress =     await _goalService.getDailyProgressForAllGoals();
      setState(() {
        _dailyProgress = progress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load goals: $e');
    }
  }

  Future<void> _checkForActiveSession() async {
    final isActive = await _timerService.isSessionActive;
    setState(() => _hasActiveSession = isActive);
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Goal'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Total Goal Duration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hoursController,
                        decoration: const InputDecoration(
                          labelText: 'Hours',
                          border: OutlineInputBorder(),
                          suffixText: 'h',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final hours = int.tryParse(value);
                          if (hours == null || hours < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _minutesController,
                        decoration: const InputDecoration(
                          labelText: 'Minutes',
                          border: OutlineInputBorder(),
                          suffixText: 'min',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final minutes = int.tryParse(value);
                          if (minutes == null || minutes < 0 || minutes >= 60) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Session Duration (auto-pause reminder)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sessionHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Hours',
                          border: OutlineInputBorder(),
                          suffixText: 'h',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final hours = int.tryParse(value);
                          if (hours == null || hours < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _sessionMinutesController,
                        decoration: const InputDecoration(
                          labelText: 'Minutes',
                          border: OutlineInputBorder(),
                          suffixText: 'min',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final minutes = int.tryParse(value);
                          if (minutes == null || minutes < 1 || minutes >= 60) {
                            return 'Must be 1-59';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Timer will pause automatically after each session and ask if you want to continue.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final hours = int.parse(_hoursController.text);
                final minutes = int.parse(_minutesController.text);
                final totalMinutes = hours * 60 + minutes;

                final sessionHours = int.parse(_sessionHoursController.text);
                final sessionMinutes = int.parse(_sessionMinutesController.text);
                final totalSessionMinutes = sessionHours * 60 + sessionMinutes;

                if (totalMinutes == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please set a time greater than 0'),
                    ),
                  );
                  return;
                }

                if (totalSessionMinutes == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please set a session time greater than 0'),
                    ),
                  );
                  return;
                }

                await _goalService.createGoal(
                  _titleController.text,
                  totalMinutes,
                  totalSessionMinutes,
                );
                _titleController.clear();
                _hoursController.text = '0';
                _minutesController.text = '0';
                _sessionHoursController.text = '0';
                _sessionMinutesController.text = '25';
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes min' : ''} ${seconds > 0 ? '$seconds sec' : ''}'
          .trim();
    }
    if (minutes > 0) {
      return '$minutes min ${seconds > 0 ? '$seconds sec' : ''}'.trim();
    }
    return '$seconds sec';
  }

  Widget _buildGoalItem(Goal goal) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal title
            Text(
              goal.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Goal details
            Row(
              children: [
                Text(
                  'Total: ${goal.formattedTime}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Session: ${goal.formattedSessionTime}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar with remaining time
            if (goal.isActive)
              // For active goals, use real-time stream updates
              StreamBuilder<Duration>(
                stream: _goalService.remainingTimeStream.distinct(),
                builder: (context, timeSnapshot) {
                  final remaining = timeSnapshot.hasData
                      ? timeSnapshot.data!
                      : (goal.remainingTime ?? Duration(minutes: goal.totalMinutes));

                  final totalDuration = Duration(minutes: goal.totalMinutes);
                  final progress = remaining.inSeconds <= 0
                      ? 1.0
                      : 1.0 - (remaining.inSeconds / totalDuration.inSeconds);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remaining: ${_formatDuration(remaining)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: remaining.inSeconds <= 0 ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          remaining.inSeconds <= 0
                              ? Colors.red
                              : remaining.inSeconds <= 300 // Less than 5 minutes
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                        minHeight: 6,
                      ),
                    ],
                  );
                },
              )
            else
              // For inactive goals, show static remaining time and progress
              Builder(
                builder: (context) {
                  final remaining = goal.remainingTime ?? Duration(minutes: goal.totalMinutes);
                  final totalDuration = Duration(minutes: goal.totalMinutes);
                  final progress = remaining.inSeconds <= 0
                      ? 1.0
                      : 1.0 - (remaining.inSeconds / totalDuration.inSeconds);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            remaining.inSeconds <= 0
                                ? 'Completed!'
                                : 'Remaining: ${_formatDuration(remaining)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: remaining.inSeconds <= 0 ? Colors.green : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${goal.formattedTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          remaining.inSeconds <= 0 ? Colors.green : Colors.blue,
                        ),
                        minHeight: 6,
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (goal.isActive)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Pause'),
                    onPressed: () => _goalService.pauseGoal(goal),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Start'),
                    onPressed: goal.remainingTime?.inSeconds == 0
                        ? null // Disable if completed
                        : () => _goalService.startGoal(goal),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(goal);
                    } else if (value == 'reset') {
                      _showResetConfirmation(goal);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'reset',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Reset'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Manager'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDailyProgress,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active session widget (if any)
          if (_hasActiveSession)
            ActiveSessionWidget(
              onStop: _stopCurrentSession,
              timerService: _timerService,
            ),

          // Goals list
                    Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dailyProgress.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadDailyProgress,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _dailyProgress.length,
                          itemBuilder: (context, index) {
                            final progress = _dailyProgress[index];
                            return GoalProgressCard(
                              progress: progress,
                              onStartSession: () => _startSession(progress),
                              onViewDetails: () => _navigateToGoalDetails(progress.goalId),
                              isSessionActive: _hasActiveSession,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddGoal,
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.track_changes,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Goals Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
            ),
          ),
          conizedBox(height: 8),
          Text(
            'Create your first learning goal to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
            ),
            textAlign: Texgn.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddGoal,
            icon: const Icon(Icons.add),
            label: const Text('Create Goal'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddGoal() {
    Navigator.of(context)
        .push(
          Materiae(
          ilder: (context) => const AalScreen(),
          ),
        )
        .then((_ _loadDP);
  }

  void _navigateToGoalDetails(int goalId) {
    Navigator.of(context)
        .push(
          Materiae(
          ilder: (context) => GoalDetScreen(goalId: goalId),
          ),
        )
        .then((_ _loadDP);
  }

  Future<void> _startSession(DailyProgress progress) async {
    try {
      // Check if there's already an active session
      if (_hasActiveSession) {
        _showErrorSnackBar('Please stop the current session before starting a new one');
        return;
      }

      // Show confirmation dialog
      final shouldStart = await _showStartSessionDialog(progress);
      if (!shouldStart) return;

      await _timerService.startSession(
        goalId: progress.goalId,
        sessionMinutes: progress.sessionMinutes,
        goalTitle: progress.goalTitle,
      );

      setState(() => _hasActiveSession = true);

      _showSuccessSnackBar('Sess      ion started for ${progress.goalTitle}');
    } catch (e) {
      _showErrorSnackBar('Failed to start session: $e');
    }
  }

  Future<bool> _showStartSessionDialog(DailyProgress progress) async {
    return await showDialog<bool>(
          context: context,
          ber: (context) => AlertDi(
            title: Text('Start Session'),         content: Column(
            inAxisSize: MainAxisSize.mi             crossAxisAlignment: CrossAxisnment.start,
              children: [
                T'Goal: ${progress.goalTi'),
                const SizedBox(height: 8),
            Text('Session Duration: ${pros.sessionMinutes} minutes'),
                const SizedBox(height: 8),
            Text('Remaining Today: ${prog.formattedRemaining}'),
              ],
            ),
           ions: [
          Texton(
                ossed: () => Navigator.oftext).pop(false),
                child: const Text('Cancel'),
          ),
              ElevatedButt             nPressed: () => Navigator.oftext).pop(true),
                child: const Text('Start'),
          ),
            ],
          )      ) ??
    false}

  Fu<voiCurrentSession() async {
    try {
      await _timerService.stopSession();
      setState(() => _hasActiveSession = false);
      await _loadDailyProgress(); // Refresh progress
      _showSuccessSnackBar('Session stopped');
    } catch (e) {
      _showErrorSnackBar('Failed to stop session: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showDeleteConfirmation(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _goalService.deleteGoal(goal);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Goal'),
        content: Text('Are you sure you want to reset "${goal.title}" to its full duration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _goalService.resetGoal(goal);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
