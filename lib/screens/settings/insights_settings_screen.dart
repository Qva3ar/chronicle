import 'dart:convert';

import 'package:chrono/background/insight_worker.dart';
import 'package:chrono/db_manager.dart';
import 'package:flutter/material.dart';
import 'package:chrono/ai/insight_engine.dart';
import 'package:chrono/ai/context_builder.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:intl/intl.dart';

class InsightsSettingsScreen extends StatefulWidget {
  const InsightsSettingsScreen({super.key});

  @override
  State<InsightsSettingsScreen> createState() => _InsightsSettingsScreenState();
}

class _InsightsSettingsScreenState extends State<InsightsSettingsScreen> {
  bool _enabled = true;
  int _intervalMinutes = 60;
  int _contextDays = 7;
  int _tokenLimit = 4000;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  int? _lastBackgroundRunAt;

  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  bool _signalsLoading = true;
  List<Map<String, dynamic>> _signalsInContext = [];
  List<Map<String, dynamic>> _signalsOutContext = [];
  bool _insightsLoading = true;
  List<Map<String, dynamic>> _insights = [];
  bool _contextLoading = false;
  Map<String, dynamic>? _contextPreview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.appSettings, limit: 1);
    if (rows.isNotEmpty) {
      final s = rows.first;
      if (!mounted) return;
      setState(() {
        _enabled = (s[DatabaseColumns.settingInsightEnabled] ?? 1) == 1;
        _intervalMinutes = (s[DatabaseColumns.settingInsightIntervalMinutes] as int?) ?? 60;
        _contextDays = (s[DatabaseColumns.settingInsightContextDays] as int?) ?? 7;
        _tokenLimit = (s[DatabaseColumns.settingInsightTokenLimit] as int?) ?? 4000;
        final startStr = s[DatabaseColumns.settingQuietHoursStart] as String?;
        final endStr = s[DatabaseColumns.settingQuietHoursEnd] as String?;
        _quietStart = _parseTime(startStr);
        _quietEnd = _parseTime(endStr);
        _lastBackgroundRunAt = s[DatabaseColumns.settingLastBackgroundRunAt] as int?;
        _loading = false;
      });
      await _loadSignals();
      await _loadInsights();
    } else {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadSignals() async {
    if (!mounted) return;
    setState(() {
      _signalsLoading = true;
    });
    try {
      final db = await DatabaseHelper.instance.database;
      final since = DateTime.now().subtract(Duration(days: _contextDays)).millisecondsSinceEpoch;
      final inRows = await db.query(
        DatabaseTables.aiInterestSignals,
        where: '${DatabaseColumns.aiCreatedAt} >= ?',
        whereArgs: [since],
        orderBy: '${DatabaseColumns.aiCreatedAt} DESC',
        limit: 200,
      );
      final outRows = await db.query(
        DatabaseTables.aiInterestSignals,
        where: '${DatabaseColumns.aiCreatedAt} < ?',
        whereArgs: [since],
        orderBy: '${DatabaseColumns.aiCreatedAt} DESC',
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _signalsInContext = inRows;
        _signalsOutContext = outRows;
      });
    } finally {
      if (mounted) {
        setState(() {
          _signalsLoading = false;
        });
      }
    }
  }

  Future<void> _loadInsights() async {
    if (!mounted) return;
    setState(() {
      _insightsLoading = true;
    });
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        DatabaseTables.aiInsights,
        orderBy: '${DatabaseColumns.insightDeliveredAt} DESC',
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _insights = rows;
      });
    } finally {
      if (mounted) {
        setState(() {
          _insightsLoading = false;
        });
      }
    }
  }

  Future<void> _loadContextPreview() async {
    if (!mounted) return;
    setState(() {
      _contextLoading = true;
    });
    try {
      final settings = await ContextBuilder.instance.loadSettings();
      final ctx = await ContextBuilder.instance.buildInsightsContext(
        contextDays: settings.contextDays,
        tokenLimitApprox: settings.tokenLimit,
        primaryGoalText: settings.mainIntentionText,
      );
      if (!mounted) return;
      setState(() {
        _contextPreview = ctx;
      });
    } catch (e) {
      print('[Settings] ❌ Failed to load context preview: $e');
    } finally {
      if (mounted) {
        setState(() {
          _contextLoading = false;
        });
      }
    }
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _quietStart : _quietEnd) ?? const TimeOfDay(hour: 22, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseTables.appSettings, limit: 1);
    final map = {
      DatabaseColumns.settingInsightEnabled: _enabled ? 1 : 0,
      DatabaseColumns.settingInsightIntervalMinutes: _intervalMinutes,
      DatabaseColumns.settingInsightContextDays: _contextDays,
      DatabaseColumns.settingInsightTokenLimit: _tokenLimit,
      DatabaseColumns.settingQuietHoursStart: _fmt(_quietStart),
      DatabaseColumns.settingQuietHoursEnd: _fmt(_quietEnd),
    };
    if (rows.isEmpty) {
      await db.insert(DatabaseTables.appSettings, map);
    } else {
      await db.update(DatabaseTables.appSettings, map,
          where: '${DatabaseColumns.id} = ?', whereArgs: [rows.first[DatabaseColumns.id]]);
    }
    // Re-register background worker schedule
    await InsightWorker.registerIfEnabled();

    // Trigger immediate insight generation
    if (_enabled) {
      final insight = await InsightEngine.instance.generateAndStoreInsight();
      if (insight != null && insight['should_notify'] == true) {
        await NotificationService().showInsightNotification(
          title: (insight['title'] ?? 'Chrono') as String,
          body: (insight['body'] ?? '') as String,
        );
      }
    }
    // Refresh signals preview based on new settings
    await _loadSignals();
    await _loadInsights();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insights settings saved')),
      );
    Navigator.of(context).pop(true);
    }
  }

  Future<void> _testNow() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧪 Generating insight... check logs and notifications'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    try {
      await InsightWorker.generateNow();
      await _load(); // Refresh settings including timestamp
      await _loadInsights(); // Refresh the insights list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test completed! Check logs for details'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      String userMessage = '❌ Test failed';

      if (errorStr.contains('socketexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('no address associated')) {
        userMessage = '📡 No internet connection\n\nCheck Wi-Fi/mobile data and try again';
      } else if (errorStr.contains('api key') || errorStr.contains('unauthorized')) {
        userMessage = '🔑 API key error\n\nCheck OpenAI API settings';
      } else if (errorStr.contains('timeout')) {
        userMessage = '⏱️ Request timeout\n\nCheck your connection';
      } else {
        userMessage = '❌ Error: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('AI Insights Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Enable AI Insights'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '$_intervalMinutes',
                decoration: const InputDecoration(labelText: 'Interval (minutes)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _intervalMinutes = int.tryParse(v) ?? _intervalMinutes,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 15 || n > 720) {
                    return 'Enter 15..720';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '$_contextDays',
                decoration: const InputDecoration(labelText: 'Context window (days)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _contextDays = int.tryParse(v) ?? _contextDays,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n > 60) {
                    return 'Enter 1..60';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '$_tokenLimit',
                decoration: const InputDecoration(labelText: 'Token limit (approx)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _tokenLimit = int.tryParse(v) ?? _tokenLimit,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 500 || n > 16000) {
                    return 'Enter 500..16000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Quiet hours start'),
                subtitle: Text(_fmt(_quietStart) ?? 'Not set'),
                trailing: const Icon(Icons.schedule),
                onTap: () => _pickTime(isStart: true),
              ),
              ListTile(
                title: const Text('Quiet hours end'),
                subtitle: Text(_fmt(_quietEnd) ?? 'Not set'),
                trailing: const Icon(Icons.schedule),
                onTap: () => _pickTime(isStart: false),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Requires internet connection and OpenAI API key to generate insights',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _testNow,
                icon: const Icon(Icons.science),
                label: const Text('Test Insight Generation Now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Background Execution',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _lastBackgroundRunAt != null
                                ? _formatLastRun(_lastBackgroundRunAt!)
                                : 'Never run yet',
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Context Preview',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: _contextLoading ? null : _loadContextPreview,
                    icon: _contextLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_contextLoading ? 'Loading...' : 'Build Context'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_contextPreview != null)
                ExpansionTile(
                  title: const Text('Full Context JSON'),
                  subtitle: Text('${(_contextPreview!['context_json'] as String).length} characters'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ').convert(_contextPreview!),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Interest signals preview',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_signalsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _buildSignalSection(
                  title:
                      'Included in context (last $_contextDays day${_contextDays == 1 ? '' : 's'})',
                  items: _signalsInContext,
                ),
                const SizedBox(height: 8),
                _buildSignalSection(
                  title: 'Outside context window',
                  items: _signalsOutContext,
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Stored insights (last 50)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_insightsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_insights.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 4, right: 4, bottom: 12),
                  child: Text('No insights saved yet.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _insights.length,
                  itemBuilder: (context, index) {
                    final insight = _insights[index];
                    final title =
                        (insight[DatabaseColumns.insightTitle] ?? 'Chrono').toString();
                    final body = (insight[DatabaseColumns.insightBody] ?? '').toString();
                    final deliveredAs =
                        (insight[DatabaseColumns.insightDeliveredAs] ?? 'banner').toString();
                    final dismissedAt = insight[DatabaseColumns.insightDismissedAt] as int?;
                    final expiresAt = insight[DatabaseColumns.insightExpiresAt] as int?;
                    final deliveredAt = insight[DatabaseColumns.insightDeliveredAt] as int?;
                    return Card(
                      color: Colors.white10,
                      child: ListTile(
                        onTap: () => _showFullInsight(insight),
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              body.isEmpty ? '(empty body)' : body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (body.length > 100)
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
                            const SizedBox(height: 6),
                            Text(
                              [
                                'delivered: ${_fmtTimestamp(deliveredAt)}',
                                'expires: ${_fmtTimestamp(expiresAt)}',
                                if (dismissedAt != null && dismissedAt > 0)
                                  'dismissed: ${_fmtTimestamp(dismissedAt)}',
                              ].join(' • '),
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Chip(
                              label: Text(
                                deliveredAs,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalSection({
    required String title,
    required List<Map<String, dynamic>> items,
  }) {
    return ExpansionTile(
      title: Text('$title • ${items.length}'),
      initiallyExpanded: false,
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('No items'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final m = items[index];
              final topic = (m[DatabaseColumns.aiTopic] ?? '').toString();
              final intent = (m[DatabaseColumns.aiIntent] ?? '').toString();
              final conf = m[DatabaseColumns.aiConfidence];
              final ts = m[DatabaseColumns.aiCreatedAt] as int?;
              final dt =
                  ts != null ? DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String() : '';
              return ListTile(
                dense: true,
                title: Text(topic.isEmpty ? '(no topic)' : topic),
                subtitle: Text(
                    'intent: ${intent.isEmpty ? '-' : intent} • conf: ${conf is num ? conf.toStringAsFixed(2) : '-'} • $dt'),
              );
            },
          ),
      ],
    );
  }

  String _fmtTimestamp(int? millis) {
    if (millis == null || millis == 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return dt.toIso8601String();
  }

  String _formatLastRun(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM d, y HH:mm').format(dt);
    }
  }

  void _showFullInsight(Map<String, dynamic> insight) {
    final title = (insight[DatabaseColumns.insightTitle] ?? 'Chrono').toString();
    final body = (insight[DatabaseColumns.insightBody] ?? '').toString();
    final deliveredAt = insight[DatabaseColumns.insightDeliveredAt] as int?;
    final expiresAt = insight[DatabaseColumns.insightExpiresAt] as int?;
    final dismissedAt = insight[DatabaseColumns.insightDismissedAt] as int?;
    final deliveredAs = (insight[DatabaseColumns.insightDeliveredAs] ?? 'banner').toString();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                body,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Delivered: ${_fmtTimestamp(deliveredAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Text(
                'Expires: ${_fmtTimestamp(expiresAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              if (dismissedAt != null && dismissedAt > 0)
                Text(
                  'Dismissed: ${_fmtTimestamp(dismissedAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              Text(
                'Type: $deliveredAs',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
