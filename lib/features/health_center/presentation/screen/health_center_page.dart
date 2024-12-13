import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/core/navigation/routes/health_reminder_route.dart';
import 'package:Chrono/features/health_center/presentation/bloc/health_center_bloc.dart';
import 'package:Chrono/features/health_reminder/domain/models/health_reminder_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../colors.dart';
import '../../../../generated/l10n.dart';

class HealthCenterPage extends StatelessWidget {
  const HealthCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<HealthCenterBloc>()..add(HealthCenterRemindersLoaded()),
      child: Scaffold(
        backgroundColor: cardColor,
        appBar: AppBar(
          backgroundColor: MyColors.primaryColor,
          centerTitle: true,
          title: Text("HEALTH CENTER", style: TextStyle(color: Color.fromARGB(255, 190, 190, 190))),
        ),
        body: _Body(),
        floatingActionButton: _AddReminderButton(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HealthCenterBloc>();
    return BlocBuilder<HealthCenterBloc, HealthCenterState>(
      buildWhen: (curr, prev) =>
          prev.reminders != curr.reminders || prev.isLoading != curr.isLoading,
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        }
        final reminders = state.reminders;
        return ListView.builder(
          itemBuilder: (BuildContext context, int index) {
            final reminder = reminders[index];
            final dateFormat = DateFormat.Hm('ru');
            final formattedDate = dateFormat.format(reminder.date);
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: MyColors.drawalBackground,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 50, color: Colors.white),
                      ),
                      Transform.scale(
                        scale: 2.0,
                        child: Checkbox(
                          checkColor: Colors.black,
                          activeColor: textColor,
                          value: reminder.isChecked,
                          onChanged: (value) {
                            bloc.add(HealthCenterReminderIsChecked(
                                isChecked: value ?? true, index: reminder.id));
                          },
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    reminder.description,
                    maxLines: 1,
                  ),
                  onLongPress: () {
                    showModalBottomSheet(
                        context: context,
                        builder: (context) => _DeleteDialog(
                              bloc: bloc,
                              reminder: reminder,
                            ));
                  },
                  onTap: () {
                    final id = reminder.id;
                    context.push(HealthReminderRoute.getRouteWithArgs(id)).then(
                      (value) {
                        if (value == true) {
                          bloc.add(HealthCenterRemindersLoaded());
                        }
                        ;
                      },
                    );
                  },
                ),
              ),
            );
          },
          itemCount: reminders.length,
        );
      },
    );
  }
}

class _AddReminderButton extends StatelessWidget {
  const _AddReminderButton();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HealthCenterBloc>();
    return FloatingActionButton(
      onPressed: () {
        context.push(HealthReminderRoute.navigateRoute).then(
          (value) {
            if (value == true) {
              bloc.add(HealthCenterRemindersLoaded());
            }
          },
        );
      },
      backgroundColor: MyColors.trecondaryColor,
      child: Icon(
        Icons.add,
        color: Colors.white,
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.bloc, required this.reminder});

  final HealthCenterBloc bloc;
  final HealthReminderData reminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: MyColors.trecondaryColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            style: TextButton.styleFrom(backgroundColor: MyColors.trecondaryColor),
            child: Icon(Icons.delete, color: textColor),
            onPressed: () {
              context.pop();
              bloc.add(HealthCenterReminderDeleted(reminder: reminder));
              bloc.add(HealthCenterRemindersLoaded());
            },
          ),
          Text(
            S.of(context).delete,
            style: TextStyle(color: textColor),
          )
        ],
      ),
    );
  }
}
