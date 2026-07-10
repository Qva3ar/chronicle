import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/widget_service.dart';
import 'package:chrono/colors.dart';

class InsightBanner extends StatefulWidget {
  const InsightBanner({super.key});

  @override
  State<InsightBanner> createState() => _InsightBannerState();
}

class _InsightBannerState extends State<InsightBanner> {
  Map<String, dynamic>? _insight;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      DatabaseTables.aiInsights,
      where:
          '${DatabaseColumns.insightExpiresAt} > ? AND (${DatabaseColumns.insightDismissedAt} IS NULL OR ${DatabaseColumns.insightDismissedAt} = 0)',
      whereArgs: [now],
      orderBy: '${DatabaseColumns.insightDeliveredAt} DESC',
      limit: 1,
    );
    if (!mounted) return;
    setState(() {
      _insight = rows.isNotEmpty ? rows.first : null;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    if (_insight == null) return;
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseTables.aiInsights,
      {DatabaseColumns.insightDismissedAt: DateTime.now().millisecondsSinceEpoch},
      where: '${DatabaseColumns.id} = ?',
      whereArgs: [_insight![DatabaseColumns.id]],
    );

    // Update widget to show next insight or placeholder
    try {
      final widgetService = WidgetService(DatabaseHelper.instance);
      await widgetService.updateWidget();
    } catch (e) {
      print('[InsightBanner] Error updating widget after dismiss: $e');
    }

    if (!mounted) return;
    setState(() {
      _insight = null;
    });
  }

  void _showFullInsight() {
    if (_insight == null) return;
    final title = _insight![DatabaseColumns.insightTitle] as String? ?? 'Chrono';
    final body = _insight![DatabaseColumns.insightBody] as String? ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.tips_and_updates, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).commonClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_insight == null) return const SizedBox.shrink();
    final title = _insight![DatabaseColumns.insightTitle] as String? ?? 'Chrono';
    final body = _insight![DatabaseColumns.insightBody] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: _showFullInsight,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tips_and_updates, color: Colors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    if (body.length > 150)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Tap to read more...',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close, color: textHint, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
