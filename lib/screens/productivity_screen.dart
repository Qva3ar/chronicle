import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  int? _selectedDayIndex;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.primaryColor,
      appBar: AppBar(
        backgroundColor: MyColors.primaryColor,
        title: const Text('Продуктивность', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentScoreCard(),
                  const SizedBox(height: 20),
                  _buildRangeSelector(),
                  const SizedBox(height: 16),
                  _buildChart(),
                  const SizedBox(height: 16),
                  _buildAverageCard(),
                  const SizedBox(height: 16),
                  _buildHistoryList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentScoreCard() {
    if (_currentScore == null || _currentScore!.totalWeight == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Нет активных рутин и целей на сегодня',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final score = _currentScore!;
    final color = _scoreColor(score.score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Сегодня',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: score.score / 10,
                    strokeWidth: 6,
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
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'из 10',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatChip(
                Icons.check_circle_outline,
                '${score.routinesDone}/${score.routinesTotal}',
                'рутин',
              ),
              _buildStatChip(
                Icons.flag_outlined,
                '${(score.goalsProgress * 100).round()}%',
                'цели',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Row(
      children: [
        for (final range in _DateRange.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(_rangeLabel(range)),
                selected: _range == range,
                onSelected: (_) {
                  setState(() {
                    _range = range;
                    _selectedDayIndex = null;
                  });
                },
                selectedColor: MyColors.trecondaryColor,
                backgroundColor: cardColor2,
                labelStyle: TextStyle(
                  color: _range == range ? Colors.white : Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _rangeLabel(_DateRange range) {
    switch (range) {
      case _DateRange.week:
        return 'Неделя';
      case _DateRange.month:
        return 'Месяц';
      case _DateRange.all:
        return 'Всё время';
    }
  }

  Widget _buildChart() {
    final data = _filteredHistory;
    if (data.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: cardColor2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Пока нет данных за этот период',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].score));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2.5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white10,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 2.5,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == 5 || value == 10) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _bottomInterval(data.length),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                  final date = DateTime.tryParse(data[idx].date);
                  if (date == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('dd.MM').format(date),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 10,
          lineTouchData: LineTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                setState(() {
                  _selectedDayIndex = response.lineBarSpots!.first.spotIndex;
                });
              }
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.spotIndex;
                  if (idx < data.length) {
                    final s = data[idx];
                    return LineTooltipItem(
                      '${s.score.toStringAsFixed(1)}/10\n${s.routinesDone}/${s.routinesTotal} рутин',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: Colors.greenAccent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = index == _selectedDayIndex;
                  return FlDotCirclePainter(
                    radius: isSelected ? 5 : 3,
                    color: isSelected ? Colors.greenAccent : Colors.greenAccent.withValues(alpha: 0.6),
                    strokeWidth: isSelected ? 2 : 0,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.greenAccent.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return (count / 6).ceilToDouble();
  }

  Widget _buildAverageCard() {
    final avg = _averageScore;
    final data = _filteredHistory;
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_outlined, color: _scoreColor(avg), size: 24),
          const SizedBox(width: 12),
          Text(
            'Средний балл: ${avg.toStringAsFixed(1)}/10',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '${data.length} дн.',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final data = _filteredHistory.reversed.toList();
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'История',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  '${score.routinesDone}/${score.routinesTotal} рутин  •  Цели ${(score.goalsProgress * 100).round()}%',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            score.score.toStringAsFixed(1),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
