import 'package:Chrono/features/health_reminder/presentation/models/repeat_mode.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'repeat_state.dart';

class RepeatCubit extends Cubit<RepeatState> {
  RepeatCubit({required List<RepeatMode> modes}) : super(RepeatState(modes: modes));

  void onDaysSelected(List<String> selectedDays) {
    emit(state.copyWith(selectedDays: selectedDays));
  }

  void updateMode(int index) async {
    List<RepeatMode> newModes = _createNewModesList();
    for (int i = 0; i < newModes.length; i++) {
      if (newModes[index].mode == newModes[i].mode) {
        newModes[i].isSelected = true;
      } else
        newModes[i].isSelected = false;
    }
    emit(state.copyWith(
      modes: newModes,
    ));
  }

  void onSaveButtonClicked() {
    emit(state.copyWith(needExit: true));
  }

  List<RepeatMode> _createNewModesList() {
    List<RepeatMode> newModes = [];
    for (var mode in state.modes) {
      newModes.add(RepeatMode(mode: mode.mode, isSelected: false));
    }
    return newModes;
  }
}
