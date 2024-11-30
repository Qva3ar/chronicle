part of 'repeat_cubit.dart';

class RepeatState extends Equatable {
  final List<RepeatMode> modes;
  final bool needExit;
  final List<String> selectedDays;

  RepeatState({
    required this.modes,
    this.needExit = false,
    this.selectedDays = const [],
  });

  RepeatState copyWith({List<RepeatMode>? modes, bool? needExit, List<String>? selectedDays}) {
    return RepeatState(
      modes: modes ?? this.modes,
      needExit: needExit ?? this.needExit,
      selectedDays: selectedDays ?? this.selectedDays,
    );
  }

  @override
  List<Object?> get props => [
        modes,
        needExit,
        selectedDays,
      ];
}
