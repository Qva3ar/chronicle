// import 'package:equatable/equatable.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
//
// import '../../models/day_of_week.dart';
//
// part 'select_days_dialog_state.dart';
//
// class SelectDaysDialogCubit extends Cubit<SelectDaysDialogState> {
//   SelectDaysDialogCubit({required List<String> selectedDays})
//       : super(SelectDaysDialogState(
//             daysOfWeek: DayOfWeek.daysOfWeek,
//             daysFromBd: selectedDays,
//             selectedDays: selectedDays)) {
//     returnOldData();
//   }
//
//   void returnOldData() {
//     if (state.selectedDays != state.daysFromBd) {
//       emit(state.copyWith(selectedDays: state.daysFromBd));
//     }
//   }
//
//   void onDaySelected(int index, bool isChecked) {
//     List<DayOfWeek> daysOfWeek = state.daysOfWeek;
//     for (int i = 0; i < daysOfWeek.length; i++) {
//       if (daysOfWeek[index].dayOfWeek == daysOfWeek[i].dayOfWeek) {
//         daysOfWeek[i].isSelected = isChecked;
//       }
//     }
//
//     List<String> selectedDays = state.selectedDays.toList();
//     if (isChecked) {
//       selectedDays.add(daysOfWeek[index].dayOfWeek);
//     } else {
//       for (int i = 0; i < selectedDays.length; i++) {
//         if (selectedDays[i] == daysOfWeek[index].dayOfWeek) {
//           selectedDays.remove(selectedDays[i]);
//         }
//       }
//     }
//     print('SELECTED DAYS === $selectedDays');
//     emit(state.copyWith(selectedDays: selectedDays, daysOfWeek: daysOfWeek));
//   }
// }
