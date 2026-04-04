import 'dart:math';
import 'package:flutter/material.dart';
import 'package:chrono/colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Screen 1 — Pulsing Rings (The Hook)
// ═══════════════════════════════════════════════════════════════════════════

class PulsingRingsAnimation extends StatefulWidget {
  final bool active;
  const PulsingRingsAnimation({super.key, this.active = true});

  @override
  State<PulsingRingsAnimation> createState() => _PulsingRingsAnimationState();
}

class _PulsingRingsAnimationState extends State<PulsingRingsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(PulsingRingsAnimation old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.active && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: _PulsingRingsPainter(_ctrl.value),
        );
      },
    );
  }
}

class _PulsingRingsPainter extends CustomPainter {
  final double progress;
  static const int ringCount = 5;
  static const Color accent = MyColors.orangeDivider;

  _PulsingRingsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Central glowing dot
    final dotPaint = Paint()
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, 6, dotPaint);
    canvas.drawCircle(center, 4, Paint()..color = accent);

    // Expanding rings
    for (int i = 0; i < ringCount; i++) {
      final phase = (progress + i / ringCount) % 1.0;
      final radius = phase * maxRadius;
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.6;

      final ringPaint = Paint()
        ..color = accent.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 - phase * 1.2;

      canvas.drawCircle(center, radius, ringPaint);
    }

    // Orbiting particles
    final particlePaint = Paint()..color = accent;
    for (int i = 0; i < 8; i++) {
      final angle = (progress * 2 * pi) + (i * pi / 4);
      final orbitRadius = maxRadius * 0.35 + sin(progress * pi * 2 + i) * 20;
      final px = center.dx + cos(angle) * orbitRadius;
      final py = center.dy + sin(angle) * orbitRadius;
      final particleAlpha = (0.3 + sin(progress * pi * 4 + i * 1.5) * 0.4).clamp(0.0, 1.0);
      particlePaint.color = accent.withValues(alpha: particleAlpha);
      canvas.drawCircle(Offset(px, py), 2.5, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_PulsingRingsPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 2 — Flowing Notes (External Brain)
// ═══════════════════════════════════════════════════════════════════════════

class FlowingNotesAnimation extends StatefulWidget {
  final bool active;
  const FlowingNotesAnimation({super.key, this.active = true});

  @override
  State<FlowingNotesAnimation> createState() => _FlowingNotesAnimationState();
}

class _FlowingNotesAnimationState extends State<FlowingNotesAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _particles = List.generate(20, (_) => _Particle.random(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(FlowingNotesAnimation old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.active && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: _FlowingNotesPainter(_ctrl.value, _particles),
        );
      },
    );
  }
}

class _Particle {
  final double startX, startY;
  final double speed;
  final double size;
  final double phase;

  _Particle(this.startX, this.startY, this.speed, this.size, this.phase);

  static _Particle random(Random rng) {
    return _Particle(
      rng.nextDouble(),
      rng.nextDouble(),
      0.3 + rng.nextDouble() * 0.7,
      1.5 + rng.nextDouble() * 3,
      rng.nextDouble() * 2 * pi,
    );
  }
}

class _FlowingNotesPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  static const Color accent = MyColors.orangeDivider;

  _FlowingNotesPainter(this.progress, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Central "brain" glow
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, 40, glowPaint);

    // Draw central icon shape (stylized note)
    final iconPaint = Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final noteRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 30, height: 38),
      const Radius.circular(4),
    );
    canvas.drawRRect(noteRect, iconPaint);
    // Lines on the note
    for (int i = 0; i < 3; i++) {
      final y = center.dy - 10 + i * 10.0;
      canvas.drawLine(
        Offset(center.dx - 8, y),
        Offset(center.dx + 8, y),
        iconPaint..color = accent.withValues(alpha: 0.3),
      );
    }

    // Flowing particles converging toward center
    for (final p in particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final edgeX = p.startX * size.width;
      final edgeY = p.startY * size.height;

      // Spiral toward center
      final angle = t * pi * 2;
      final radius = (1.0 - t) * size.width * 0.5;
      final x = center.dx + cos(angle + p.phase) * radius * 0.3 +
          (edgeX - center.dx) * (1.0 - t);
      final y = center.dy + sin(angle + p.phase) * radius * 0.3 +
          (edgeY - center.dy) * (1.0 - t);

      final alpha = t < 0.1
          ? t / 0.1
          : t > 0.85
              ? (1.0 - t) / 0.15
              : 1.0;

      final paint = Paint()
        ..color = accent.withValues(alpha: (alpha * 0.7).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), p.size * (0.5 + t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_FlowingNotesPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 3 — Streak Checks (Unbreakable Discipline)
// ═══════════════════════════════════════════════════════════════════════════

class StreakCheckAnimation extends StatefulWidget {
  final bool active;
  const StreakCheckAnimation({super.key, this.active = true});

  @override
  State<StreakCheckAnimation> createState() => _StreakCheckAnimationState();
}

class _StreakCheckAnimationState extends State<StreakCheckAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(StreakCheckAnimation old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.active && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(300, 200),
          painter: _StreakCheckPainter(_ctrl.value),
        );
      },
    );
  }
}

class _StreakCheckPainter extends CustomPainter {
  final double progress;
  static const Color accent = MyColors.orangeDivider;
  static const int days = 7;
  static const List<String> labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  _StreakCheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final circleRadius = 18.0;
    final spacing = size.width / (days + 1);
    final cy = size.height * 0.55;

    for (int i = 0; i < days; i++) {
      final cx = spacing * (i + 1);
      final fillThreshold = (i + 1) / (days + 1);
      final filled = progress > fillThreshold;
      final fillProgress = filled
          ? ((progress - fillThreshold) / (1.0 / (days + 1))).clamp(0.0, 1.0)
          : 0.0;

      // Background circle
      final bgPaint = Paint()
        ..color = cardColor2
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), circleRadius, bgPaint);

      // Border
      final borderPaint = Paint()
        ..color = filled
            ? accent.withValues(alpha: fillProgress)
            : textMuted.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx, cy), circleRadius, borderPaint);

      // Fill animation
      if (filled && fillProgress > 0) {
        final fillPaint = Paint()
          ..color = accent.withValues(alpha: fillProgress * 0.2);
        canvas.drawCircle(
          Offset(cx, cy),
          circleRadius * fillProgress,
          fillPaint,
        );
      }

      // Checkmark
      if (filled && fillProgress > 0.5) {
        final checkAlpha = ((fillProgress - 0.5) * 2).clamp(0.0, 1.0);
        final checkPaint = Paint()
          ..color = accent.withValues(alpha: checkAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

        final path = Path()
          ..moveTo(cx - 6, cy)
          ..lineTo(cx - 1, cy + 5)
          ..lineTo(cx + 7, cy - 5);
        canvas.drawPath(path, checkPaint);
      }

      // Day label
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: filled ? accent : textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy + circleRadius + 8),
      );
    }

    // Streak counter at top
    final streakCount = (progress * days).floor().clamp(0, days);
    final counterPainter = TextPainter(
      text: TextSpan(
        text: '$streakCount',
        style: TextStyle(
          color: accent,
          fontSize: 48,
          fontWeight: FontWeight.w700,
          fontFamily: 'Montserrat',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    counterPainter.paint(
      canvas,
      Offset(
        size.width / 2 - counterPainter.width / 2,
        size.height * 0.08,
      ),
    );

    final dayLabel = TextPainter(
      text: TextSpan(
        text: streakCount == 1 ? 'day streak' : 'days streak',
        style: TextStyle(
          color: textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dayLabel.paint(
      canvas,
      Offset(
        size.width / 2 - dayLabel.width / 2,
        size.height * 0.08 + counterPainter.height + 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_StreakCheckPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 4 — Progress Ring (Time Investment)
// ═══════════════════════════════════════════════════════════════════════════

class ProgressRingAnimation extends StatefulWidget {
  final bool active;
  const ProgressRingAnimation({super.key, this.active = true});

  @override
  State<ProgressRingAnimation> createState() => _ProgressRingAnimationState();
}

class _ProgressRingAnimationState extends State<ProgressRingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(ProgressRingAnimation old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.active && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(260, 260),
          painter: _ProgressRingPainter(_ctrl.value),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  static const Color accent = MyColors.orangeDivider;

  _ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    const strokeWidth = 8.0;

    // Background ring
    final bgPaint = Paint()
      ..color = cardColor2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc — fills to ~78% then resets
    final sweepFraction = Curves.easeInOut.transform(progress) * 0.78;
    final sweepAngle = sweepFraction * 2 * pi;

    final arcPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );

    // Glow at leading edge
    final glowAngle = -pi / 2 + sweepAngle;
    final glowX = center.dx + cos(glowAngle) * radius;
    final glowY = center.dy + sin(glowAngle) * radius;
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(glowX, glowY), 6, glowPaint);

    // Time display
    final totalSeconds = (progress * 9000).floor(); // up to 2:30:00
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final timeStr =
        '${hours.toString().padLeft(1)}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final timePainter = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: const TextStyle(
          color: textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w300,
          fontFamily: 'Montserrat',
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    timePainter.paint(
      canvas,
      Offset(center.dx - timePainter.width / 2, center.dy - timePainter.height / 2),
    );

    // "Deep work" label below timer
    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'deep work',
        style: TextStyle(
          color: textMuted.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy + timePainter.height / 2 + 6,
      ),
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 5 — Neural Network (AI Intelligence)
// ═══════════════════════════════════════════════════════════════════════════

class NeuralNetworkAnimation extends StatefulWidget {
  final bool active;
  const NeuralNetworkAnimation({super.key, this.active = true});

  @override
  State<NeuralNetworkAnimation> createState() => _NeuralNetworkAnimationState();
}

class _NeuralNetworkAnimationState extends State<NeuralNetworkAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_NeuralNode> _nodes;

  @override
  void initState() {
    super.initState();
    final rng = Random(77);
    _nodes = List.generate(14, (_) => _NeuralNode.random(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(NeuralNetworkAnimation old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.active && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: _NeuralNetworkPainter(_ctrl.value, _nodes),
        );
      },
    );
  }
}

class _NeuralNode {
  final double x, y;
  final double driftX, driftY;
  final double phase;
  final double pulseSpeed;

  _NeuralNode(this.x, this.y, this.driftX, this.driftY, this.phase, this.pulseSpeed);

  static _NeuralNode random(Random rng) {
    return _NeuralNode(
      0.15 + rng.nextDouble() * 0.7,
      0.15 + rng.nextDouble() * 0.7,
      (rng.nextDouble() - 0.5) * 0.08,
      (rng.nextDouble() - 0.5) * 0.08,
      rng.nextDouble() * 2 * pi,
      1.0 + rng.nextDouble() * 2.0,
    );
  }

  Offset position(double t, Size size) {
    final px = (x + sin(t * pulseSpeed * pi * 2 + phase) * driftX) * size.width;
    final py = (y + cos(t * pulseSpeed * pi * 2 + phase) * driftY) * size.height;
    return Offset(px, py);
  }
}

class _NeuralNetworkPainter extends CustomPainter {
  final double progress;
  final List<_NeuralNode> nodes;
  static const Color accent = MyColors.orangeDivider;
  static const double connectionThreshold = 110;

  _NeuralNetworkPainter(this.progress, this.nodes);

  @override
  void paint(Canvas canvas, Size size) {
    final positions = nodes.map((n) => n.position(progress, size)).toList();

    // Draw connections
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final dist = (positions[i] - positions[j]).distance;
        if (dist < connectionThreshold) {
          final alpha = (1.0 - dist / connectionThreshold) * 0.25;
          final pulse = sin(progress * pi * 4 + i + j) * 0.5 + 0.5;
          final linePaint = Paint()
            ..color = accent.withValues(alpha: alpha * (0.5 + pulse * 0.5))
            ..strokeWidth = 1.0;
          canvas.drawLine(positions[i], positions[j], linePaint);

          // Data pulse traveling along connection
          if (pulse > 0.7) {
            final pulseT = (progress * 3 + i * 0.1) % 1.0;
            final pulsePt = Offset.lerp(positions[i], positions[j], pulseT)!;
            final dotPaint = Paint()
              ..color = accent.withValues(alpha: 0.6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
            canvas.drawCircle(pulsePt, 2, dotPaint);
          }
        }
      }
    }

    // Draw nodes
    for (int i = 0; i < positions.length; i++) {
      final pulse = sin(progress * pi * 2 * nodes[i].pulseSpeed + nodes[i].phase);
      final nodeSize = 3.5 + pulse * 1.5;
      final nodeAlpha = (0.5 + pulse * 0.3).clamp(0.0, 1.0);

      // Glow
      final glowPaint = Paint()
        ..color = accent.withValues(alpha: nodeAlpha * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(positions[i], nodeSize + 3, glowPaint);

      // Node
      final nodePaint = Paint()..color = accent.withValues(alpha: nodeAlpha);
      canvas.drawCircle(positions[i], nodeSize, nodePaint);
    }
  }

  @override
  bool shouldRepaint(_NeuralNetworkPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen 6 — Workspace Grid (Command Center)
// ═══════════════════════════════════════════════════════════════════════════

class WorkspaceGridAnimation extends StatefulWidget {
  final bool active;
  const WorkspaceGridAnimation({super.key, this.active = true});

  @override
  State<WorkspaceGridAnimation> createState() => _WorkspaceGridAnimationState();
}

class _WorkspaceGridAnimationState extends State<WorkspaceGridAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.active) {
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(WorkspaceGridAnimation old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating && _ctrl.value == 0) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(300, 240),
          painter: _WorkspaceGridPainter(_ctrl.value),
        );
      },
    );
  }
}

class _WorkspaceGridPainter extends CustomPainter {
  final double progress;

  static const List<Color> cardColors = [
    MyColors.orangeDivider,
    MyColors.contactDivider,
    Color(0xFF7B8CDE),
    Color(0xFFE57373),
    Color(0xFF81C784),
    Color(0xFFBA68C8),
  ];

  static const List<String> cardLabels = [
    'Work',
    'Health',
    'Learning',
    'Projects',
    'Finance',
    'Personal',
  ];

  _WorkspaceGridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 3;
    const rows = 2;
    final cardW = (size.width - 32) / cols;
    final cardH = (size.height - 16) / rows;

    for (int i = 0; i < 6; i++) {
      final row = i ~/ cols;
      final col = i % cols;

      // Staggered entrance
      final delay = i * 0.1;
      final cardProgress = ((progress - delay) / 0.6).clamp(0.0, 1.0);
      final eased = Curves.elasticOut.transform(cardProgress);

      if (cardProgress <= 0) continue;

      final targetX = 8.0 + col * (cardW + 8);
      final targetY = row * (cardH + 8);

      // Slide in from below with scale
      final offsetY = (1.0 - eased) * 60;
      final scale = 0.5 + eased * 0.5;

      canvas.save();
      final cx = targetX + cardW / 2;
      final cy = targetY + cardH / 2 + offsetY;
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.translate(-cardW / 2, -cardH / 2);

      // Card background
      final cardRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, cardW, cardH),
        const Radius.circular(12),
      );
      final bgPaint = Paint()..color = cardColor2;
      canvas.drawRRect(cardRect, bgPaint);

      // Border with color accent
      final borderPaint = Paint()
        ..color = cardColors[i].withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(cardRect, borderPaint);

      // Top accent line
      final accentPaint = Paint()
        ..color = cardColors[i].withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(16, 8),
        Offset(cardW * 0.4, 8),
        accentPaint,
      );

      // Label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: cardLabels[i],
          style: TextStyle(
            color: textSecondary.withValues(alpha: eased),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(16, cardH / 2 - 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WorkspaceGridPainter old) => old.progress != progress;
}
