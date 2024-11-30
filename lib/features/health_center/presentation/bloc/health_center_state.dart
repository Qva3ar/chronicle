part of 'health_center_bloc.dart';

class HealthCenterState extends Equatable {
  final List<HealthReminderData> reminders;
  final bool isLoading;

  HealthCenterState({
    required this.reminders,
    this.isLoading = false,
  });

  HealthCenterState copyWith({
    List<HealthReminderData>? reminders,
    bool? isLoading,
  }) {
    return HealthCenterState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        reminders,
        isLoading,
      ];
}
