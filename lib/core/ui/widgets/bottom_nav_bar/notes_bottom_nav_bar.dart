import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../colors.dart';
import '../../../../features/start/presentation/cubit/start_cubit.dart';
import '../../../../features/start/presentation/cubit/start_state.dart';

class ChronoBottomNavigationBar extends StatelessWidget {
  const ChronoBottomNavigationBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StartCubit, StartState>(builder: (context, state) {
      return BottomNavigationBar(
        backgroundColor: MyColors.trecondaryColor,
        currentIndex: state.index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: MyColors.forthyColor,
        onTap: (index) {
          context.read<StartCubit>().changeBottomNavBar(index);
          navigationShell.goBranch(index);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(
              Icons.note,
            ),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.cell_tower),
            label: 'Health Center',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/chat.svg',
              colorFilter: ColorFilter.mode(MyColors.forthyColor, BlendMode.srcIn),
            ),
            label: 'GPT',
          ),
        ],
      );
    });
  }
}
