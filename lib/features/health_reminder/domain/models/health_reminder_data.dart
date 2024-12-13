import 'package:equatable/equatable.dart';

class HealthReminderData extends Equatable {
  final String id;
  final DateTime date;
  final String description;
  bool isChecked;
  final List<String> selectedDays;

  HealthReminderData({
    required this.id,
    required this.date,
    required this.description,
    required this.isChecked,
    required this.selectedDays,
  });

  @override
  List<Object?> get props => [
        id,
        date,
        description,
        isChecked,
        selectedDays,
      ];
}
