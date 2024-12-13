part of 'health_reminder_bloc.dart';

class HealthReminderState extends Equatable {
  final DateTime date;
  final String id;
  final bool needExit;
  final bool isLoading;
  final List<DayOfWeek> daysOfWeek;
  final List<String> selectedDays;

  HealthReminderState({
    required this.date,
    this.id = '',
    this.needExit = false,
    this.isLoading = false,
    required this.daysOfWeek,
    required this.selectedDays,
  });

  HealthReminderState copyWith({
    DateTime? date,
    String? id,
    bool? needExit,
    bool? isLoading,
    List<DayOfWeek>? daysOfWeek,
    List<String>? selectedDays,
  }) {
    return HealthReminderState(
      date: date ?? this.date,
      id: id ?? this.id,
      needExit: needExit ?? this.needExit,
      isLoading: isLoading ?? this.isLoading,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      selectedDays: selectedDays ?? this.selectedDays,
    );
  }

  @override
  List<Object?> get props => [
        date,
        id,
        needExit,
        isLoading,
        daysOfWeek,
        selectedDays,
      ];
}
