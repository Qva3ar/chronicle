import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chrono/colors.dart';
import 'dart:math' as math;

class ReminderTimelineWidget extends StatefulWidget {
  final TimeOfDay scheduledTime;
  final int periodAfter;
  final int interval;
  final ValueChanged<int> onPeriodAfterChanged;
  final ValueChanged<int> onIntervalChanged;

  const ReminderTimelineWidget({
    super.key,
    required this.scheduledTime,
    required this.periodAfter,
    required this.interval,
    required this.onPeriodAfterChanged,
    required this.onIntervalChanged,
  });

  @override
  State<ReminderTimelineWidget> createState() => _ReminderTimelineWidgetState();
}

enum _DragTarget { period, interval }

class _ReminderTimelineWidgetState extends State<ReminderTimelineWidget>
    with SingleTickerProviderStateMixin {
  static const double _horizontalPadding = 20.0;
  static const double _barTop = 40.0;
  static const double _barHeight = 26.0;
  static const double _bracketY = 76.0;
  static const double _totalHeight = 100.0;

  static const int _minInterval = 5;
  static const int _minPeriod = 5;

  /// Minimum density so timeline stays readable when scrollable
  static const double _minPixelsPerMinute = 3.5;

  _DragTarget? _activeDrag;
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();
  double _viewportWidth = 0;

  int get _visibleMaxMinutes => math.max(widget.periodAfter + 15, 60);

  /// Total notifications: 1 initial + periodAfter/interval retries
  int get _notificationCount {
    if (widget.interval <= 0 || widget.periodAfter <= 0) return 1;
    return (widget.periodAfter / widget.interval).floor() + 1;
  }

  /// Content width: at least the viewport, or wider if period requires scroll
  double _contentWidth(double viewportWidth) {
    final minContentWidth =
        _visibleMaxMinutes * _minPixelsPerMinute + 2 * _horizontalPadding;
    return math.max(viewportWidth, minContentWidth);
  }

  double _minuteToX(double minutes, double contentWidth) {
    final usable = contentWidth - 2 * _horizontalPadding;
    return _horizontalPadding + (minutes / _visibleMaxMinutes) * usable;
  }

  double _xToMinute(double x, double contentWidth) {
    final usable = contentWidth - 2 * _horizontalPadding;
    return ((x - _horizontalPadding) / usable) * _visibleMaxMinutes;
  }

  int _snapTo5(double value) {
    return (value / 5).round().clamp(1, 9999) * 5;
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Pointer-based drag handling (works alongside ScrollView) ---

  void _handlePointerDown(PointerDownEvent event, double contentWidth) {
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final contentX = event.localPosition.dx + scrollOffset;
    final y = event.localPosition.dy;

    final periodX = _minuteToX(widget.periodAfter.toDouble(), contentWidth);
    if ((contentX - periodX).abs() < 28 &&
        y > _barTop - 12 &&
        y < _barTop + _barHeight + 16) {
      setState(() => _activeDrag = _DragTarget.period);
      HapticFeedback.lightImpact();
      return;
    }

    if (widget.interval > 0 && widget.interval < widget.periodAfter) {
      final intervalX = _minuteToX(widget.interval.toDouble(), contentWidth);
      if ((contentX - intervalX).abs() < 28 &&
          y > _bracketY - 12 &&
          y < _bracketY + 20) {
        setState(() => _activeDrag = _DragTarget.interval);
        HapticFeedback.lightImpact();
        return;
      }
    }
  }

  void _handlePointerMove(
      PointerMoveEvent event, double contentWidth, double viewWidth) {
    if (_activeDrag == null) return;

    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final contentX = event.localPosition.dx + scrollOffset;
    final minutes = _xToMinute(contentX, contentWidth);
    final snapped = _snapTo5(minutes);

    if (_activeDrag == _DragTarget.period) {
      final clamped = snapped.clamp(_minPeriod, 1000);
      if (clamped != widget.periodAfter) {
        HapticFeedback.selectionClick();
        widget.onPeriodAfterChanged(clamped);
      }
    } else if (_activeDrag == _DragTarget.interval) {
      final clamped = snapped.clamp(_minInterval, widget.periodAfter);
      if (clamped != widget.interval) {
        HapticFeedback.selectionClick();
        widget.onIntervalChanged(clamped);
      }
    }

    _autoScroll(event.localPosition.dx, viewWidth);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activeDrag != null) {
      setState(() => _activeDrag = null);
    }
  }

  /// Smoothly scroll when dragging a handle near the viewport edges
  void _autoScroll(double pointerX, double viewWidth) {
    if (!_scrollController.hasClients) return;
    const edgeZone = 40.0;
    const speed = 10.0;

    if (pointerX < edgeZone) {
      final factor = 1.0 - (pointerX / edgeZone);
      _scrollController.jumpTo(
        math.max(0, _scrollController.offset - speed * factor),
      );
    } else if (pointerX > viewWidth - edgeZone) {
      final factor = 1.0 - ((viewWidth - pointerX) / edgeZone);
      _scrollController.jumpTo(
        math.min(_scrollController.position.maxScrollExtent,
            _scrollController.offset + speed * factor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final endTime = _addMinutes(widget.scheduledTime, widget.periodAfter);
    final count = _notificationCount;

    return Container(
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor3, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Header ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Row(
              children: [
                const Icon(Icons.notifications_active,
                    size: 14, color: MyColors.orangeDivider),
                const SizedBox(width: 6),
                Text(
                  'Notification Timeline',
                  style: TextStyle(
                    color: MyColors.fivyColor.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MyColors.orangeDivider.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count notification${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: MyColors.orangeDivider.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // --- Scrollable timeline ---
          LayoutBuilder(
            builder: (context, constraints) {
              _viewportWidth = constraints.maxWidth;
              final cWidth = _contentWidth(_viewportWidth);
              final isScrollable = cWidth > _viewportWidth;

              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Listener(
                      onPointerDown: (e) => _handlePointerDown(e, cWidth),
                      onPointerMove: (e) =>
                          _handlePointerMove(e, cWidth, _viewportWidth),
                      onPointerUp: _handlePointerUp,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: _activeDrag != null
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(cWidth, _totalHeight),
                              painter: _TimelinePainter(
                                scheduledTime: widget.scheduledTime,
                                periodAfter: widget.periodAfter,
                                interval: widget.interval,
                                maxMinutes: _visibleMaxMinutes,
                                padding: _horizontalPadding,
                                activeDrag: _activeDrag,
                                pulse: _pulseController.value,
                                notificationCount: count,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (isScrollable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chevron_left,
                              size: 12,
                              color: MyColors.forthyColor.withValues(alpha: 0.5)),
                          Text(
                            ' swipe ',
                            style: TextStyle(
                              color: MyColors.forthyColor.withValues(alpha: 0.5),
                              fontSize: 9,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 12,
                              color: MyColors.forthyColor.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),

          // --- Summary ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  ...List.generate(
                    math.min(count, 6),
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(Icons.notifications,
                          size: 11,
                          color:
                              MyColors.orangeDivider.withValues(alpha: 0.6)),
                    ),
                  ),
                  if (count > 6)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '+${count - 6}',
                        style: TextStyle(
                          color: MyColors.orangeDivider.withValues(alpha: 0.5),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_fmt(widget.scheduledTime)} → ${_fmt(endTime)}  ·  every ${widget.interval} min',
                      style: const TextStyle(
                        color: MyColors.forthyColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Active drag label ---
          if (_activeDrag != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Text(
                _activeDrag == _DragTarget.period
                    ? 'Period: ${widget.periodAfter} min'
                    : 'Interval: ${widget.interval} min',
                style: TextStyle(
                  color: _activeDrag == _DragTarget.period
                      ? MyColors.orangeDivider
                      : const Color(0xFF4FC3F7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter — unchanged drawing logic
// ---------------------------------------------------------------------------

class _TimelinePainter extends CustomPainter {
  final TimeOfDay scheduledTime;
  final int periodAfter;
  final int interval;
  final int maxMinutes;
  final double padding;
  final _DragTarget? activeDrag;
  final double pulse;
  final int notificationCount;

  static const double _rulerY = 32.0;
  static const double _barTop = 40.0;
  static const double _barHeight = 26.0;
  static const double _bracketY = 76.0;

  static const _accentColor = Color(0xFFFF9800);
  static const _accentDeep = Color(0xFFFF6D00);
  static const _intervalColor = Color(0xFF4FC3F7);
  static const _bgDark = Color(0xFF2D2E33);
  static const _tickLight = Color(0xFF777777);
  static const _tickDim = Color(0xFF555555);
  static const _ruleLine = Color(0xFF444444);

  _TimelinePainter({
    required this.scheduledTime,
    required this.periodAfter,
    required this.interval,
    required this.maxMinutes,
    required this.padding,
    required this.activeDrag,
    required this.pulse,
    required this.notificationCount,
  });

  double _minuteToX(double minutes, double width) {
    final usable = width - 2 * padding;
    return padding + (minutes / maxMinutes) * usable;
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void paint(Canvas canvas, Size size) {
    _drawRuler(canvas, size);
    _drawActiveBar(canvas, size);
    _drawNotificationMarkers(canvas, size);
    _drawPeriodHandle(canvas, size);
    _drawIntervalBracket(canvas, size);
  }

  void _drawRuler(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(padding, _rulerY),
      Offset(size.width - padding, _rulerY),
      Paint()
        ..color = _ruleLine
        ..strokeWidth = 1,
    );

    final tickStep = maxMinutes <= 30
        ? 5
        : maxMinutes <= 60
            ? 10
            : maxMinutes <= 120
                ? 15
                : 30;
    final labelStep = maxMinutes <= 60
        ? 10
        : maxMinutes <= 120
            ? 30
            : 60;

    for (int m = 0; m <= maxMinutes; m += tickStep) {
      final x = _minuteToX(m.toDouble(), size.width);
      final isLabel = m % labelStep == 0;
      final tickH = isLabel ? 7.0 : 3.5;

      canvas.drawLine(
        Offset(x, _rulerY - tickH),
        Offset(x, _rulerY),
        Paint()
          ..color = isLabel ? _tickLight : _tickDim
          ..strokeWidth = isLabel ? 1.2 : 0.8,
      );

      if (isLabel) {
        final time = _addMinutes(scheduledTime, m);
        final tp = TextPainter(
          text: TextSpan(
            text: _fmt(time),
            style: const TextStyle(
              color: _tickLight,
              fontSize: 9,
              fontFamily: 'Montserrat',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, _rulerY - tickH - 14));
      }
    }
  }

  void _drawActiveBar(Canvas canvas, Size size) {
    final startX = _minuteToX(0, size.width);
    final endX = _minuteToX(periodAfter.toDouble(), size.width);
    final rect = Rect.fromLTRB(startX, _barTop, endX, _barTop + _barHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    final gradient = LinearGradient(
      colors: [
        _accentColor.withValues(alpha: 0.25 + pulse * 0.05),
        _accentDeep.withValues(alpha: 0.12 + pulse * 0.03),
      ],
    ).createShader(rect);

    canvas.drawRRect(rrect, Paint()..shader = gradient);

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _accentColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawNotificationMarkers(Canvas canvas, Size size) {
    if (interval <= 0) return;

    // Adaptive marker size based on density
    final pxPerInterval =
        _minuteToX(interval.toDouble(), size.width) - _minuteToX(0, size.width);
    final dense = pxPerInterval < 20;
    final veryDense = pxPerInterval < 10;

    int index = 0;
    for (int m = 0; m <= periodAfter; m += interval) {
      final x = _minuteToX(m.toDouble(), size.width);
      const cy = _barTop + _barHeight / 2;
      final isFirst = index == 0;

      if (!veryDense || index % 2 == 0 || isFirst) {
        canvas.drawLine(
          Offset(x, _rulerY),
          Offset(x, _barTop),
          Paint()
            ..color = _accentColor.withValues(alpha: 0.25)
            ..strokeWidth = 0.8,
        );
      }

      if (isFirst) {
        canvas.drawCircle(
          Offset(x, cy),
          9 + pulse * 2,
          Paint()..color = _accentColor.withValues(alpha: 0.08 + pulse * 0.06),
        );
      }

      final r = isFirst
          ? 7.0
          : dense
              ? 3.0
              : 5.5;

      canvas.drawCircle(
        Offset(x, cy),
        r,
        Paint()
          ..color =
              isFirst ? _accentColor : _accentColor.withValues(alpha: 0.55),
      );

      if (!dense) {
        _drawBellIcon(canvas, Offset(x, cy), r * 0.6);
      }

      index++;
    }
  }

  void _drawBellIcon(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = _bgDark
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx - size * 0.5, center.dy + size * 0.15);
    path.quadraticBezierTo(
      center.dx - size * 0.5,
      center.dy - size * 0.6,
      center.dx,
      center.dy - size * 0.7,
    );
    path.quadraticBezierTo(
      center.dx + size * 0.5,
      center.dy - size * 0.6,
      center.dx + size * 0.5,
      center.dy + size * 0.15,
    );
    path.close();
    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(center.dx - size * 0.6, center.dy + size * 0.15),
      Offset(center.dx + size * 0.6, center.dy + size * 0.15),
      paint..strokeWidth = size * 0.15,
    );

    canvas.drawCircle(
      Offset(center.dx, center.dy + size * 0.35),
      size * 0.15,
      paint,
    );
  }

  void _drawPeriodHandle(Canvas canvas, Size size) {
    final x = _minuteToX(periodAfter.toDouble(), size.width);
    const cy = _barTop + _barHeight / 2;
    final isActive = activeDrag == _DragTarget.period;
    final r = isActive ? 11.0 : 9.0;

    if (isActive) {
      canvas.drawCircle(
        Offset(x, cy),
        r + 6,
        Paint()..color = _accentColor.withValues(alpha: 0.15),
      );
    }

    canvas.drawCircle(Offset(x, cy), r, Paint()..color = _accentColor);
    canvas.drawCircle(Offset(x, cy), r - 2.5, Paint()..color = _bgDark);

    final arrowPaint = Paint()
      ..color = _accentColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(x - 2.5, cy - 2), Offset(x - 2.5, cy + 2), arrowPaint);
    canvas.drawLine(
        Offset(x + 2.5, cy - 2), Offset(x + 2.5, cy + 2), arrowPaint);

    if (isActive) {
      _drawTooltip(canvas, '${periodAfter}m', Offset(x, _barTop - 10),
          _accentColor);
    }
  }

  void _drawIntervalBracket(Canvas canvas, Size size) {
    if (interval <= 0 || interval >= periodAfter) return;

    final x0 = _minuteToX(0, size.width);
    final x1 = _minuteToX(interval.toDouble(), size.width);
    final isActive = activeDrag == _DragTarget.interval;

    final color =
        isActive ? _intervalColor : _intervalColor.withValues(alpha: 0.5);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    canvas.drawLine(
        Offset(x0, _bracketY), Offset(x1, _bracketY), linePaint);
    canvas.drawLine(
        Offset(x0, _bracketY - 3), Offset(x0, _bracketY + 3), linePaint);

    final handleR = isActive ? 7.0 : 5.0;

    if (isActive) {
      canvas.drawCircle(
        Offset(x1, _bracketY),
        handleR + 4,
        Paint()..color = _intervalColor.withValues(alpha: 0.15),
      );
    }

    canvas.drawCircle(
        Offset(x1, _bracketY), handleR, Paint()..color = _intervalColor);
    canvas.drawCircle(
        Offset(x1, _bracketY), handleR - 2, Paint()..color = _bgDark);

    final tp = TextPainter(
      text: TextSpan(
        text: '${interval}min interval',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          fontFamily: 'Montserrat',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelX = ((x0 + x1) / 2 - tp.width / 2)
        .clamp(padding, size.width - padding - tp.width);
    tp.paint(canvas, Offset(labelX, _bracketY + 6));

    if (isActive) {
      _drawTooltip(
          canvas, '${interval}m', Offset(x1, _bracketY - 14), _intervalColor);
    }
  }

  void _drawTooltip(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Montserrat',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 10,
        height: 16,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(bgRect, Paint()..color = _bgDark);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - 8));
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) {
    return old.periodAfter != periodAfter ||
        old.interval != interval ||
        old.activeDrag != activeDrag ||
        old.pulse != pulse ||
        old.scheduledTime != scheduledTime ||
        old.maxMinutes != maxMinutes ||
        old.notificationCount != notificationCount;
  }
}
