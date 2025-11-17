import 'package:flutter/material.dart';
import '../models/goal.model.dart';
import '../services/timer_service.dart';
import '../colors.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  final Function(Goal)? onDelete;
  final Function(Goal)? onEdit;

  const GoalCard({
    Key? key,
    required this.goal,
    required this.onTap,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  // Calculate real-time progress including current session time
  double _getRealtimeProgress(TimerService timerService, bool isActiveGoal) {
    if (goal.totalSeconds <= 0) return 0.0;

    if (isActiveGoal && timerService.isRunning) {
      // For active running goals, include current session time
      final currentTotalTime = timerService.totalTimeElapsed;
      return (currentTotalTime / goal.totalSeconds).clamp(0.0, 1.0);
    } else {
      // For inactive goals, use stored progress
      return goal.progress;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TimerService.instance,
      builder: (context, child) {
        final timerService = TimerService.instance;
        final isActiveGoal = timerService.activeGoal?.id == goal.id;
        final isRunning = isActiveGoal && timerService.isRunning;

        // Calculate real-time progress
        final realtimeProgress =
            _getRealtimeProgress(timerService, isActiveGoal);

        // Don't allow swipe actions if no actions are provided
        if (onDelete == null && onEdit == null) {
          return _buildGoalCard(
              context, timerService, isActiveGoal, isRunning, realtimeProgress);
        }

        return Dismissible(
          key: Key('goal_${goal.id}'),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Swipe left to delete
              // Prevent deletion of active goals
              if (isActiveGoal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot delete an active goal. Stop the session first.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return false;
              }
              return await _showDeleteConfirmation(context);
            } else if (direction == DismissDirection.startToEnd) {
              // Swipe right to edit
              onEdit?.call(goal);
              return false; // Don't dismiss, just trigger edit
            }
            return false;
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              onDelete?.call(goal);
            }
          },
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(0),
            ),
            alignment: Alignment.centerLeft,
            child: const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(0),
            ),
            alignment: Alignment.centerRight,
            child: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.delete, color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
          child: _buildGoalCard(
              context, timerService, isActiveGoal, isRunning, realtimeProgress),
        );
      },
    );
  }

  Widget _buildGoalCard(BuildContext context, TimerService timerService,
      bool isActiveGoal, bool isRunning, double realtimeProgress) {
    return GestureDetector(
      onTap: goal.isCompleted ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        height: 72,
        decoration: BoxDecoration(
          color: cardColor2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cardColor3,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    goal.isCompleted
                        ? Icons.check
                        : isRunning
                            ? Icons.pause
                            : Icons.play_arrow,
                    size: 24,
                    color: white,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Title and progress section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: white,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Timer for active goals, spent time for inactive goals
                    if (isActiveGoal) ...[
                      Text(
                        isRunning
                            ? 'Running: ${timerService.formatTime(timerService.totalTimeElapsed)}'
                            : 'Time spent: ${goal.formattedTimeSpent}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color:
                              isRunning ? Colors.green[400] : MyColors.fivyColor,
                          height: 1.2,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Time spent: ${goal.formattedTimeSpent}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: MyColors.fivyColor,
                          height: 1.2,
                        ),
                      ),
                    ],

                    const SizedBox(height: 2),

                    // Progress bar and percentage
                    Row(
                      children: [
                        // Progress bar
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: MyColors.forthyColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: realtimeProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getProgressColor(realtimeProgress),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Percentage
                        Text(
                          '${(realtimeProgress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Goal'),
            content: Text(
              'Are you sure you want to delete "${goal.title}"?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) {
      return Colors.green; // Completed
    } else if (progress >= 0.8) {
      return Colors.orange; // Nearly complete
    } else if (progress >= 0.5) {
      return Colors.blue; // Good progress
    } else {
      return const Color(0xFF121417); // Just started/minimal progress
    }
  }
}
