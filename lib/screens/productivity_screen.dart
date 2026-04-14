import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/services/productivity_service.dart';

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

  double get _averageScore {
    final data = _filteredHistory;
    if (data.isEmpty) return 0;
    return data.map((s) => s.score).reduce((a, b) => a + b) / data.length;
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
    // Walk backwards from most recent
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

  // ── Trend calculation ──

  double? get _trendDelta {
    final data = _filteredHistory;
    if (data.length < 2) return null;

    int halfLen;
    switch (_range) {
      case _DateRange.week:
        halfLen = 7;
      case _DateRange.month:
        halfLen = 15;
      case _DateRange.all:
        halfLen = (data.length / 2).ceil();
    }

    // Current period = last N entries, previous = the N before that
    final currentPeriod = data.length > halfLen
        ? data.sublist(data.length - halfLen)
        : data;

    final previousEnd = data.length - currentPeriod.length;
    if (previousEnd <= 0) return null;

    final previousPeriod = data.sublist(
      (previousEnd - halfLen).clamp(0, previousEnd),
      previousEnd,
    );

    if (previousPeriod.isEmpty) return null;

    final currentAvg =
        currentPeriod.map((s) => s.score).reduce((a, b) => a + b) / currentPeriod.length;
    final previousAvg =
        previousPeriod.map((s) => s.score).reduce((a, b) => a + b) / previousPeriod.length;

    return currentAvg - previousAvg;
  }

  // ── Weekday averages ──

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
                    const SizedBox(height: 20),
                    _buildRangeSelector(),
                    const SizedBox(height: 12),
                    _buildTrendCard(),
                    const SizedBox(height: 12),
                    _buildBarChart(),
                    const SizedBox(height: 12),
                    _buildAverageCard(),
                    const SizedBox(height: 16),
                    _buildWeekdayPatterns(),
                    const SizedBox(height: 20),
                    _buildHistoryList(),
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
                  Icon(Icons.emoji_events_outlined,
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

  // ── Range selector ──

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

  // ── Trend card ──

  Widget _buildTrendCard() {
    final delta = _trendDelta;
    if (delta == null) return const SizedBox.shrink();

    final isUp = delta >= 0;
    final color = isUp ? Colors.greenAccent : Colors.redAccent;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;
    final avg = _averageScore;
    final periodLabel = _range == _DateRange.week
        ? 'vs last week'
        : _range == _DateRange.month
            ? 'vs previous month'
            : 'vs first half';

    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${avg.toStringAsFixed(1)} avg',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    periodLabel,
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bar chart ──

  Widget _buildBarChart() {
    final data = _filteredHistory;
    if (data.isEmpty) {
      return _card(
        child: const SizedBox(
          height: 160,
          child: Center(
            child: Text(
              'No data for this period yet',
              style: TextStyle(color: textMuted),
            ),
          ),
        ),
      );
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return _card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: SizedBox(
          height: _barChartHeight(data.length),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((s) {
              final isToday = s.date == todayStr;
              return Expanded(
                child: _BarColumn(
                  score: s,
                  isToday: isToday,
                  maxHeight: _barChartHeight(data.length) - 24,
                  showLabel: _shouldShowLabel(data, s),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  double _barChartHeight(int count) {
    if (count <= 7) return 140;
    if (count <= 14) return 140;
    return 160;
  }

  bool _shouldShowLabel(List<ProductivityScore> data, ProductivityScore s) {
    final count = data.length;
    final idx = data.indexOf(s);
    if (count <= 7) return true;
    if (count <= 14) return idx % 2 == 0 || idx == count - 1;
    if (count <= 31) return idx % 5 == 0 || idx == count - 1;
    return idx % 7 == 0 || idx == count - 1;
  }

  // ── Average card ──

  Widget _buildAverageCard() {
    final avg = _averageScore;
    final data = _filteredHistory;
    if (data.isEmpty) return const SizedBox.shrink();

    final color = _scoreColor(avg);

    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.analytics_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Average score',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data.length} day${data.length != 1 ? 's' : ''} tracked',
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              avg.toStringAsFixed(1),
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Weekday patterns ──

  Widget _buildWeekdayPatterns() {
    final avgs = _weekdayAverages;
    if (avgs.length < 3) return const SizedBox.shrink(); // need at least 3 days of data

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = avgs.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxAvg = sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'By weekday',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: sorted.map((entry) {
                final wd = entry.key;
                final avg = entry.value;
                final color = _scoreColor(avg);
                final ratio = maxAvg > 0 ? avg / 10 : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          dayNames[wd - 1],
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              color.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 32,
                        child: Text(
                          avg.toStringAsFixed(1),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── History list ──

  Widget _buildHistoryList() {
    final data = _filteredHistory.reversed.toList();
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'History',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...data.take(30).map((s) => _buildDayTile(s)),
      ],
    );
  }

  Widget _buildDayTile(ProductivityScore score) {
    final date = DateTime.tryParse(score.date);
    final dateStr = date != null ? DateFormat('dd MMM, EEE').format(date) : score.date;
    final color = _scoreColor(score.score);
    final routineProgress = score.routinesTotal > 0
        ? score.routinesDone / score.routinesTotal
        : 0.0;
    final hasDetails =
        score.routineDetails.isNotEmpty || score.goalDetails.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            trailing: const SizedBox.shrink(),
            title: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 4, color: color.withValues(alpha: 0.7)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (hasDetails) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.expand_more, size: 16, color: textHint),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _MiniStat(
                                      icon: Icons.check_circle_outline,
                                      text: '${score.routinesDone}/${score.routinesTotal}',
                                      color: const Color(0xFF66BB6A),
                                      progress: routineProgress,
                                    ),
                                    const SizedBox(width: 16),
                                    _MiniStat(
                                      icon: Icons.flag_outlined,
                                      text: '${(score.goalsProgress * 100).round()}%',
                                      color: const Color(0xFF42A5F5),
                                      progress: score.goalsProgress.clamp(0.0, 1.0),
                                    ),
                                  ],
                                ),
                              ],
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
                  ),
                ],
              ),
            ),
            children: hasDetails
                ? [_buildDayDetails(score)]
                : [],
          ),
        ),
      ),
    );
  }

  Widget _buildDayDetails(ProductivityScore score) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: cardBorder.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 10),
          if (score.routineDetails.isNotEmpty) ...[
            const Text('Routines',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...score.routineDetails.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        r.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: r.completed ? const Color(0xFF66BB6A) : textHint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.name,
                          style: TextStyle(
                            color: r.completed ? textPrimary : textMuted,
                            fontSize: 13,
                            decoration: r.completed ? null : TextDecoration.lineThrough,
                            decorationColor: textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (score.goalDetails.isNotEmpty) ...[
            if (score.routineDetails.isNotEmpty) const SizedBox(height: 10),
            const Text('Goals',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...score.goalDetails.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: g.progress.clamp(0.0, 1.0),
                          strokeWidth: 2.5,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            g.progress >= 1.0
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFF42A5F5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.name,
                          style: const TextStyle(color: textPrimary, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${(g.progress * 100).round()}%',
                        style: TextStyle(
                          color: g.progress >= 1.0
                              ? const Color(0xFF66BB6A)
                              : const Color(0xFF42A5F5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
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
          // Mini circular indicator
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
// Bar Column (chart)
// ═══════════════════════════════════════════════════════════════════════════

class _BarColumn extends StatelessWidget {
  final ProductivityScore score;
  final bool isToday;
  final double maxHeight;
  final bool showLabel;

  const _BarColumn({
    required this.score,
    required this.isToday,
    required this.maxHeight,
    required this.showLabel,
  });

  Color _barColor(double s) {
    if (s >= 7) return Colors.greenAccent;
    if (s >= 4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor(score.score);
    final barHeight = (score.score / 10) * maxHeight;
    final date = DateTime.tryParse(score.date);
    final label = date != null ? DateFormat('E').format(date).substring(0, 2) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 16,
            height: barHeight.clamp(2.0, maxHeight),
            decoration: BoxDecoration(
              color: isToday ? color : color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
              border: isToday
                  ? Border.all(color: color, width: 1.5)
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: showLabel
                ? Text(
                    label,
                    style: TextStyle(
                      color: isToday ? textPrimary : textMuted,
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Mini stat (for history tiles)
// ═══════════════════════════════════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final double progress;

  const _MiniStat({
    required this.icon,
    required this.text,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            strokeCap: StrokeCap.round,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
