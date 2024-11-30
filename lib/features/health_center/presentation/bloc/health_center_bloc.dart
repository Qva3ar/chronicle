import 'package:Chrono/features/health_center/domain/inderactor/health_center_interactor.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../health_reminder/domain/models/health_reminder_data.dart';

part 'health_center_event.dart';
part 'health_center_state.dart';

class HealthCenterBloc extends Bloc<HealthCenterEvent, HealthCenterState> {
  HealthCenterBloc({
    required HealthCenterInteractor healthCenterInteractor,
  })  : _healthCenterInteractor = healthCenterInteractor,
        super(HealthCenterState(reminders: [])) {
    on<HealthCenterRemindersLoaded>(_onHealthCenterRemindersDataLoaded);
    on<HealthCenterReminderDeleted>(_onHealthCenterReminderDeleted);
    on<HealthCenterReminderIsChecked>(_onChangeCheckboxState);
  }

  final HealthCenterInteractor _healthCenterInteractor;

  void _onHealthCenterRemindersDataLoaded(
    HealthCenterRemindersLoaded event,
    Emitter<HealthCenterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final reminders = await _healthCenterInteractor.getReminders();
    emit(state.copyWith(reminders: reminders, isLoading: false));
  }

  void _onHealthCenterReminderDeleted(
    HealthCenterReminderDeleted event,
    Emitter<HealthCenterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final reminder = event.reminder;
    final reminders = state.reminders.toList();
    reminders.remove(event.reminder);
    _healthCenterInteractor.deleteNote(reminder.id);
    emit(state.copyWith(reminders: reminders, isLoading: false));
  }

  // void _onHealthCenterReminderIsChecked(
  //   HealthCenterReminderIsChecked event,
  //   Emitter<HealthCenterState> emit,
  // ) async {
  //   print('INDEX ===>>> ${event.index}');
  //   emit(state.copyWith(isLoading: true));
  //   var reminders = state.reminders;
  //   // reminders = await _healthCenterInteractor.updateReminders(reminders);
  //   emit(state.copyWith(reminders: reminders, isLoading: false));
  // }

  void _onChangeCheckboxState(
    HealthCenterReminderIsChecked event,
    Emitter<HealthCenterState> emit,
  ) {
    emit(state.copyWith(isLoading: true));
    final id = event.index;
    final reminders = state.reminders;
    for (int i = 0; i < reminders.length; i++) {
      if (reminders[i].id == id) {
        reminders[i].isChecked = event.isChecked!;
      }
    }
    print('REMINDERS BLOC ==>> ${state.reminders}');
    emit(state.copyWith(reminders: reminders, isLoading: false));
  }
}
