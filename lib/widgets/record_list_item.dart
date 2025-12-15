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
      child: Card(
        elevation: 0,
        margin: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        color: _getCardColor(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: _getBorderSide(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
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
                  SizedBox(
                      height: _shouldShowStatusRow() ? 8 : 0),
                  Text(
                    "${item.text}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  if (item.goalId != null || item.routineId != null) ...[
                    SizedBox(height: 8),
                    Text(
                      item.goalId != null
                          ? 'Goal ID: ${item.goalId}'
                          : 'Routine ID: ${item.routineId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (tags.isNotEmpty)
                    Expanded(
                      child: SizedBox(
                        height: 35,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: tags.length,
                          itemBuilder: (context, index) {
                            final tag = tags[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: Color(int.parse(tag.color ?? '0xFF808080')),
                              ),
                              child: Center(
                                child: Text(
                                  tag.name,
                                  style: const TextStyle(color: Colors.black, fontSize: 12),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (item.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.lock,
                        size: 18,
                        color: Colors.white30,
                      ),
                    ),
                  IconButton(
                    onPressed: () => onDelete(item.id),
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowStatusRow() {
    return item.recordType == RecordType.routine ||
        item.recordType == RecordType.goal ||
        item.recordType == RecordType.morningCheckin ||
        item.recordType == RecordType.eveningCheckin;
  }

  Color _getCardColor() {
    switch (item.recordType) {
      case RecordType.routine:
        return const Color.fromARGB(255, 100, 80, 80);
      case RecordType.goal:
        return const Color.fromARGB(255, 60, 90, 60);
      case RecordType.morningCheckin:
        return const Color.fromARGB(255, 90, 80, 60); // Morning warm color
      case RecordType.eveningCheckin:
        return const Color.fromARGB(255, 60, 70, 90); // Evening cool color
      default:
        return MyColors.primaryColor;
    }
  }

  BorderSide _getBorderSide() {
    switch (item.recordType) {
      case RecordType.routine:
        return const BorderSide(color: Colors.orange, width: 1);
      case RecordType.goal:
        return const BorderSide(color: Colors.greenAccent, width: 1);
      case RecordType.morningCheckin:
        return const BorderSide(color: MyColors.orangeDivider, width: 1);
      case RecordType.eveningCheckin:
        return const BorderSide(color: MyColors.contactDivider, width: 1);
      default:
        return BorderSide.none;
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
    // Parse status from record text
    // Format: "...---\ngoal_id: X\ntime_minutes: Y\nstatus: active/completed/day_ended"
    final text = item.text;

    if (text.contains('status: completed')) {
      return _buildStatusRow('Goal Completed', Icons.star, Colors.greenAccent);
    } else if (text.contains('status: day_ended')) {
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
