import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:provider/provider.dart';

import 'theme_notifier.dart';

import 'login.dart';
import 'admin_dashboard.dart';
import 'mentor_dashboard.dart';
import 'student_dashboard.dart';


import 'Mentors/announcement_screen.dart';
import 'Mentors/chat_to_students.dart';
import 'Mentors/share_resource_screen.dart';
import 'Mentors/create_announcement_screen.dart';
import 'Mentors/preview_announcement_screen.dart';


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

    return MaterialApp(
      title: 'Edu Mentor',
      debugShowCheckedModeBanner: false,
      theme: themeNotifier.isDarkMode ? ThemeData.dark() : ThemeData.light(),

      initialRoute: '/login',

      routes: {
        '/login': (context) => LoginScreen(),
        '/adminDashboard': (context) => AdminDashboard(),
        '/mentorDashboard': (context) => MentorDashboard(),
        '/studentDashboard': (context) => StudentDashboard(),

        // 👇 New routes with arguments handled using ModalRoute
        '/announcement': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return AnnouncementScreen(
            subjectName: args['subjectName'],
            className: args['className'],
          );
        },
        '/createAnnouncement': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return CreateAnnouncementScreen(
            subjectName: args['subjectName'],
            className: args['className'],
            announcementId: args['announcementId'],
            title: args['title'],
            description: args['description'],
            files: args['files'],
            externalLinks: List<String>.from(args['externalLinks'] ?? []),

          );
        },
        '/previewAnnouncement': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PreviewAnnouncementScreen(data: args['data']);
        },
        '/classChat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return ClassChatScreen(
            subjectName: args['subjectName'],
            className: args['className'],
          );
        },
        '/shareResources': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return ShareResourcesScreen(
            subjectName: args['subjectName'],
            className: args['className'],
          );
        },
      },
    );
  }
}
