import 'package:equatable/equatable.dart';

class StartState extends Equatable {
  final int index;

  const StartState({required this.index});

  StartState copyWith(int index) {
    return StartState(index: index);
  }

  @override
  List<Object?> get props => [index];
}
