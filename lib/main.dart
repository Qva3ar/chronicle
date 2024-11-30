import 'package:Chrono/core/di/dependency_injection.dart';
import 'package:Chrono/core/navigation/router.dart';
import 'package:Chrono/services/gpt-note-bind.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'generated/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting();
  await GPTNoteBindService().loadModel();

  initDependencyInjection();
  runApp(MyApp(chronoRouter: getIt()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, required this.chronoRouter});

  final ChronoRouter chronoRouter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: ThemeData(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),
      ),
      routeInformationProvider: chronoRouter.router.routeInformationProvider,
      routeInformationParser: chronoRouter.router.routeInformationParser,
      routerDelegate: chronoRouter.router.routerDelegate,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
    );
  }
}
