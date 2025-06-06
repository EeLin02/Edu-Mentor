import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:provider/provider.dart';

import 'theme_notifier.dart';
import 'font_size_notifier.dart';

import 'login.dart';
import 'admin_dashboard.dart';
import 'mentor_dashboard.dart';
import 'student_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => FontSizeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(context);

    return MaterialApp(
      title: 'Edu Mentor',
      debugShowCheckedModeBanner: false,
      theme: themeNotifier.isDarkMode ? ThemeData.dark() : ThemeData.light(),

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: fontSizeNotifier.fontSize / 16,
          ),
          child: child!,
        );
      },

      initialRoute: '/login',
      routes: {
        '/login': (context) =>  LoginScreen(),
        '/adminDashboard': (context) =>  AdminDashboard(),
        '/mentorDashboard': (context) =>  MentorDashboard(),
        '/studentDashboard': (context) => StudentDashboard(),
      },
    );
  }
}