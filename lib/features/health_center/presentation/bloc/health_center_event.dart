part of 'health_center_bloc.dart';

class HealthCenterEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class HealthCenterRemindersLoaded extends HealthCenterEvent {}

class HealthCenterReminderDeleted extends HealthCenterEvent {
  final HealthReminderData reminder;

  HealthCenterReminderDeleted({required this.reminder});

  @override
  List<Object?> get props => [reminder];
}

class HealthCenterReminderIsChecked extends HealthCenterEvent {
  final bool? isChecked;
  final String index;

  HealthCenterReminderIsChecked({required this.isChecked, required this.index});

  @override
  List<Object?> get props => [isChecked, index];
}
