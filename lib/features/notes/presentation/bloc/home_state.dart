part of 'home_bloc.dart';

class HomeState extends Equatable {
  final bool isChanged;

  HomeState({this.isChanged = true});

  HomeState copyWith({bool? isChanged}) {
    return HomeState(isChanged: isChanged ?? this.isChanged);
  }

  @override
  List<Object?> get props => [isChanged];
}
