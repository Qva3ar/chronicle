import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/services/productivity_service.dart';

Color productivityScoreColor(double score) {
  if (score >= 7) return Colors.greenAccent;
  if (score >= 4) return Colors.orangeAccent;
  return Colors.redAccent;
}

/// Shared routines/goals breakdown for a single day. Used by both the history
/// tiles and the heatmap day-detail bottom sheet.
Widget productivityDayBreakdown(BuildContext context, ProductivityScore score) {
  if (score.routineDetails.isEmpty && score.goalDetails.isEmpty) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Text(
        AppLocalizations.of(context).productivityNoBreakdown,
        style: const TextStyle(color: textHint, fontSize: 12),
      ),
    );
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (score.routineDetails.isNotEmpty) ...[
          Text(AppLocalizations.of(context).navRoutines,
              style: const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
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
          Text(AppLocalizations.of(context).navGoals,
              style: const TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
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

class ProductivityHistoryScreen extends StatefulWidget {
  final List<ProductivityScore> history;

  const ProductivityHistoryScreen({super.key, required this.history});

  @override
  State<ProductivityHistoryScreen> createState() => _ProductivityHistoryScreenState();
}

class _ProductivityHistoryScreenState extends State<ProductivityHistoryScreen> {
  final Map<String, ProductivityScore> _detailsCache = {};
  final Set<String> _detailsLoading = {};

  Future<void> _loadDetails(String date) async {
    if (_detailsCache.containsKey(date) || _detailsLoading.contains(date)) {
      return;
    }
    _detailsLoading.add(date);
    try {
      final detail = await ProductivityService.instance.recalculateForDate(date);
      if (mounted) setState(() => _detailsCache[date] = detail);
    } catch (_) {
      // Leave uncached so it can be retried on next expansion.
    } finally {
      _detailsLoading.remove(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.history.reversed.toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppLocalizations.of(context).productivityHistory,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      body: data.isEmpty
          ? Center(
              child: Text(AppLocalizations.of(context).productivityNoHistory,
                  style: const TextStyle(color: textMuted)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: data.length,
              itemBuilder: (context, i) => _buildDayTile(data[i]),
            ),
    );
  }

  Widget _buildDayTile(ProductivityScore score) {
    final date = DateTime.tryParse(score.date);
    final dateStr = date != null ? DateFormat('dd MMM, EEE').format(date) : score.date;
    final color = productivityScoreColor(score.score);
    final routineProgress =
        score.routinesTotal > 0 ? score.routinesDone / score.routinesTotal : 0.0;

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
            onExpansionChanged: (expanded) {
              if (expanded) _loadDetails(score.date);
            },
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
                                    const SizedBox(width: 6),
                                    const Icon(Icons.expand_more, size: 16, color: textHint),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _MiniStat(
                                      text: '${score.routinesDone}/${score.routinesTotal}',
                                      color: const Color(0xFF66BB6A),
                                      progress: routineProgress,
                                    ),
                                    const SizedBox(width: 16),
                                    _MiniStat(
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
            children: [_buildDayDetailsLazy(score.date)],
          ),
        ),
      ),
    );
  }

  Widget _buildDayDetailsLazy(String date) {
    final detail = _detailsCache[date];
    if (detail == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: cardBorder.withValues(alpha: 0.3),
          height: 1,
          indent: 18,
          endIndent: 18,
        ),
        const SizedBox(height: 10),
        productivityDayBreakdown(context, detail),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String text;
  final Color color;
  final double progress;

  const _MiniStat({
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
