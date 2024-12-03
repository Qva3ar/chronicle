import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/features/start/presentation/cubit/start_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/widgets/bottom_nav_bar/notes_bottom_nav_bar.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<StartCubit>(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: _Body(navigationShell: navigationShell),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ChronoBottomNavigationBar(
        navigationShell: navigationShell,
      ),
    );
  }
}
