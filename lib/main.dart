import 'package:chrono/homepage.dart';
import 'package:flutter/material.dart';
import 'package:chrono/db_manager.dart';
import 'package:chrono/services/timer_service.dart';
import 'package:chrono/services/app_lifecycle_service.dart';
import 'package:chrono/services/gpt-note-bind.service.dart';
import 'package:chrono/services/notification_service.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/background/task_dispatcher.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    print('Starting app initialization...');
    WidgetsFlutterBinding.ensureInitialized();

    // Load persisted OpenAI API key and model
    await GPTNoteBindService().loadModel();

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

    // Initialize notification service for daily resets
    print('Initializing notification service...');
    await NotificationService().initialize();
    print('Notification service initialized');

    // Initialize unified WorkManager for all background tasks
    print('Initializing background task manager...');
    await BackgroundTaskManager.initialize();
    print('Background task manager initialized');

    // Schedule daily reset
    await BackgroundTaskManager.scheduleDailyReset();

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
      navigatorKey: navigatorKey,
      title: 'Goal Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Montserrat',
        brightness: Brightness.dark,

        // Color scheme for dark theme
        colorScheme: const ColorScheme.dark(
          primary: MyColors.primaryColor,
          secondary: MyColors.secondaryColor,
          surface: cardColor,
          error: MyColors.remove,
        ),

        // Scaffold background
        scaffoldBackgroundColor: bgColor,

        // Dialog theme with dark background
        dialogTheme: const DialogThemeData(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: white,
            fontFamily: 'Montserrat',
          ),
          contentTextStyle: TextStyle(
            fontSize: 14,
            color: white,
            fontFamily: 'Montserrat',
          ),
        ),

        // TextButton theme - use blue for visibility in dialogs
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: white,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ElevatedButton theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: MyColors.primaryColor,
            foregroundColor: white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Switch theme with high contrast
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return MyColors.fivyColor;
            }
            return MyColors.forthyColor;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return MyColors.trecondaryColor;
            }
            return MyColors.secondaryColor;
          }),
        ),

        // ListTile theme for SwitchListTile
        listTileTheme: const ListTileThemeData(
          textColor: white,
          iconColor: white,
        ),

        // Input decoration theme
        inputDecorationTheme: const InputDecorationTheme(
          // filled: true,
          // fillColor: cardColor2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: MyColors.forthyColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: MyColors.forthyColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: MyColors.fivyColor, width: 2),
          ),
          labelStyle: TextStyle(color: MyColors.fivyColor),
          hintStyle: TextStyle(color: MyColors.trecondaryColor),
        ),
      ),
      home: HomePage(),
    );
  }
}
