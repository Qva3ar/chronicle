// import 'package:Chrono/core/di/dependency_injection.dart';
// import 'package:Chrono/features/repeat/presentation/cubit/seleact_days_dialog_cubit/select_days_dialog_cubit.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';
//
// import '../../../../colors.dart';
// import '../../../../generated/l10n.dart';
// import '../../../health_reminder/presentation/models/repeat_mode.dart';
// import '../cubit/repeat_cubit/repeat_cubit.dart';
//
// class RepeatPage extends StatelessWidget {
//   const RepeatPage({super.key, required this.modes});
//
//   final List<RepeatMode> modes;
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => getIt<RepeatCubit>(param1: modes),
//       child: BlocListener<RepeatCubit, RepeatState>(
//         listener: (context, state) {
//           if (state.needExit) {
//             context.pop(state.modes);
//           }
//         },
//         child: Scaffold(
//           backgroundColor: cardColor,
//           appBar: AppBar(
//             iconTheme: IconThemeData(
//               color: textColor,
//             ),
//             backgroundColor: MyColors.primaryColor,
//             centerTitle: true,
//             title: Text(
//               S.of(context).repeat,
//               style: TextStyle(color: Color.fromARGB(255, 190, 190, 190)),
//             ),
//             actions: [
//               _SaveIcon(),
//             ],
//           ),
//           body: _Body(),
//         ),
//       ),
//     );
//   }
// }
//
// class _SaveIcon extends StatelessWidget {
//   const _SaveIcon();
//
//   @override
//   Widget build(BuildContext context) {
//     final cubit = context.read<RepeatCubit>();
//     return IconButton(
//       onPressed: () {
//         cubit.onSaveButtonClicked();
//       },
//       icon: const Icon(Icons.save),
//     );
//   }
// }
//
// class _Body extends StatelessWidget {
//   const _Body();
//
//   @override
//   Widget build(BuildContext context) {
//     final cubit = context.read<RepeatCubit>();
//     final modes = context.select((RepeatCubit cubit) => cubit.state.modes);
//     return ListView.builder(
//       itemCount: modes.length,
//       itemBuilder: (BuildContext context, int index) {
//         final mode = modes[index];
//         return Padding(
//           padding: const EdgeInsets.all(8),
//           child: SizedBox(
//             height: 50,
//             child: TextButton(
//               onPressed: () {
//                 cubit.updateMode(index);
//                 if (index == 2) {
//                   showDialog(
//                     barrierDismissible: false,
//                     context: context,
//                     builder: (context) => BlocProvider(
//                       create: (context) =>
//                           SelectDaysDialogCubit(selectedDays: cubit.state.selectedDays),
//                       child: _SelectDaysDialog(),
//                     ),
//                   ).then((value) {
//                     if (value is List<String>) {
//                       cubit.onDaysSelected(value);
//                     }
//                     ;
//                   });
//                 }
//               },
//               style: TextButton.styleFrom(
//                   backgroundColor: mode.isSelected ? Colors.black38 : Colors.white12),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     mode.mode,
//                     style: TextStyle(
//                       color: mode.isSelected ? Colors.white : Colors.white70,
//                       fontSize: 20,
//                     ),
//                   ),
//                   Visibility(
//                     visible: mode.isSelected,
//                     child: Icon(Icons.done),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _SelectDaysDialog extends StatelessWidget {
//   const _SelectDaysDialog();
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<SelectDaysDialogCubit, SelectDaysDialogState>(
//       builder: (context, state) {
//         return Dialog(
//           backgroundColor: MyColors.trecondaryColor,
//           child: SizedBox(
//             width: double.infinity,
//             height: 470,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Expanded(
//                   child: Text(
//                     textAlign: TextAlign.center,
//                     S.of(context).select_days_title,
//                     style: TextStyle(color: textColor, fontSize: 24),
//                   ),
//                 ),
//                 Container(
//                   height: 350,
//                   margin: EdgeInsets.only(bottom: 20),
//                   child: ListView.builder(
//                     itemExtent: 50,
//                     itemCount: state.daysOfWeek.length,
//                     itemBuilder: (BuildContext context, int index) {
//                       final dayOfWeek = state.daysOfWeek[index];
//                       return ListTile(
//                         title: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               dayOfWeek.dayOfWeek,
//                               style: const TextStyle(fontSize: 20, color: Colors.white),
//                             ),
//                             Transform.scale(
//                               scale: 1.5,
//                               child: Checkbox(
//                                   checkColor: Colors.black,
//                                   activeColor: textColor,
//                                   value: dayOfWeek.isSelected,
//                                   onChanged: (value) {
//                                     context
//                                         .read<SelectDaysDialogCubit>()
//                                         .onDaySelected(index, value ?? false);
//                                   }),
//                             ),
//                           ],
//                         ),
//                         onTap: () {
//                           context
//                               .read<SelectDaysDialogCubit>()
//                               .onDaySelected(index, !dayOfWeek.isSelected);
//                         },
//                       );
//                     },
//                   ),
//                 ),
//                 Expanded(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: Container(
//                       height: 50,
//                       width: double.infinity,
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Expanded(
//                             child: TextButton(
//                                 style:
//                                     TextButton.styleFrom(backgroundColor: MyColors.secondaryColor),
//                                 onPressed: () {
//                                   context.read<SelectDaysDialogCubit>().returnOldData();
//                                   context.pop(state.daysFromBd);
//                                 },
//                                 child: Text(
//                                   S.of(context).select_days_exit_buttons,
//                                   style: TextStyle(fontSize: 20),
//                                 )),
//                           ),
//                           Expanded(
//                             child: TextButton(
//                                 style: TextButton.styleFrom(
//                                   backgroundColor: MyColors.secondaryColor,
//                                 ),
//                                 onPressed: () {
//                                   context.pop(state.selectedDays);
//                                 },
//                                 child: Text(
//                                   S.of(context).select_days_ok_buttons,
//                                   style: TextStyle(fontSize: 20),
//                                 )),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
