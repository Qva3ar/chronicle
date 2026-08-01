import 'dart:convert';
import 'dart:developer';

import 'package:chrono/colors.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/l10n/app_localizations.dart';
import 'package:chrono/models/goal.model.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/models/record_type.dart';
import 'package:chrono/services/productivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Editor for a goal work-session note (`RecordType.goal`).
///
/// Lets the user correct the time spent on a goal for a PAST day; on save the
/// record's `time_minutes` is rewritten and the productivity index for that day
/// is recomputed via [ProductivityService.createOrUpdateDailyRecord] (records-based
/// for a past date, so the edit takes effect exactly).
///
/// Today's goal notes are shown read-only: today's index is driven by the live
/// timer (`goal.timeSpentSeconds`), so it must be managed there, not here.
class GoalRecordEditorScreen extends StatefulWidget {
  final Record record;

  const GoalRecordEditorScreen({super.key, required this.record});

  @override
  State<GoalRecordEditorScreen> createState() => _GoalRecordEditorScreenState();
}

class _GoalRecordEditorScreenState extends State<GoalRecordEditorScreen> {
  final _db = DatabaseHelper.instance;
  final _controller = TextEditingController();

  Goal? _goal;
  bool _loading = true;
  bool _saving = false;

  late final DateTime _recordDate;
  late final bool _isToday;
  late final String _dateStr; // yyyy-MM-dd for productivity recompute

  @override
  void initState() {
    super.initState();
    _recordDate = widget.record.createdAtDate;
    final now = DateTime.now();
    _isToday = _recordDate.year == now.year &&
        _recordDate.month == now.month &&
        _recordDate.day == now.day;
    _dateStr = DateFormat('yyyy-MM-dd').format(_recordDate);
    _controller.text = '${_parseTimeMinutes(widget.record.text) ?? 0}';
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    Goal? goal;
    if (widget.record.goalId != null) {
      goal = await _db.getGoal(widget.record.goalId!);
    }
    if (mounted) {
      setState(() {
        _goal = goal;
        _loading = false;
      });
    }
  }

  int? _parseTimeMinutes(String text) {
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) {
        final tm = data['time_minutes'];
        if (tm is num) return tm.toInt();
        if (tm is String) return int.tryParse(tm);
      }
    } catch (_) {
      final m = RegExp(r'time_minutes:\s*(\d+)').firstMatch(text);
      if (m != null) return int.tryParse(m.group(1)!);
    }
    return null;
  }

  int? get _targetMinutes {
    final total = _goal?.totalSeconds ?? 0;
    return total > 0 ? total ~/ 60 : null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final minutes = int.tryParse(_controller.text.trim());
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.goalEnterValidMinutes),
          backgroundColor: MyColors.remove,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final target = _targetMinutes;
    final status =
        (target != null && minutes >= target) ? 'completed' : 'day_ended';

    final recordData = {
      'goal_id': widget.record.goalId,
      'time_minutes': minutes,
      'status': status,
    };

    try {
      await _db.updateRecord({
        DatabaseColumns.id: widget.record.id,
        DatabaseColumns.recordTitle: widget.record.title,
        DatabaseColumns.recordText: jsonEncode(recordData),
        DatabaseColumns.recordCreatedAt: widget.record.createdAt,
        DatabaseColumns.recordType: RecordType.goal.toDbValue(),
        DatabaseColumns.recordGoalId: widget.record.goalId,
      }, widget.record.tagIds);

      // Past date → records-based recompute picks up the new time_minutes.
      await ProductivityService.instance
          .createOrUpdateDailyRecord(forDate: _dateStr);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.goalRecordIndexUpdated),
          backgroundColor: MyColors.orangeDivider,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      log('[GoalRecordEditor] Save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: MyColors.remove,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final title = _goal?.title ?? widget.record.title;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        title: Text(
          l10n.goalRecordEditTitle,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag, color: successColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat.yMMMMEEEEd(locale).format(_recordDate),
                    style: const TextStyle(color: textMuted, fontSize: 13),
                  ),
                  if (_targetMinutes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.goalDailyTarget(_targetMinutes!),
                      style: const TextStyle(color: textHint, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_isToday)
                    _readonlyBanner(l10n)
                  else ...[
                    Text(
                      l10n.goalRecordTimeSpentLabel,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(color: textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardColor,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cardBorder.withValues(alpha: 0.4),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: successColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: successColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.commonSave,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _readonlyBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.goalRecordTodayReadonly,
              style: const TextStyle(color: textMuted, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
