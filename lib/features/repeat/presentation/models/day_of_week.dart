import 'package:equatable/equatable.dart';

class DayOfWeek extends Equatable {
  final String dayOfWeek;
  bool isSelected;

  static List<DayOfWeek> daysOfWeek = [
    DayOfWeek(dayOfWeek: 'S', isSelected: false),
    DayOfWeek(dayOfWeek: 'M', isSelected: false),
    DayOfWeek(dayOfWeek: 'T', isSelected: false),
    DayOfWeek(dayOfWeek: 'W', isSelected: false),
    DayOfWeek(dayOfWeek: 'T', isSelected: false),
    DayOfWeek(dayOfWeek: 'F', isSelected: false),
    DayOfWeek(dayOfWeek: 'S', isSelected: false),
  ];

  DayOfWeek({
    required this.dayOfWeek,
    required this.isSelected,
  });

  @override
  List<Object?> get props => [
        dayOfWeek,
        isSelected,
      ];
}
