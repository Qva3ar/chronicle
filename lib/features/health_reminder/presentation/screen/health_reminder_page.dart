import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:go_router/go_router.dart';

import '../../../../colors.dart';
import '../../../../generated/l10n.dart';
import '../bloc/health_reminder_bloc.dart';

class HealthReminderPage extends StatelessWidget {
  const HealthReminderPage({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<HealthReminderBloc>()..add(HealthReminderByIdLoaded(id: id)),
      child: BlocListener<HealthReminderBloc, HealthReminderState>(
        listener: (context, state) {
          if (state.needExit) {
            context.pop(true);
          }
        },
        child: Scaffold(
          backgroundColor: cardColor,
          appBar: AppBar(
            iconTheme: IconThemeData(
              color: textColor,
            ),
            backgroundColor: MyColors.primaryColor,
            centerTitle: true,
            title: Text(
              id != null ? 'EDIT REMINDER' : 'CREATE REMINDER',
              style: TextStyle(color: Color.fromARGB(255, 190, 190, 190)),
            ),
            actions: const [
              _SaveIcon(),
            ],
          ),
          body: _Body(),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HealthReminderBloc>();
    final isLoading = context.select((HealthReminderBloc bloc) => bloc.state.isLoading);
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      child: Column(
        children: [
          TimePickerSpinner(
            highlightedTextStyle: TextStyle(color: Colors.white, fontSize: 60),
            alignment: Alignment.center,
            spacing: 50,
            itemWidth: 70,
            normalTextStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 40),
            itemHeight: 90,
            onTimeChange: (selectedTime) {
              bloc.add(HealthReminderTimeSelected(selectedTime: selectedTime));
            },
          ),
          _RepeatTextButton(),
          _DaysOfWeekButtons(),
          _DescriptionWidget(),
        ],
      ),
    );
  }
}

class _RepeatTextButton extends StatelessWidget {
  const _RepeatTextButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          MaterialButton(
            onPressed: () {},
            color: Colors.grey,
            child: Text('on weekdays'),
          ),
          MaterialButton(
            onPressed: () {},
            color: Colors.grey,
            child: Text('every day'),
          ),
          MaterialButton(
            onPressed: () {},
            color: Colors.grey,
            child: Text('once'),
          ),
        ],
      ),
    );
  }
}

class _DaysOfWeekButtons extends StatelessWidget {
  const _DaysOfWeekButtons();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HealthReminderBloc>();
    // final modes = bloc.state.modes;

    return BlocBuilder<HealthReminderBloc, HealthReminderState>(
      builder: (context, state) {
        final daysOfWeek = state.daysOfWeek;
        return Container(
          height: 50,
          width: double.infinity,
          child: ListView.builder(
            itemCount: daysOfWeek.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) {
              final day = daysOfWeek[index];
              return TextButton(
                style: TextButton.styleFrom(
                  shape: CircleBorder(side: BorderSide()),
                  backgroundColor:
                      day.isSelected ? MyColors.contactDivider : MyColors.trecondaryColor,
                ),
                onPressed: () {
                  bloc.add(HealthReminderDayOfWeekButtonClicked(dayOfWeek: daysOfWeek[index]));
                },
                child: Text(day.dayOfWeek),
              );
            },
          ),
        );
      },
    );

    // return TextButton(
    //   onPressed: () {
    //     context.push(RepeatRoute.navigateRoute,extra: modes).then(
    //       (value) {
    //         if (value is List<RepeatMode>) {
    //           bloc.add(HealthReminderRepeatModeChanged(modes: value));
    //         }
    //       },
    //     );
    //   },
    //   child: Padding(
    //     padding: const EdgeInsets.symmetric(horizontal: 8),
    //     child: Row(
    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //       crossAxisAlignment: CrossAxisAlignment.center,
    //       children: [
    //         Text(
    //           S.of(context).repeat,
    //           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30, color: textColor),
    //         ),
    //         Text(
    //           bloc.getRepeatMode(modes),
    //           style: TextStyle(color: Colors.white54),
    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }
}

class _DescriptionWidget extends StatelessWidget {
  const _DescriptionWidget();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).description,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextField(
            scrollPadding: EdgeInsets.zero,
            controller: context.read<HealthReminderBloc>().descriptionController,
            style: TextStyle(color: textColor, fontSize: 20),
            maxLines: null,
            decoration: InputDecoration(
              hintText: S.of(context).enter_text,
              hintStyle: TextStyle(color: textColor),
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveIcon extends StatelessWidget {
  const _SaveIcon();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HealthReminderBloc>();
    return IconButton(
      onPressed: () {
        bloc.add(HealthReminderSaveButtonClicked());
      },
      icon: const Icon(
        Icons.save,
        color: textColor,
      ),
    );
  }
}
