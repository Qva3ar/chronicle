import 'package:Chrono/features/health_reminder/data/db/health_reminder_db_service.dart';
import 'package:equatable/equatable.dart';

class HealthReminderEntity extends Equatable {
  final String id;
  final String date;
  final String description;
  final int isChecked;
  final String selectedDays;

  HealthReminderEntity({
    required this.id,
    required this.date,
    required this.description,
    required this.selectedDays,
    required this.isChecked,
  });

  factory HealthReminderEntity.fromJson(Map<String, dynamic> json) {
    return HealthReminderEntity(
      id: json[HealthReminderDbService.columnId],
      date: json[HealthReminderDbService.columnDate],
      description: json[HealthReminderDbService.columnDescription],
      isChecked: json[HealthReminderDbService.columnIsChecked],
      selectedDays: json[HealthReminderDbService.columnSelectedDays],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      HealthReminderDbService.columnId: id,
      HealthReminderDbService.columnDate: date,
      HealthReminderDbService.columnDescription: description,
      HealthReminderDbService.columnIsChecked: isChecked,
      HealthReminderDbService.columnSelectedDays: selectedDays,
    };
  }

  @override
  List<Object?> get props => [
        id,
        date,
        description,
        isChecked,
        selectedDays,
      ];
}
