import 'package:flutter/material.dart';
import 'package:chrono/homepage.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/db_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

void main() async {
  try {
    print('Starting app initialization...');
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize database first
    print('Initializing database...');
    await DatabaseHelper.instance.initializeDatabase();

    // Initialize the notification service directly
    print('Initializing notification service...');
    await NotificationService().initialize();
    print('Notification service initialized');

    // Load GPT model
    print('Loading GPT model...');
    await GPTNoteBindService().loadModel();
    print('GPT model loaded');

    print('Starting app...');
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      // debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Montserrat',
        primarySwatch: Colors.blue,
        textButtonTheme: TextButtonThemeData(
            // style: TextButton.styleFrom(
            //   foregroundColor: Colors.white, // This is a custom color variable
            // ),
            ),
        textTheme: TextTheme(bodyMedium: TextStyle(color: Colors.black)),
      ),
      home: HomePage(),
    );
  }
}
