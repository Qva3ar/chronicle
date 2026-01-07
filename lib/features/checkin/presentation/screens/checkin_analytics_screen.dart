import 'package:chrono/colors.dart';
import 'package:chrono/features/checkin/data/constants/evening_metrics.dart';
import 'package:chrono/features/checkin/data/constants/morning_metrics.dart';
import 'package:chrono/features/checkin/data/models/checkin_type.dart';
import 'package:chrono/features/checkin/data/repositories/checkin_repository.dart';
import 'package:chrono/features/checkin/presentation/widgets/checkin_dialog.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CheckinAnalyticsScreen extends StatefulWidget {
  const CheckinAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<CheckinAnalyticsScreen> createState() => _CheckinAnalyticsScreenState();
}

class _CheckinAnalyticsScreenState extends State<CheckinAnalyticsScreen> {
  final CheckinRepository _repository = CheckinRepository();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  CheckinType _selectedType = CheckinType.morning;
  String? _selectedMetricKey;

  List<Map<String, dynamic>> _checkins = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMetricKey = MorningMetrics.all.first.key;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _repository.getCheckins(
        startDate: _startDate.subtract(Duration(days: 1)), // Include start date fully
        endDate: _endDate.add(Duration(days: 1)), // Include end date fully
        type: _selectedType,
      );

      // Sort by date
      data.sort((a, b) => (a['created_at'] as int).compareTo(b['created_at'] as int));

      setState(() {
        _checkins = data;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTypeChanged(CheckinType? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      // Reset metric key to first availability of new type
      final metrics = type == CheckinType.morning ? MorningMetrics.all : EveningMetrics.all;
      if (metrics.isNotEmpty) {
        _selectedMetricKey = metrics.first.key;
      } else {
        _selectedMetricKey = null;
      }
    });
    _loadData();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: MyColors.primaryColor,
              onPrimary: Colors.white,
              surface: bgColor,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: bgColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  List<FlSpot> _getChartData() {
    if (_selectedMetricKey == null) return [];

    final spots = <FlSpot>[];
    final metrics = _selectedType == CheckinType.morning ? MorningMetrics.all : EveningMetrics.all;

    // Find metric definition to check if we can parse the value
    // (though validation happens at parsing time mostly)

    // Parse values from checkins
    int index = 0;
    for (final checkin in _checkins) {
      final text = checkin['text'] as String;

      final values = _repository.parseCheckinValues(text, metrics);

      if (values.containsKey(_selectedMetricKey)) {
        final value = values[_selectedMetricKey]!;
        // Use index as X for simple sequential plotting,
        // or we could use milliseconds for X axis if we want time-scaled
        // Let's use index 0..N for now to space them evenly
        spots.add(FlSpot(index.toDouble(), value.toDouble()));
      }
      index++;
    }
    return spots;
  }

  // Get date labels for X axis
  String _getDateLabel(double value) {
    if (value < 0 || value >= _checkins.length) return '';
    final index = value.toInt();
    final checkin = _checkins[index];
    final date = DateTime.fromMillisecondsSinceEpoch(checkin['created_at'] as int);
    return DateFormat('dd.MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _selectedType == CheckinType.morning ? MorningMetrics.all : EveningMetrics.all;
    final spots = _getChartData();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Analytics", style: TextStyle(color: Colors.white70)),
        backgroundColor: MyColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // checkin buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      CheckinDialog.show(context, CheckinType.morning).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: const Text("Morning Check-in"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.orangeDivider,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      CheckinDialog.show(context, CheckinType.evening).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.nightlight_round),
                    label: const Text("Evening Check-in"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Controls row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Type Toggle
                  SegmentedButton<CheckinType>(
                    segments: const [
                      ButtonSegment(value: CheckinType.morning, label: Text("Morning")),
                      ButtonSegment(value: CheckinType.evening, label: Text("Evening")),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<CheckinType> newSelection) {
                      _onTypeChanged(newSelection.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.selected)) {
                          return MyColors.orangeDivider;
                        }
                        return cardColor;
                      }),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                      side: MaterialStateProperty.all(BorderSide(color: Colors.grey.shade800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date Range
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                    label: Text(
                      "${DateFormat('dd.MM').format(_startDate)} - ${DateFormat('dd.MM').format(_endDate)}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Metric Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMetricKey,
                  isExpanded: true,
                  dropdownColor: cardColor,
                  style: const TextStyle(color: Colors.white),
                  items: metrics.map((m) {
                    return DropdownMenuItem<String>(
                      value: m.key,
                      child: Text(m.label, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMetricKey = value;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Chart
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : spots.isEmpty
                      ? const Center(
                          child: Text("No data for selected period",
                              style: TextStyle(color: Colors.grey)))
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              getDrawingHorizontalLine: (value) =>
                                  FlLine(color: Colors.white10, strokeWidth: 1),
                              getDrawingVerticalLine: (value) =>
                                  FlLine(color: Colors.white10, strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles:
                                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles:
                                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    // Show valid dates
                                    if (value % 1 != 0) return Container();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        _getDateLabel(value),
                                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Colors.white10),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: MyColors.orangeDivider,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: MyColors.orangeDivider.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}




