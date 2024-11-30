import 'package:equatable/equatable.dart';

class RepeatMode extends Equatable {
  String mode;
  bool isSelected;

  RepeatMode({
    required this.mode,
    required this.isSelected,
  });

  static List<RepeatMode> getModes() {
    return [
      RepeatMode(mode: 'One time', isSelected: true),
      RepeatMode(mode: 'Every day', isSelected: false),
      RepeatMode(mode: 'Select days', isSelected: false),
    ];
  }

  @override
  List<Object?> get props => [
        mode,
        isSelected,
      ];
}
