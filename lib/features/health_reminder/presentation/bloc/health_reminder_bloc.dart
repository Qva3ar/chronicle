import 'package:Chrono/features/health_reminder/domain/interactor/health_reminder_interactor.dart';
import 'package:Chrono/features/health_reminder/domain/models/health_reminder_data.dart';
import 'package:Chrono/features/health_reminder/presentation/models/day_of_week.dart';
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
          date: DateTime.now(),
          daysOfWeek: DayOfWeek.daysOfWeek,
          selectedDays: DayOfWeek.selectedDays,
        )) {
    on<HealthReminderTimeSelected>(_onHealthReminderTimeSelected);
    on<HealthReminderSaveButtonClicked>(_onHealthReminderSaveButtonClicked);
    on<HealthReminderByIdLoaded>(_onHealthReminderByIdLoaded);
    on<HealthReminderDayOfWeekButtonClicked>(_onHealthReminderDayOfWeekClicked);
  }

  final HealthReminderInteractor _healthReminderInteractor;

  final TextEditingController descriptionController = TextEditingController();

  void _onHealthReminderDayOfWeekClicked(
    HealthReminderDayOfWeekButtonClicked event,
    Emitter<HealthReminderState> emit,
  ) {
    final currentDay = event.currentDay;
    List<DayOfWeek> daysOfWeek = state.daysOfWeek;
    final newDaysOfWeek = daysOfWeek
        .map((day) => day == currentDay
            ? day.copyWith(isSelected: event.currentDay.isSelected ? false : true)
            : day)
        .toList();
    emit(state.copyWith(
      daysOfWeek: newDaysOfWeek,
    ));
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
    final reminder = await _healthReminderInteractor.getReminderById(id);

    final List<DayOfWeek> daysOfWeek = [];

    for (int i = 0; i < state.daysOfWeek.length; i++) {
      for (int j = 0; j < reminder!.selectedDays.length; j++) {
        if (state.daysOfWeek[i].dayOfWeek == reminder.selectedDays[j]) {
          daysOfWeek.add(DayOfWeek(dayOfWeek: state.daysOfWeek[i].dayOfWeek, isSelected: true));
        }
      }
      if (daysOfWeek.length != i + 1) {
        daysOfWeek.add(DayOfWeek(dayOfWeek: state.daysOfWeek[i].dayOfWeek, isSelected: false));
      }
    }

    descriptionController.text = reminder?.description ?? '';
    emit(state.copyWith(
      date: reminder?.date,
      selectedDays: reminder?.selectedDays,
      daysOfWeek: daysOfWeek,
      isLoading: false,
    ));
  }

  void _onHealthReminderSaveButtonClicked(
    HealthReminderSaveButtonClicked event,
    Emitter<HealthReminderState> emit,
  ) async {
    final id = state.id;
    final List<String> selectedDays = [];
    for (var day in state.daysOfWeek) {
      if (day.isSelected) {
        selectedDays.add(day.dayOfWeek);
      }
    }
    final reminder = HealthReminderData(
      id: id,
      date: state.date,
      description: descriptionController.text,
      isChecked: false,
      selectedDays: selectedDays,
    );
    print('PRINT BLOC == $reminder');
    await _healthReminderInteractor.saveReminder(reminder);
    emit(state.copyWith(needExit: true));
  }
}
