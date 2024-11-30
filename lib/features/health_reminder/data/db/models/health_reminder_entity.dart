import 'package:Chrono/features/health_reminder/data/db/health_reminder_db_service.dart';
import 'package:equatable/equatable.dart';

class HealthReminderEntity extends Equatable {
  final String id;
  final String date;
  final String description;
  final int isChecked;
  final String mode;

  HealthReminderEntity({
    required this.id,
    required this.date,
    required this.description,
    required this.isChecked,
    required this.mode,
  });

  factory HealthReminderEntity.fromJson(Map<String, dynamic> json) {
    return HealthReminderEntity(
      id: json[HealthReminderDbService.columnId],
      date: json[HealthReminderDbService.columnDate],
      description: json[HealthReminderDbService.columnDescription],
      isChecked: json[HealthReminderDbService.columnIsChecked],
      mode: json[HealthReminderDbService.columnMode],
    );
  }

  Map<String, dynamic> toJson() => {
        HealthReminderDbService.columnId: id,
        HealthReminderDbService.columnDate: date,
        HealthReminderDbService.columnDescription: description,
        HealthReminderDbService.columnIsChecked: isChecked,
        HealthReminderDbService.columnMode: mode,
      };

  @override
  List<Object?> get props => [
        id,
        date,
        description,
        isChecked,
        mode,
      ];
}
