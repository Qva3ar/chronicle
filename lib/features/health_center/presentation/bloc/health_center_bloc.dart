import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/features/health_center/domain/inderactor/health_center_interactor.dart';
import 'package:Chrono/features/notes/data/db/record.service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../health_reminder/domain/models/health_reminder_data.dart';
import '../models/data_stream.dart';

part 'health_center_event.dart';
part 'health_center_state.dart';

class HealthCenterBloc extends Bloc<HealthCenterEvent, HealthCenterState> {
  HealthCenterBloc({
    required HealthCenterInteractor healthCenterInteractor,
    required RecordService recordService,
  })  : _healthCenterInteractor = healthCenterInteractor,
        _recordService = recordService,
        super(HealthCenterState(reminders: [])) {
    on<HealthCenterRemindersLoaded>(_onHealthCenterRemindersDataLoaded);
    on<HealthCenterReminderDeleted>(_onHealthCenterReminderDeleted);
    on<HealthCenterReminderIsChecked>(_onChangeCheckboxState);
  }

  final HealthCenterInteractor _healthCenterInteractor;
  final RecordService _recordService;
  final _dataStream = getIt<DataStream>();

  void _onHealthCenterRemindersDataLoaded(
    HealthCenterRemindersLoaded event,
    Emitter<HealthCenterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final reminders = await _healthCenterInteractor.getReminders();
    final sortedReminders = _sortReminders(reminders);
    emit(state.copyWith(reminders: sortedReminders, isLoading: false));
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

  void _onChangeCheckboxState(
    HealthCenterReminderIsChecked event,
    Emitter<HealthCenterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final id = event.index;
    final reminders = state.reminders;
    for (int i = 0; i < reminders.length; i++) {
      if (reminders[i].id == id) {
        if (reminders[i].isChecked == false) {
          reminders[i].isChecked = event.isChecked;
          _recordService.handleIsGenerated(1);
          _recordService
              .handleText(reminders[i].description + '\n' + reminders[i].date.toIso8601String());
          _dataStream.updateData(i);
        }
      }
    }
    await _healthCenterInteractor.saveReminders(reminders);
    emit(state.copyWith(reminders: reminders, isLoading: false));
  }
}

List<HealthReminderData> _sortReminders(List<HealthReminderData> reminders) {
  List<DateTime> date = [];
  List<HealthReminderData> sortedReminders = [];

  for (var reminder in reminders) {
    date.add(reminder.date);
  }
  date.sort((a, b) {
    return a.hour != b.hour
        ? a.hour.compareTo(b.hour)
        : a.minute != b.minute
            ? a.minute.compareTo(b.minute)
            : a.second.compareTo(b.second);
  });

  for (int i = 0; i < reminders.length; i++) {
    for (int j = 0; j < reminders.length; j++) {
      if (date[i] == reminders[j].date) {
        sortedReminders.add(reminders[j]);
      }
    }
  }
  return sortedReminders;
}
