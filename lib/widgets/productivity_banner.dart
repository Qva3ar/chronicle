import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:chrono/services/daily_reset_service.dart';

/// Compact circular progress indicator showing the productivity index.
/// Designed to be placed to the right of the search bar.
class ProductivityBanner extends StatefulWidget {
  final VoidCallback? onTap;

  const ProductivityBanner({super.key, this.onTap});

  @override
  State<ProductivityBanner> createState() => _ProductivityBannerState();
}

class _ProductivityBannerState extends State<ProductivityBanner>
    with WidgetsBindingObserver {
  ProductivityScore? _currentScore;
  bool _loading = true;
  Timer? _refreshTimer;
  StreamSubscription<void>? _resetSubscription;
  StreamSubscription<ProductivityScore>? _scoreUpdatedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    _resetSubscription = DailyResetService.instance.onResetComplete.listen((_) => _load());
    _scoreUpdatedSubscription =
        ProductivityService.instance.onProductivityScoreUpdated.listen((score) {
      // The banner only ever shows TODAY. Editing/backdating a past day also
      // emits on this stream with that day's date — ignore it, otherwise the
      // banner briefly shows the past day's score until the next _load() reverts it.
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (score.date != todayStr) return;
      if (mounted) setState(() => _currentScore = score);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _resetSubscription?.cancel();
    _scoreUpdatedSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recalculate immediately when app returns from background.
      // Background isolate may have updated the DB (e.g. routine marked done
      // via notification action) but the in-memory stream doesn't cross
      // isolate boundaries, so the banner would stay stale until the next
      // periodic timer tick.
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final score = await ProductivityService.instance.calculateCurrentScore();
      if (mounted) {
        setState(() {
          _currentScore = score;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 44, height: 44);
    if (_currentScore == null || _currentScore!.totalWeight == 0) {
      return const SizedBox.shrink();
    }

    final score = _currentScore!.score;
    final color = _scoreColor(score);

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: score / 10,
                strokeWidth: 3,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
