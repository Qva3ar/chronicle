part of 'health_reminder_bloc.dart';

sealed class HealthReminderEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class HealthReminderTimeSelected extends HealthReminderEvent {
  final DateTime? selectedTime;

  HealthReminderTimeSelected({required this.selectedTime});

  @override
  List<Object?> get props => [selectedTime];
}

class HealthReminderSaveButtonClicked extends HealthReminderEvent {}

class HealthReminderByIdLoaded extends HealthReminderEvent {
  final String? id;

  HealthReminderByIdLoaded({required this.id});

  @override
  List<Object?> get props => [id];
}

class HealthReminderDayOfWeekButtonClicked extends HealthReminderEvent {
  final DayOfWeek currentDay;

  HealthReminderDayOfWeekButtonClicked({required this.currentDay});

  @override
  List<Object?> get props => [currentDay];
}
