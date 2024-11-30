part of 'health_reminder_bloc.dart';

class HealthReminderState extends Equatable {
  final DateTime date;
  final String id;
  final bool needExit;
  final bool isLoading;
  final List<RepeatMode> modes;
  final List<DayOfWeek> daysOfWeek;

  HealthReminderState({
    required this.date,
    this.id = '',
    this.needExit = false,
    this.isLoading = false,
    required this.modes,
    required this.daysOfWeek,
  });

  HealthReminderState copyWith({
    DateTime? date,
    String? id,
    bool? needExit,
    bool? isLoading,
    List<RepeatMode>? modes,
    List<DayOfWeek>? daysOfWeek,
  }) {
    return HealthReminderState(
      date: date ?? this.date,
      id: id ?? this.id,
      needExit: needExit ?? this.needExit,
      isLoading: isLoading ?? this.isLoading,
      modes: modes ?? this.modes,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }

  @override
  List<Object?> get props => [
        date,
        id,
        needExit,
        isLoading,
        modes,
        daysOfWeek,
      ];
}
