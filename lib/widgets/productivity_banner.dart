import 'dart:async';
import 'package:flutter/material.dart';
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

class _ProductivityBannerState extends State<ProductivityBanner> {
  ProductivityScore? _currentScore;
  bool _loading = true;
  Timer? _refreshTimer;
  StreamSubscription<void>? _resetSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    _resetSubscription = DailyResetService.instance.onResetComplete.listen((_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _resetSubscription?.cancel();
    super.dispose();
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
