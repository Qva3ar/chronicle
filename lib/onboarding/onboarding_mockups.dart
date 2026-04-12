import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Screen 1 — Offline Data Mockup (Your Data. Your Device.)
// ═══════════════════════════════════════════════════════════════════════════

class OfflineDataMockup extends StatelessWidget {
  const OfflineDataMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phone icon with shield
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MyColors.orangeDivider.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MyColors.orangeDivider.withValues(alpha: 0.08),
                      border: Border.all(
                        color: MyColors.orangeDivider.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.smartphone_rounded,
                      size: 52,
                      color: MyColors.orangeDivider,
                    ),
                  ),
                  // Shield badge
                  Positioned(
                    right: 12,
                    bottom: 18,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3B2D),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: successColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 22,
                        color: successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Info cards
            _OfflineInfoCard(
              icon: Icons.wifi_off_rounded,
              title: 'Works Offline',
              subtitle: 'No internet connection required',
              color: const Color(0xFF42A5F5),
            ),
            const SizedBox(height: 10),
            _OfflineInfoCard(
              icon: Icons.storage_rounded,
              title: 'Local Storage',
              subtitle: 'All data stays on your device',
              color: MyColors.orangeDivider,
            ),
            const SizedBox(height: 10),
            _OfflineInfoCard(
              icon: Icons.visibility_off_rounded,
              title: 'No Tracking',
              subtitle: 'We never see your notes or data',
              color: successColor,
            ),
            const SizedBox(height: 10),
            _OfflineInfoCard(
              icon: Icons.import_export_rounded,
              title: 'Export / Import',
              subtitle: 'Back up & transfer data as JSON',
              color: const Color(0xFFAB47BC),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _OfflineInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 3 — Notes Feed Mockup (Your External Brain)
// ═══════════════════════════════════════════════════════════════════════════

class NotesFeedMockup extends StatelessWidget {
  const NotesFeedMockup({super.key});

  static const _mockNotes = [
    _MockNote(
      title: 'Newsletter idea',
      text: 'Had an amazing idea during meditation today — what if I start a weekly newsletter about personal growth?',
      time: '11:30',
      tags: [
        _MockTag('personal', Color(0xFFFFB7A7)),
        _MockTag('mindset', Color(0xFF8BC34A)),
      ],
    ),
    _MockNote(
      title: null,
      text: '"The only way to do great work is to love what you do." — Steve Jobs',
      time: '11:01',
      tags: [
        _MockTag('quote', Color(0xFF7B8CDE)),
        _MockTag('motivation', Color(0xFF8B7ACA)),
      ],
    ),
    _MockNote(
      title: 'Coffee with David',
      text: 'He recommended the book "Deep Work" by Cal Newport. Adding it to my reading list.',
      time: '10:00',
      tags: [
        _MockTag('books', Color(0xFF4DB6AC)),
        _MockTag('meeting', Color(0xFF6D9EEB)),
      ],
    ),
    _MockNote(
      title: 'My Pomodoro setup',
      text: '40 min work / 10 min break instead of the classic 25/5. Game changer for deep focus.',
      time: '08:26',
      tags: [
        _MockTag('productivity', Color(0xFFFFF59D)),
        _MockTag('experiment', Color(0xFF4DB6AC)),
      ],
    ),
    _MockNote(
      title: null,
      text: 'Week 3 of waking up at 5:30 AM. Energy levels are way better.',
      time: '07:51',
      tags: [
        _MockTag('personal', Color(0xFFFFB7A7)),
        _MockTag('productivity', Color(0xFFFFF59D)),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockBottomSheet(
      title: 'Chrono',
      titleIcon: Icons.stream_rounded,
      badgeCount: 24,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _mockNotes.length,
        itemBuilder: (_, i) => _NoteCard(note: _mockNotes[i]),
      ),
    );
  }
}

class _MockNote {
  final String? title;
  final String text;
  final String time;
  final List<_MockTag> tags;

  const _MockNote({
    required this.title,
    required this.text,
    required this.time,
    required this.tags,
  });
}

class _MockTag {
  final String name;
  final Color color;
  const _MockTag(this.name, this.color);
}

class _NoteCard extends StatelessWidget {
  final _MockNote note;
  const _NoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + time row
            Row(
              children: [
                if (note.title != null)
                  Expanded(
                    child: Text(
                      note.title!,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  note.time,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (note.title != null) const SizedBox(height: 4),
            // Text
            Text(
              note.text,
              style: TextStyle(
                color: textSecondary.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Tags
            Row(
              children: [
                for (int i = 0; i < note.tags.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: note.tags[i].color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note.tags[i].name,
                      style: TextStyle(
                        color: note.tags[i].color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 3 — Routines Mockup (Unbreakable Discipline)
// ═══════════════════════════════════════════════════════════════════════════

class RoutinesMockup extends StatelessWidget {
  const RoutinesMockup({super.key});

  static const _routines = [
    _MockRoutine('No phone first 30 min', '05:30', true, 13, 3),
    _MockRoutine('Cold shower', '06:30', true, 8, 3),
    _MockRoutine('Shoulder exercises', '08:00', true, 3, 2),
    _MockRoutine('Take vitamin D3', '09:00', true, 6, 2),
    _MockRoutine('Walk 8000 steps', '12:00', false, 5, 2),
    _MockRoutine('Gratitude journaling', '06:00', false, 3, 2),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockBottomSheet(
      title: 'Routines',
      titleIcon: Icons.schedule_rounded,
      badgeCount: 6,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _routines.length,
        itemBuilder: (_, i) => _RoutineCard(routine: _routines[i]),
      ),
    );
  }
}

class _MockRoutine {
  final String name;
  final String time;
  final bool isDone;
  final int streak;
  final int priority;
  const _MockRoutine(this.name, this.time, this.isDone, this.streak, this.priority);
}

class _RoutineCard extends StatelessWidget {
  final _MockRoutine routine;
  const _RoutineCard({super.key, required this.routine});

  Color get _prioColor {
    if (routine.priority >= 3) return MyColors.orangeDivider;
    if (routine.priority == 2) return infoColor;
    return textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: routine.isDone
              ? successColor.withValues(alpha: 0.3)
              : cardBorder.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left indicator
              Container(width: 4, color: _prioColor.withValues(alpha: 0.7)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Checkbox
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: routine.isDone ? successColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: routine.isDone ? successColor : textMuted,
                            width: 2,
                          ),
                        ),
                        child: routine.isDone
                            ? const Icon(Icons.check, size: 14, color: cardColor2)
                            : null,
                      ),
                      // Name + time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              routine.name,
                              style: TextStyle(
                                color: routine.isDone ? textMuted : textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                decoration: routine.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              routine.time,
                              style: TextStyle(
                                color: routine.isDone ? textHint : textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Streak badge
                      if (routine.streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: warningColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: warningColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 12,
                                color: warningColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${routine.streak}',
                                style: const TextStyle(
                                  color: warningColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// Screen 4 — Goals Timer Mockup (Invest Your Time)
// ═══════════════════════════════════════════════════════════════════════════

class GoalsTimerMockup extends StatelessWidget {
  const GoalsTimerMockup({super.key});

  static const _goals = [
    _MockGoal('Morning meditation', 27, true, true),
    _MockGoal('Read 30 pages daily', 78, false, false),
    _MockGoal('Spanish B1 course', 25, false, false),
    _MockGoal('Spanish A1 - Duolingo', 0, false, false),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockBottomSheet(
      title: 'Goals',
      titleIcon: Icons.track_changes_rounded,
      badgeCount: 4,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _goals.length,
        itemBuilder: (_, i) => _GoalCardMock(goal: _goals[i]),
      ),
    );
  }
}

class _MockGoal {
  final String title;
  final int progressPercent;
  final bool isRunning;
  final bool isActive;
  const _MockGoal(this.title, this.progressPercent, this.isActive, this.isRunning);
}

class _GoalCardMock extends StatelessWidget {
  final _MockGoal goal;
  const _GoalCardMock({super.key, required this.goal});

  Color get _progressColor {
    final p = goal.progressPercent / 100;
    if (p >= 1.0) return successColor;
    if (p >= 0.8) return warningColor;
    if (p >= 0.5) return infoColor;
    return MyColors.forthyColor;
  }

  Color get _accent {
    if (goal.isRunning) return const Color(0xFF66BB6A);
    return MyColors.orangeDivider;
  }

  Color get _borderColor {
    final p = goal.progressPercent / 100;
    if (p >= 1.0) return successColor;
    if (p >= 0.5) return infoColor.withValues(alpha: 0.5);
    return cardBorder.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: _accent.withValues(alpha: 0.7)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Icon container
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _accent.withValues(alpha: 0.20),
                              _accent.withValues(alpha: 0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          goal.isRunning ? Icons.pause : Icons.play_arrow,
                          size: 20,
                          color: _accent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              goal.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              goal.isRunning
                                  ? 'Running: 27:00'
                                  : 'Time spent: ${_formatTime(goal.progressPercent)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: goal.isRunning
                                    ? const Color(0xFF66BB6A)
                                    : textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Progress bar
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: cardColor3.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: goal.progressPercent / 100,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _progressColor,
                                              _progressColor.withValues(alpha: 0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${goal.progressPercent}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _progressColor,
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
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int percent) {
    if (percent == 0) return '0:00';
    // Approximate some reasonable times
    final minutes = (percent * 0.6).round();
    return '0:${minutes.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 5 — AI Chat Mockup (Your Experience, Amplified)
// ═══════════════════════════════════════════════════════════════════════════

class AIChatMockup extends StatelessWidget {
  const AIChatMockup({super.key});

  static const _contextTags = [
    _MockTag('productivity', Color(0xFFFFF59D)),
    _MockTag('health', Color(0xFF4DB6AC)),
    _MockTag('personal', Color(0xFFFFB7A7)),
    _MockTag('learning', Color(0xFF4DB6AC)),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockBottomSheet(
      title: 'AI Chat',
      titleIcon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          // AI Context panel with tags
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
            decoration: BoxDecoration(
              color: surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: MyColors.orangeDivider, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Context',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Active switch
                    Container(
                      width: 36,
                      height: 20,
                      decoration: BoxDecoration(
                        color: MyColors.orangeDivider,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Selected tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _contextTags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tag.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tag.color, width: 1.5),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        color: tag.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  '37 notes · ~2,400 tokens',
                  style: TextStyle(
                    color: textMuted.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _ChatBubble(
                  text: 'What patterns do you see in my notes?',
                  isUser: true,
                ),
                _ChatBubble(
                  text: 'Looking at your 37 notes across #productivity, #health, #personal and #learning:\n\n'
                      '• Your morning routine is solid — 13-day streak on no phone, 8 days cold shower\n\n'
                      '• Reading goal at 78% — you\'re ahead of schedule\n\n'
                      '• Pomodoro 40/10 is working better than 25/5 for your deep work',
                  isUser: false,
                ),
              ],
            ),
          ),
          // API key notice
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Requires your own API key',
              style: TextStyle(
                color: MyColors.remove,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Input bar
          Container(
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ask about your notes...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.send_rounded,
                  color: MyColors.orangeDivider.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser ? cardColor2 : cardColor3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUser ? 'You' : 'AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isUser ? textSecondary : MyColors.orangeDivider,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 6 — Workspaces Mockup (Your Command Center)
// ═══════════════════════════════════════════════════════════════════════════

class WorkspacesMockup extends StatelessWidget {
  const WorkspacesMockup({super.key});

  static const _workspaces = [
    _MockWorkspace('Book notes: Atomic Habits', 2, MyColors.orangeDivider),
    _MockWorkspace('Weekly planning template', 0, Color(0xFF7B8CDE)),
    _MockWorkspace('Morning routine checklist', 0, MyColors.contactDivider),
    _MockWorkspace('Stoic philosophy notes', 0, Color(0xFFE57373)),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockBottomSheet(
      title: 'Workspaces',
      titleIcon: Icons.workspaces_rounded,
      badgeCount: 4,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _workspaces.length,
        itemBuilder: (_, i) => _WorkspaceCard(workspace: _workspaces[i]),
      ),
    );
  }
}

class _MockWorkspace {
  final String name;
  final int linkedNotes;
  final Color accentColor;
  const _MockWorkspace(this.name, this.linkedNotes, this.accentColor);
}

class _WorkspaceCard extends StatelessWidget {
  final _MockWorkspace workspace;
  const _WorkspaceCard({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: workspace.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: workspace.accentColor.withValues(alpha: 0.6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: workspace.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: workspace.accentColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          size: 20,
                          color: workspace.accentColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              workspace.name,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (workspace.linkedNotes > 0) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${workspace.linkedNotes} linked notes',
                                style: const TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textMuted.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// Screen 7 — Productivity Index Mockup (Measure Your Growth)
// ═══════════════════════════════════════════════════════════════════════════

class ProductivityIndexMockup extends StatelessWidget {
  const ProductivityIndexMockup({super.key});

  static const _weekData = [
    _MockDay('Mon', 6.2, false),
    _MockDay('Tue', 7.8, false),
    _MockDay('Wed', 5.1, false),
    _MockDay('Thu', 8.4, false),
    _MockDay('Fri', 9.0, false),
    _MockDay('Sat', 4.3, false),
    _MockDay('Sun', 7.5, true),
  ];

  static const _breakdownItems = [
    _MockBreakdownItem('Routines completed', '5 / 6', 0.83, Color(0xFF66BB6A)),
    _MockBreakdownItem('Goal progress', '78%', 0.78, Color(0xFF42A5F5)),
    _MockBreakdownItem('Notes written', '4 today', 0.6, Color(0xFFAB47BC)),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockBottomSheet(
      title: 'Productivity',
      titleIcon: Icons.analytics_rounded,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            // Score circle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: 0.75,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.greenAccent,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '7.5',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'out of 10',
                            style: TextStyle(
                              color: textMuted.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Week chart
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cardBorder.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This Week',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 80,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: _weekData
                          .map((d) => Expanded(child: _BarColumn(day: d)))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Breakdown
            ...(_breakdownItems.map((item) => _BreakdownRow(item: item))),
          ],
        ),
      ),
    );
  }
}

class _MockDay {
  final String label;
  final double score;
  final bool isToday;
  const _MockDay(this.label, this.score, this.isToday);
}

class _MockBreakdownItem {
  final String title;
  final String value;
  final double progress;
  final Color color;
  const _MockBreakdownItem(this.title, this.value, this.progress, this.color);
}

class _BarColumn extends StatelessWidget {
  final _MockDay day;
  const _BarColumn({super.key, required this.day});

  Color _barColor(double score) {
    if (score >= 7) return Colors.greenAccent;
    if (score >= 4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor(day.score);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bar
          Container(
            width: 14,
            height: (day.score / 10) * 55,
            decoration: BoxDecoration(
              color: day.isToday
                  ? color
                  : color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
              border: day.isToday
                  ? Border.all(color: color, width: 1.5)
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day.label,
            style: TextStyle(
              color: day.isToday ? textPrimary : textMuted,
              fontSize: 10,
              fontWeight: day.isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final _MockBreakdownItem item;
  const _BreakdownRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: item.progress,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(item.color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared — Mock Bottom Sheet Wrapper
// ═══════════════════════════════════════════════════════════════════════════

class _MockBottomSheet extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final int? badgeCount;
  final Widget child;

  const _MockBottomSheet({
    required this.title,
    this.titleIcon,
    this.badgeCount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: cardBorder.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MyColors.forthyColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
              child: Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, size: 20, color: MyColors.orangeDivider),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (badgeCount != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MyColors.orangeDivider.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: MyColors.orangeDivider,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.add_rounded,
                    color: textPrimary,
                    size: 22,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
