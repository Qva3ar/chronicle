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

class HealthReminderRepeatModeChanged extends HealthReminderEvent {
  final List<RepeatMode> modes;

  HealthReminderRepeatModeChanged({required this.modes});

  @override
  List<Object?> get props => [modes];
}
