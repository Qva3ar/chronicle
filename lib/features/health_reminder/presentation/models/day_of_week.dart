import 'package:equatable/equatable.dart';

class DayOfWeek extends Equatable {
  final String dayOfWeek;
  final bool isSelected;

  static List<DayOfWeek> daysOfWeek = [
    DayOfWeek(dayOfWeek: 'Sun', isSelected: true),
    DayOfWeek(dayOfWeek: 'Mon', isSelected: true),
    DayOfWeek(dayOfWeek: 'Tue', isSelected: true),
    DayOfWeek(dayOfWeek: 'Wed', isSelected: true),
    DayOfWeek(dayOfWeek: 'Thu', isSelected: true),
    DayOfWeek(dayOfWeek: 'Fri', isSelected: true),
    DayOfWeek(dayOfWeek: 'Sat', isSelected: true),
  ];

  static List<String> selectedDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  DayOfWeek({
    required this.dayOfWeek,
    required this.isSelected,
  });

  DayOfWeek copyWith({
    String? dayOfWeek,
    bool? isSelected,
  }) {
    return DayOfWeek(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [
        dayOfWeek,
        isSelected,
      ];
}
