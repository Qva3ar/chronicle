import 'package:chrono/homepage.dart';
import 'package:flutter/material.dart';
import 'package:chrono/screens/goals_screen.dart';
import 'package:chrono/services/database_helper.dart';
import 'package:chrono/services/timer_service.dart';
import 'package:chrono/services/app_lifecycle_service.dart';

void main() async {
  try {
    print('Starting app initialization...');
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize database
    print('Initializing database...');
    await DatabaseHelper.instance.database;
    print('Database initialized');

    // Initialize timer service
    print('Initializing timer service...');
    await TimerService.instance.initialize();
    print('Timer service initialized');

    // Initialize app lifecycle service for background handling
    print('Initializing app lifecycle service...');
    AppLifecycleService.instance.initialize();
    print('App lifecycle service initialized');

    print('Starting app...');
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goal Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Montserrat',
        primarySwatch: Colors.blue,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white, // This is a custom color variable
          ),
        ),
      ),
      home: HomePage(),
    );
  }
}
