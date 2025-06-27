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
import 'Mentors/create_resource_screen.dart';
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

        //  New routes with arguments handled using ModalRoute
        '/announcement': (context) => const AnnouncementScreen(),


        '/createAnnouncement': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return CreateAnnouncementScreen(
            subjectName: args['subjectName'],
            className: args['className'],
            color: args['color'],
            announcementId: args['announcementId'],
            title: args['title'],
            description: args['description'],
            files: args['files'],
            externalLinks: List<String>.from(args['externalLinks'] ?? []),

          );
        },
        '/previewAnnouncement': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PreviewAnnouncementScreen(data: args['data'],color: args['color'],);
        },
        '/classChat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

          if (args == null ||
              args['subjectId'] == null ||
              args['classId'] == null ||
              args['mentorId'] == null ||
              args['subjectName'] == null ||
              args['className'] == null) {
            return const Scaffold(
              body: Center(child: Text("Missing arguments for ClassChatScreen")),
            );
          }

          return ClassChatScreen(
            subjectId: args['subjectId'] as String,
            classId: args['classId'] as String,
            mentorId: args['mentorId'] as String,
            subjectName: args['subjectName'] as String,
            className: args['className'] as String,
            color: args['color'] as Color?, // Can be null
          );
        },


        '/shareResources': (context) => const ResourceScreen(),

        '/createResource': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CreateResourceScreen(
            subjectName: args['subjectName'],
            className: args['className'],
            color: args['color'],
            resourceId: args['resourceId'],
            title: args['title'],
            description: args['description'],
            category: args['category'],
            links: args['links'] != null ? List<String>.from(args['links']) : [],
            // Add other arguments as needed
          );
        },
        '/PreviewResourceScreen': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PreviewAnnouncementScreen(data: args['data'],color: args['color'],);
        },
      },
    );
  }
}
