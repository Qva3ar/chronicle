import 'package:flutter/material.dart';
import 'package:Chrono/homepage.dart';
import 'package:Chrono/services/gpt-note-bind.service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GPTNoteBindService().loadModel();

  runApp(const MyApp());
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
