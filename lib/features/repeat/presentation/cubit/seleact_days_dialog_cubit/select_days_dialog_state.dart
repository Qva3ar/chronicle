part of 'select_days_dialog_cubit.dart';

class SelectDaysDialogState extends Equatable {
  final List<String> selectedDays;
  final List<DayOfWeek> daysOfWeek;
  final List<String> daysFromBd;

  SelectDaysDialogState(
      {required this.selectedDays, required this.daysOfWeek, required this.daysFromBd});

  SelectDaysDialogState copyWith({
    List<String>? selectedDays,
    List<DayOfWeek>? daysOfWeek,
    List<String>? daysFromBd,
  }) {
    return SelectDaysDialogState(
      selectedDays: selectedDays ?? this.selectedDays,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      daysFromBd: daysFromBd ?? this.daysFromBd,
    );
  }

  @override
  List<Object?> get props => [
        selectedDays,
        daysOfWeek,
      ];
}
