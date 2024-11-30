import 'package:Chrono/features/health_reminder/domain/interactor/health_reminder_interactor.dart';
import 'package:Chrono/features/health_reminder/domain/models/health_reminder_data.dart';
import 'package:Chrono/features/health_reminder/presentation/models/repeat_mode.dart';
import 'package:Chrono/features/repeat/presentation/models/day_of_week.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

part 'health_reminder_event.dart';

part 'health_reminder_state.dart';

class HealthReminderBloc extends Bloc<HealthReminderEvent, HealthReminderState> {
  HealthReminderBloc({
    required HealthReminderInteractor healthReminderInteractor,
  })  : _healthReminderInteractor = healthReminderInteractor,
        super(HealthReminderState(
            date: DateTime.now(), modes: RepeatMode.getModes(), daysOfWeek: DayOfWeek.daysOfWeek)) {
    on<HealthReminderTimeSelected>(_onHealthReminderTimeSelected);
    on<HealthReminderSaveButtonClicked>(_onHealthReminderSaveButtonClicked);
    on<HealthReminderByIdLoaded>(_onHealthReminderByIdLoaded);
    on<HealthReminderRepeatModeChanged>(_onHealthReminderRepeatModeChanged);
  }

  final HealthReminderInteractor _healthReminderInteractor;

  final TextEditingController descriptionController = TextEditingController();

  void _onHealthReminderRepeatModeChanged(
    HealthReminderRepeatModeChanged event,
    Emitter<HealthReminderState> emit,
  ) {
    var modes = state.modes;
    for (int i = 0; i < modes.length; i++) {
      if (modes[i].mode == event.modes[i].mode) {
        modes[i].isSelected = true;
      } else
        modes[i].isSelected = false;
    }
    emit(state.copyWith(modes: modes));
  }

  void _onHealthReminderTimeSelected(
    HealthReminderTimeSelected event,
    Emitter<HealthReminderState> emit,
  ) {
    final timeOfDay = event.selectedTime;
    if (timeOfDay == null) return;
    final currentDay = state.date.copyWith(hour: timeOfDay.hour, minute: timeOfDay.minute);
    emit(state.copyWith(date: currentDay));
  }

  void _onHealthReminderByIdLoaded(
    HealthReminderByIdLoaded event,
    Emitter<HealthReminderState> emit,
  ) async {
    final id = event.id;
    if (id == null) {
      emit(state.copyWith(id: Uuid().v4()));
      return;
    }
    emit(state.copyWith(id: id, isLoading: true));
    await Future.delayed(const Duration(milliseconds: 300));
    var modes = state.modes;
    final reminder = await _healthReminderInteractor.getReminderById(id);
    for (int i = 0; i < modes.length; i++) {
      if (modes[i].mode == reminder?.mode) {
        modes[i].isSelected = true;
      } else
        modes[i].isSelected = false;
    }
    descriptionController.text = reminder?.description ?? '';
    emit(state.copyWith(
      date: reminder?.date,
      modes: modes,
      isLoading: false,
    ));
  }

  void _onHealthReminderSaveButtonClicked(
    HealthReminderSaveButtonClicked event,
    Emitter<HealthReminderState> emit,
  ) async {
    final id = state.id;
    String mode = 'Mode is not selected';
    for (int i = 0; i < state.modes.length; i++) {
      if (state.modes[i].isSelected == true) {
        mode = state.modes[i].mode;
      }
    }
    final reminder = HealthReminderData(
      id: id,
      date: state.date,
      description: descriptionController.text,
      isChecked: true,
      mode: mode,
    );
    await _healthReminderInteractor.saveReminder(reminder);
    emit(state.copyWith(needExit: true));
  }

  String getRepeatMode(List<RepeatMode> modes) {
    String mode = 'Mode is not selected';
    for (int i = 0; i < modes.length; i++) {
      if (modes[i].isSelected == true) {
        mode = modes[i].mode;
      }
    }
    return mode;
  }

  List<String> getStringModes(List<RepeatMode> modes) {
    List<String> stringModes = [];
    for (var mode in modes) {
      stringModes.add(mode.mode);
    }
    return stringModes;
  }

  List<int> getIntIsSelected(List<RepeatMode> modes) {
    List<int> intIsSelected = [];
    for (var mode in modes) {
      if (mode.isSelected) {
        intIsSelected.add(1);
      } else
        intIsSelected.add(0);
    }
    return intIsSelected;
  }
}
