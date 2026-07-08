import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:chrono/screens/productivity_history_screen.dart';

enum _DateRange { week, month, all }

class ProductivityScreen extends StatefulWidget {
  const ProductivityScreen({super.key});

  @override
  State<ProductivityScreen> createState() => _ProductivityScreenState();
}

class _ProductivityScreenState extends State<ProductivityScreen> {
  ProductivityScore? _currentScore;
  List<ProductivityScore> _history = [];
  bool _loading = true;
  _DateRange _range = _DateRange.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final current = await ProductivityService.instance.calculateCurrentScore();
      final history = await ProductivityService.instance.getHistory(days: 0);
      if (mounted) {
        setState(() {
          _currentScore = current;
          _history = history;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _scoreColor(double score) {
    if (score >= 7) return Colors.greenAccent;
    if (score >= 4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ── Streak calculation ──

  static const double _streakThreshold = 7.0;

  int get _currentStreak {
    if (_history.isEmpty) return 0;
    int streak = 0;
    for (int i = _history.length - 1; i >= 0; i--) {
      if (_history[i].score >= _streakThreshold) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int get _bestStreak {
    if (_history.isEmpty) return 0;
    int best = 0;
    int current = 0;
    for (final s in _history) {
      if (s.score >= _streakThreshold) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  // ── Aggregations for insights ──

  double _avgOf(List<ProductivityScore> list) => list.isEmpty
      ? 0
      : list.map((s) => s.score).reduce((a, b) => a + b) / list.length;

  List<ProductivityScore> get _filteredHistory {
    if (_history.isEmpty) return [];
    final now = DateTime.now();
    switch (_range) {
      case _DateRange.week:
        final cutoff = now.subtract(const Duration(days: 7));
        return _history.where((s) {
          final d = DateTime.tryParse(s.date);
          return d != null && d.isAfter(cutoff);
        }).toList();
      case _DateRange.month:
        final cutoff = now.subtract(const Duration(days: 30));
        return _history.where((s) {
          final d = DateTime.tryParse(s.date);
          return d != null && d.isAfter(cutoff);
        }).toList();
      case _DateRange.all:
        return _history;
    }
  }

  String _rangeLabel(_DateRange range) {
    switch (range) {
      case _DateRange.week:
        return 'Week';
      case _DateRange.month:
        return 'Month';
      case _DateRange.all:
        return 'All time';
    }
  }

  /// Converts the filtered history into chart bars, aggregating days into
  /// buckets when there are too many to render individually. This keeps the
  /// "All time" view usable no matter how many days are tracked.
  List<_ChartBar> _chartBars() {
    final data = _filteredHistory;
    if (data.isEmpty) return const [];

    const maxBars = 35;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (data.length <= maxBars) {
      return data.map((s) {
        final d = DateTime.tryParse(s.date);
        final label = d != null ? DateFormat('E').format(d).substring(0, 2) : '';
        return _ChartBar(
          score: s.score,
          label: label,
          isToday: s.date == todayStr,
        );
      }).toList();
    }

    // Too many points: aggregate consecutive days into averaged buckets.
    final groupSize = (data.length / maxBars).ceil();
    final bars = <_ChartBar>[];
    for (int i = 0; i < data.length; i += groupSize) {
      final end = (i + groupSize) > data.length ? data.length : (i + groupSize);
      final group = data.sublist(i, end);
      final first = DateTime.tryParse(group.first.date);
      final label = first != null ? DateFormat('d/M').format(first) : '';
      bars.add(_ChartBar(
        score: _avgOf(group),
        label: label,
        isToday: group.any((s) => s.date == todayStr),
      ));
    }
    return bars;
  }

  Map<int, double> get _weekdayAverages {
    final sums = <int, double>{};
    final counts = <int, int>{};
    for (final s in _history) {
      final d = DateTime.tryParse(s.date);
      if (d == null) continue;
      final wd = d.weekday; // 1=Mon, 7=Sun
      sums[wd] = (sums[wd] ?? 0) + s.score;
      counts[wd] = (counts[wd] ?? 0) + 1;
    }
    final avgs = <int, double>{};
    for (final wd in sums.keys) {
      avgs[wd] = sums[wd]! / counts[wd]!;
    }
    return avgs;
  }

  /// Builds up to two human-readable insights from the history, prioritising the
  /// most actionable ones (trend > best weekday > overall average).
  List<_Insight> get _insights {
    final out = <_Insight>[];
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    // 1. Week-over-week trend
    if (_history.length >= 4) {
      final last = _history.length >= 7
          ? _history.sublist(_history.length - 7)
          : _history;
      final prevEnd = _history.length - last.length;
      if (prevEnd > 0) {
        final prevStart = (prevEnd - 7).clamp(0, prevEnd);
        final prev = _history.sublist(prevStart, prevEnd);
        if (prev.isNotEmpty) {
          final delta = _avgOf(last) - _avgOf(prev);
          if (delta.abs() >= 0.2) {
            final up = delta >= 0;
            out.add(_Insight(
              icon: up ? Icons.trending_up : Icons.trending_down,
              color: up ? successColor : Colors.redAccent,
              headline: up ? 'You\'re trending up' : 'Slipping a little',
              subtext:
                  '${up ? '+' : ''}${delta.toStringAsFixed(1)} avg vs the previous week',
            ));
          }
        }
      }
    }

    // 2. Best weekday
    final wd = _weekdayAverages;
    if (wd.length >= 3) {
      final best = wd.entries.reduce((a, b) => a.value >= b.value ? a : b);
      out.add(_Insight(
        icon: Icons.star_rounded,
        color: MyColors.orangeDivider,
        headline: '${dayNames[best.key - 1]}s are your strongest',
        subtext: '${best.value.toStringAsFixed(1)} average on that day',
      ));
    }

    // 3. Fallback: overall average
    if (out.isEmpty && _history.isNotEmpty) {
      final recent = _history.length > 30
          ? _history.sublist(_history.length - 30)
          : _history;
      final avg = _avgOf(recent);
      out.add(_Insight(
        icon: Icons.analytics_rounded,
        color: _scoreColor(avg),
        headline: '${avg.toStringAsFixed(1)} average score',
        subtext: 'Across the last ${recent.length} tracked day${recent.length != 1 ? 's' : ''}',
      ));
    }

    return out.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Productivity',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MyColors.orangeDivider))
          : RefreshIndicator(
              onRefresh: _load,
              color: MyColors.orangeDivider,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreCircle(),
                    const SizedBox(height: 16),
                    _buildStreakRow(),
                    const SizedBox(height: 16),
                    _buildBreakdown(),
                    const SizedBox(height: 16),
                    _buildInsightCard(),
                    _buildChartCard(),
                    _buildHeatmapCard(),
                    _buildHistoryButton(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Score circle ──

  Widget _buildScoreCircle() {
    if (_currentScore == null || _currentScore!.totalWeight == 0) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No active routines or goals today',
              style: TextStyle(color: textMuted),
            ),
          ),
        ),
      );
    }

    final score = _currentScore!;
    final color = _scoreColor(score.score);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CircularProgressIndicator(
                  value: score.score / 10,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.score.toStringAsFixed(1),
                    style: TextStyle(
                      color: color,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'out of 10',
                    style: TextStyle(
                      color: textMuted.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Streak row ──

  Widget _buildStreakRow() {
    final current = _currentStreak;
    final best = _bestStreak;
    if (best == 0) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: current > 0 ? warningColor : textHint, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$current day${current != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: current > 0 ? warningColor : textMuted,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text('current streak',
                            style: TextStyle(color: textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: MyColors.orangeDivider, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$best day${best != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: MyColors.orangeDivider,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text('best streak',
                            style: TextStyle(color: textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Breakdown rows ──

  Widget _buildBreakdown() {
    if (_currentScore == null || _currentScore!.totalWeight == 0) {
      return const SizedBox.shrink();
    }
    final score = _currentScore!;
    final routineProgress = score.routinesTotal > 0
        ? score.routinesDone / score.routinesTotal
        : 0.0;

    return Column(
      children: [
        _BreakdownRow(
          title: 'Routines completed',
          value: '${score.routinesDone} / ${score.routinesTotal}',
          progress: routineProgress,
          color: const Color(0xFF66BB6A),
        ),
        const SizedBox(height: 8),
        _BreakdownRow(
          title: 'Goal progress',
          value: '${(score.goalsProgress * 100).round()}%',
          progress: score.goalsProgress.clamp(0.0, 1.0),
          color: const Color(0xFF42A5F5),
        ),
      ],
    );
  }

  // ── Insight card ──

  Widget _buildInsightCard() {
    final insights = _insights;
    if (insights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          children: [
            for (int i = 0; i < insights.length; i++) ...[
              if (i > 0)
                Divider(
                  color: cardBorder.withValues(alpha: 0.3),
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                ),
              _insightRow(insights[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _insightRow(_Insight insight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(insight.icon, color: insight.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.headline,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.subtext,
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Trend chart (with range selector) ──

  Widget _buildChartCard() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          _buildRangeSelector(),
          const SizedBox(height: 12),
          _card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
              child: _buildBarChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _DateRange.values.map((range) {
          final isActive = _range == range;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _range = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? cardColor2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _rangeLabel(range),
                    style: TextStyle(
                      color: isActive ? textPrimary : textMuted,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart() {
    final bars = _chartBars();
    if (bars.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'No data for this period yet',
            style: TextStyle(color: textMuted),
          ),
        ),
      );
    }

    const chartHeight = 130.0;
    // Keep at most ~7 labels so they never collide, regardless of bar count.
    final showEvery = (bars.length / 7).ceil().clamp(1, bars.length);
    final gap = bars.length > 20 ? 0.75 : (bars.length > 10 ? 1.5 : 3.0);

    return SizedBox(
      height: chartHeight + 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < bars.length; i++)
            _BarColumn(
              bar: bars[i],
              maxHeight: chartHeight,
              gap: gap,
              showLabel: i % showEvery == 0 || i == bars.length - 1,
            ),
        ],
      ),
    );
  }

  // ── Heatmap ──

  Widget _buildHeatmapCard() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _ProductivityHeatmap(
                history: _history,
                onTapDay: _showDayDetail,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayDetail(ProductivityScore score) {
    final date = DateTime.tryParse(score.date);
    final dateStr =
        date != null ? DateFormat('EEEE, dd MMM').format(date) : score.date;
    final color = _scoreColor(score.score);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      score.score.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder<ProductivityScore>(
                future: ProductivityService.instance.recalculateForDate(score.date),
                builder: (c, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(18, 4, 18, 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final detail = snap.data ?? score;
                  return productivityDayBreakdown(detail);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── History button ──

  Widget _buildHistoryButton() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductivityHistoryScreen(history: _history),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: textMuted, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'View full history',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${_history.length} day${_history.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: textHint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Insight model
// ═══════════════════════════════════════════════════════════════════════════

class _Insight {
  final IconData icon;
  final Color color;
  final String headline;
  final String subtext;

  const _Insight({
    required this.icon,
    required this.color,
    required this.headline,
    required this.subtext,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Trend chart bar
// ═══════════════════════════════════════════════════════════════════════════

class _ChartBar {
  final double score;
  final String label;
  final bool isToday;

  const _ChartBar({
    required this.score,
    required this.label,
    this.isToday = false,
  });
}

class _BarColumn extends StatelessWidget {
  final _ChartBar bar;
  final double maxHeight;
  final double gap;
  final bool showLabel;

  const _BarColumn({
    required this.bar,
    required this.maxHeight,
    required this.gap,
    required this.showLabel,
  });

  Color _barColor(double s) {
    if (s >= 7) return Colors.greenAccent;
    if (s >= 4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor(bar.score);
    final barHeight = ((bar.score / 10) * maxHeight).clamp(2.0, maxHeight);

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gap),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: double.infinity,
              height: barHeight,
              decoration: BoxDecoration(
                color: bar.isToday ? color : color.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
                border: bar.isToday ? Border.all(color: color, width: 1.5) : null,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 14,
              child: showLabel
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        bar.label,
                        style: TextStyle(
                          color: bar.isToday ? textPrimary : textMuted,
                          fontSize: 10,
                          fontWeight:
                              bar.isToday ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Breakdown Row
// ═══════════════════════════════════════════════════════════════════════════

class _BreakdownRow extends StatelessWidget {
  final String title;
  final String value;
  final double progress;
  final Color color;

  const _BreakdownRow({
    required this.title,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Heatmap (GitHub-style contribution grid)
// ═══════════════════════════════════════════════════════════════════════════

class _ProductivityHeatmap extends StatelessWidget {
  final List<ProductivityScore> history;
  final void Function(ProductivityScore) onTapDay;

  const _ProductivityHeatmap({
    required this.history,
    required this.onTapDay,
  });

  static const int _weeksToShow = 15;

  Color _cellColor(double score) {
    if (score >= 7) return const Color(0xFF66BB6A);
    if (score >= 4) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final scoreByDate = <String, ProductivityScore>{
      for (final s in history) s.date: s,
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final todayIdx = today.weekday - 1; // 0=Mon
    final lastMonday = today.subtract(Duration(days: todayIdx));
    final firstMonday =
        lastMonday.subtract(const Duration(days: (_weeksToShow - 1) * 7));

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        const leftLabel = 22.0;
        final avail = constraints.maxWidth - leftLabel;
        final cell = (avail / _weeksToShow - gap).clamp(8.0, 18.0).toDouble();
        final rowHeight = cell + gap;

        // Month labels aligned to the first column of each month.
        final monthLabels = <Widget>[const SizedBox(width: leftLabel)];
        int? prevMonth;
        for (int w = 0; w < _weeksToShow; w++) {
          final colDate = firstMonday.add(Duration(days: w * 7));
          final showLabel = prevMonth != colDate.month;
          prevMonth = colDate.month;
          monthLabels.add(SizedBox(
            width: cell + gap,
            child: showLabel
                ? Text(
                    DateFormat('MMM').format(colDate),
                    style: const TextStyle(color: textMuted, fontSize: 9),
                  )
                : const SizedBox.shrink(),
          ));
        }

        // Weekday labels column (Mon / Wed / Fri).
        const wdLabels = ['Mon', '', 'Wed', '', 'Fri', '', ''];
        final weekdayColumn = SizedBox(
          width: leftLabel,
          child: Column(
            children: List.generate(7, (d) {
              return SizedBox(
                height: rowHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    wdLabels[d],
                    style: const TextStyle(color: textMuted, fontSize: 8),
                  ),
                ),
              );
            }),
          ),
        );

        final weekColumns = <Widget>[weekdayColumn];
        for (int w = 0; w < _weeksToShow; w++) {
          weekColumns.add(Padding(
            padding: const EdgeInsets.only(right: gap),
            child: Column(
              children: List.generate(7, (d) {
                final date = firstMonday.add(Duration(days: w * 7 + d));
                return Padding(
                  padding: const EdgeInsets.only(bottom: gap),
                  child: _buildCell(date, today, todayStr, scoreByDate, cell),
                );
              }),
            ),
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: monthLabels),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekColumns,
            ),
            const SizedBox(height: 12),
            _buildLegend(),
          ],
        );
      },
    );
  }

  Widget _buildCell(
    DateTime date,
    DateTime today,
    String todayStr,
    Map<String, ProductivityScore> scoreByDate,
    double cell,
  ) {
    if (date.isAfter(today)) {
      return SizedBox(width: cell, height: cell);
    }
    final ds = DateFormat('yyyy-MM-dd').format(date);
    final score = scoreByDate[ds];
    final color = score != null
        ? _cellColor(score.score)
        : Colors.white.withValues(alpha: 0.05);

    final box = Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: ds == todayStr
            ? Border.all(color: textPrimary, width: 1)
            : null,
      ),
    );

    if (score == null) return box;
    return GestureDetector(
      onTap: () => onTapDay(score),
      child: box,
    );
  }

  Widget _buildLegend() {
    Widget swatch(Color c) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    return Row(
      children: [
        const Text('Low', style: TextStyle(color: textMuted, fontSize: 10)),
        const SizedBox(width: 6),
        swatch(const Color(0xFFEF5350)),
        const SizedBox(width: 3),
        swatch(const Color(0xFFFFA726)),
        const SizedBox(width: 3),
        swatch(const Color(0xFF66BB6A)),
        const SizedBox(width: 6),
        const Text('High', style: TextStyle(color: textMuted, fontSize: 10)),
      ],
    );
  }
}
