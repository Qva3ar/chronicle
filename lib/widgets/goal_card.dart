import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';
import '../models/goal.model.dart';
import '../services/timer_service.dart';
import '../colors.dart';

enum _GoalCardAction { calendar, toggleArchived }

class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  final Function(Goal)? onDelete;
  final Function(Goal)? onEdit;
  final VoidCallback? onCalendar;
  final VoidCallback? onToggleArchived;

  /// Whether the goal is scheduled for the current weekday. When false the
  /// card is dimmed and the start-session tap is disabled (edit/delete/menu
  /// still work), mirroring how the routine manager treats other-day items.
  final bool scheduledToday;

  const GoalCard({
    Key? key,
    required this.goal,
    required this.onTap,
    this.onDelete,
    this.onEdit,
    this.onCalendar,
    this.onToggleArchived,
    this.scheduledToday = true,
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
                  SnackBar(
                    content: Text(AppLocalizations.of(context).goalCannotDeleteActive),
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
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).commonEdit,
                    style: const TextStyle(
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
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppLocalizations.of(context).commonDelete,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.delete, color: Colors.white, size: 24),
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

  /// Left indicator colour derived from the goal's importance (priority).
  /// Mirrors the routine tiles so importance is visible at a glance.
  Color _priorityColor(int priority) {
    switch (priority) {
      case 1: return textMuted;
      case 2: return infoColor;
      case 3: return warningColor;
      case 4: return MyColors.remove;
      default: return infoColor;
    }
  }

  /// Icon container accent based on running/done state.
  Color _iconAccent(bool isRunning) {
    if (goal.isArchived) return successColor;
    if (goal.isCompleted) return successColor;
    if (isRunning) return const Color(0xFF66BB6A);
    return MyColors.orangeDivider;
  }

  Widget _buildGoalCard(BuildContext context, TimerService timerService,
      bool isActiveGoal, bool isRunning, double realtimeProgress) {
    final progressColor = _getProgressColor(realtimeProgress);
    final accent = _iconAccent(isRunning);

    return Opacity(
      opacity: scheduledToday ? 1.0 : 0.5,
      child: GestureDetector(
      // Make the whole card tappable, including padding/gaps between widgets.
      // Without this the default deferToChild behavior only registers taps that
      // land exactly on an opaque child, so the goal feels unresponsive.
      behavior: HitTestBehavior.opaque,
      onTap: (goal.isArchived || goal.isCompleted || !scheduledToday) ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cardColor2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left colour indicator — reflects the goal's importance.
                Container(
                  width: 4,
                  color: _priorityColor(goal.priority).withValues(alpha: 0.7),
                ),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Icon container
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.20),
                                accent.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              goal.isArchived
                                  ? Icons.check_circle_outline
                                  : goal.isCompleted
                                      ? Icons.check
                                      : isRunning
                                          ? Icons.pause
                                          : Icons.play_arrow,
                              size: 22,
                              color: accent,
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 2),

                              // Timer for active goals, spent time for inactive goals
                              if (isActiveGoal) ...[
                                Text(
                                  isRunning
                                      ? AppLocalizations.of(context).goalRunning(timerService.formatTime(timerService.totalTimeElapsed))
                                      : AppLocalizations.of(context).goalTimeSpent(goal.formattedTimeSpent),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: isRunning ? const Color(0xFF66BB6A) : textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  AppLocalizations.of(context).goalTimeSpent(goal.formattedTimeSpent),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: textSecondary,
                                    height: 1.2,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 6),

                              // Progress bar and percentage
                              Row(
                                children: [
                                  // Progress bar
                                  Expanded(
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: cardColor3.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: realtimeProgress,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                progressColor,
                                                progressColor.withValues(alpha: 0.7),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  // Percentage
                                  Text(
                                    '${(realtimeProgress * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: progressColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Trailing actions (overflow menu)
                        if (onCalendar != null || onToggleArchived != null) ...[
                          const SizedBox(width: 4),
                          PopupMenuButton<_GoalCardAction>(
                            tooltip: AppLocalizations.of(context).commonActions,
                            color: cardColor3,
                            icon: const Icon(
                              Icons.more_vert,
                              color: textMuted,
                              size: 20,
                            ),
                            itemBuilder: (context) => [
                              if (onCalendar != null)
                                PopupMenuItem<_GoalCardAction>(
                                  value: _GoalCardAction.calendar,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18, color: textSecondary),
                                      const SizedBox(width: 10),
                                      Text(AppLocalizations.of(context).commonCalendar, style: const TextStyle(color: textPrimary)),
                                    ],
                                  ),
                                ),
                              if (onToggleArchived != null)
                                PopupMenuItem<_GoalCardAction>(
                                  value: _GoalCardAction.toggleArchived,
                                  child: Row(
                                    children: [
                                      Icon(
                                        goal.isArchived ? Icons.undo : Icons.check_circle_outline,
                                        size: 18,
                                        color: textPrimary,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        goal.isArchived
                                            ? AppLocalizations.of(context).goalUncomplete
                                            : AppLocalizations.of(context).goalComplete,
                                        style: const TextStyle(color: textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onSelected: (action) {
                              switch (action) {
                                case _GoalCardAction.calendar:
                                  onCalendar?.call();
                                  break;
                                case _GoalCardAction.toggleArchived:
                                  onToggleArchived?.call();
                                  break;
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).goalDeleteTitle),
            content: Text(
              AppLocalizations.of(context).goalDeleteMessage(goal.title),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: Text(AppLocalizations.of(context).commonDelete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return successColor;
    if (progress >= 0.8) return warningColor;
    if (progress >= 0.5) return infoColor;
    return MyColors.forthyColor;
  }
}
