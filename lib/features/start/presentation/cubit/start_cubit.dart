import 'package:Chrono/features/start/presentation/cubit/start_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StartCubit extends Cubit<StartState> {
  StartCubit() : super(const StartState(index: 0));

  void changeBottomNavBar(int index) {
    emit(state.copyWith(index));
  }
}
