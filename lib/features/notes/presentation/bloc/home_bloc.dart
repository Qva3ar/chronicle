import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_event.dart';

part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeState()) {
    on<HomeStreamDataChanged>(_onHomeStreamDataChanged);
  }

  void _onHomeStreamDataChanged(
    HomeStreamDataChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(isChanged: !state.isChanged));
  }
}
