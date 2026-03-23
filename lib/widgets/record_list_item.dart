import 'dart:convert';
import 'package:chrono/colors.dart';
import 'package:chrono/models/record.dart';
import 'package:chrono/models/record_type.dart';
import 'package:chrono/models/tag.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecordListItem extends StatelessWidget {
  final Record item;
  final List<Tag> tags;
  final Function(int) onDelete;
  final Function() onTap;

  const RecordListItem({
    Key? key,
    required this.item,
    required this.tags,
    required this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left colour indicator
                Container(
                  width: 4,
                  color: _getIndicatorColor(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.recordType == RecordType.routine)
                              _buildStatusRow('Routine Completed', Icons.check_circle, Colors.orange),
                            if (item.recordType == RecordType.goal)
                              _buildGoalStatusRow(),
                            if (item.recordType == RecordType.morningCheckin)
                              _buildStatusRow('Morning Checkin', Icons.wb_sunny, MyColors.orangeDivider),
                            if (item.recordType == RecordType.eveningCheckin)
                              _buildStatusRow('Evening Checkin', Icons.nightlight, MyColors.contactDivider),
                            if (item.recordType == RecordType.productivity)
                              _buildStatusRow('Productivity Index', Icons.trending_up, Colors.purpleAccent),
                            SizedBox(height: _shouldShowStatusRow() ? 6 : 0),
                            _buildContent(),
                            if (item.goalId != null || item.routineId != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.goalId != null
                                    ? 'Goal ID: ${item.goalId}'
                                    : 'Routine ID: ${item.routineId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
                        child: Row(
                          children: [
                            if (tags.isNotEmpty)
                              Expanded(
                                child: SizedBox(
                                  height: 28,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: tags.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                                    itemBuilder: (context, index) {
                                      final tag = tags[index];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: parseTagColor(tag.color).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: parseTagColor(tag.color).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          tag.name,
                                          style: TextStyle(
                                            color: parseTagColor(tag.color),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (tags.isEmpty) const Spacer(),
                            Text(
                              _formatDateTime(context, item.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (item.isLocked)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.lock, size: 16, color: textHint),
                              ),
                            IconButton(
                              onPressed: () => onDelete(item.id),
                              icon: const Icon(Icons.delete_outline, color: textHint, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _parseProductivityData() {
    try {
      final data = jsonDecode(item.text);
      if (data is Map<String, dynamic> && data.containsKey('score')) return data;
    } catch (_) {}
    return null;
  }

  Widget _buildContent() {
    if (item.recordType == RecordType.productivity) {
      final data = _parseProductivityData();
      if (data != null) {
        final score = (data['score'] as num?)?.toDouble() ?? 0.0;
        final routinesDone = (data['routines_done'] as num?)?.toInt() ?? 0;
        final routinesTotal = (data['routines_total'] as num?)?.toInt() ?? 0;
        final goalsProgress = (data['goals_progress'] as num?)?.toDouble() ?? 0.0;
        final color = score >= 7 ? Colors.greenAccent : score >= 4 ? Colors.orangeAccent : Colors.redAccent;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${score.toStringAsFixed(1)}/10',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Routines: $routinesDone/$routinesTotal • Goals: ${(goalsProgress * 100).round()}%',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        );
      }
    }
    if (item.recordType == RecordType.goal) {
      final data = _parseGoalData();
      if (data != null) {
        // Render pretty view for goal data
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🎯 Goal Work Session",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "⏱ Time spent: ${data['time_minutes']} min",
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            Text(
              "📊 Status: ${_formatStatus(data['status'])}",
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        );
      }
    }
    
    // Default text rendering
    return Text(
      "${item.text}",
      style: TextStyle(
        fontSize: 14,
        color: Colors.white,
      ),
    );
  }

  String _formatStatus(dynamic status) {
    if (status == null) return 'Unknown';
    String s = status.toString();
    if (s == 'active') return 'In Progress';
    if (s == 'completed') return 'Completed';
    if (s == 'day_ended') return 'Day Ended';
    return s;
  }

  Map<String, dynamic>? _parseGoalData() {
    try {
      // Try parsing as JSON first
      return jsonDecode(item.text);
    } catch (e) {
      // Fallback to text parsing (legacy format)
      final text = item.text;
      if (!text.contains('goal_id:') && !text.contains('time_minutes:')) return null;

      final goalIdMatch = RegExp(r'goal_id: (\d+)').firstMatch(text);
      final timeMinutesMatch = RegExp(r'time_minutes: (\d+)').firstMatch(text);
      // Status might be lower case or mixed case in text, usually 'status: active' or 'Status: In Progress'
      // The old format had "status: active" at the bottom
      final statusMatch = RegExp(r'status: (\w+)').firstMatch(text);

      if (goalIdMatch != null || timeMinutesMatch != null || statusMatch != null) {
         return {
           'goal_id': goalIdMatch?.group(1),
           'time_minutes': timeMinutesMatch?.group(1),
           'status': statusMatch?.group(1),
         };
      }
      return null;
    }
  }

  bool _shouldShowStatusRow() {
    return item.recordType == RecordType.routine ||
        item.recordType == RecordType.goal ||
        item.recordType == RecordType.morningCheckin ||
        item.recordType == RecordType.eveningCheckin ||
        item.recordType == RecordType.productivity;
  }

  Color _getCardColor() {
    switch (item.recordType) {
      case RecordType.routine:
        return const Color(0xFF3D3232);
      case RecordType.goal:
        return const Color(0xFF2D3B2D);
      case RecordType.morningCheckin:
        return const Color(0xFF3B3328);
      case RecordType.eveningCheckin:
        return const Color(0xFF28303B);
      case RecordType.productivity:
        return const Color(0xFF302740);
      default:
        return cardColor2;
    }
  }

  Color _getBorderColor() {
    switch (item.recordType) {
      case RecordType.routine:
        return Colors.orange.withValues(alpha: 0.3);
      case RecordType.goal:
        return successColor.withValues(alpha: 0.3);
      case RecordType.morningCheckin:
        return MyColors.orangeDivider.withValues(alpha: 0.3);
      case RecordType.eveningCheckin:
        return MyColors.contactDivider.withValues(alpha: 0.3);
      case RecordType.productivity:
        return Colors.purpleAccent.withValues(alpha: 0.3);
      default:
        return cardBorder.withValues(alpha: 0.3);
    }
  }

  Color _getIndicatorColor() {
    switch (item.recordType) {
      case RecordType.routine:
        return Colors.orange.withValues(alpha: 0.8);
      case RecordType.goal:
        return successColor.withValues(alpha: 0.8);
      case RecordType.morningCheckin:
        return MyColors.orangeDivider.withValues(alpha: 0.8);
      case RecordType.eveningCheckin:
        return MyColors.contactDivider.withValues(alpha: 0.8);
      case RecordType.productivity:
        return Colors.purpleAccent.withValues(alpha: 0.8);
      default:
        return cardBorder.withValues(alpha: 0.5);
    }
  }


  Widget _buildStatusRow(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalStatusRow() {
    final data = _parseGoalData();
    String status = 'active'; // default
    
    if (data != null && data['status'] != null) {
      status = data['status'].toString();
    } else {
      // Legacy text check if parsing failed completely
      if (item.text.contains('status: completed')) status = 'completed';
      else if (item.text.contains('status: day_ended')) status = 'day_ended';
    }

    if (status == 'completed') {
      return _buildStatusRow('Goal Completed', Icons.star, Colors.greenAccent);
    } else if (status == 'day_ended') {
      return _buildStatusRow('Day Ended', Icons.calendar_today, Colors.orangeAccent);
    } else {
      return _buildStatusRow('Goal In Progress', Icons.play_circle_outline, Colors.blueAccent);
    }
  }

  String _formatDateTime(BuildContext context, int timestamp) {
    final locale = Localizations.localeOf(context).toString();
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    // Use locale-aware formatting with 24-hour time and localized date
    final timeFormatter = DateFormat.Hm(locale);
    final dateFormatter = DateFormat.yMd(locale);
    return '${timeFormatter.format(dateTime)} ${dateFormatter.format(dateTime)}';
  }
}
