import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:month_year_picker/month_year_picker.dart';


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
import 'Mentors/take_attendance_screen.dart';
import 'Mentors/weekly_quiz_screen.dart';


import 'Student/student_announcement_screen.dart';
import 'Student/chat_to_mentor.dart';
import 'Student/student_private_chat_screen.dart';
import 'Student/student_share_resource_screen.dart';
import 'Student/student_notes_screen.dart';
import 'Student/student_notes_detail_screen.dart';
import 'Student/student_attendance_record.dart';
import 'Student/student_quiz_screen.dart';
import 'Student/take_quiz_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void _handleNotificationTap(String announcementId) {
  navigatorKey.currentState?.pushNamed(
    '/studentAnnouncement',
    arguments: {
      "announcementId": announcementId,
      "color": Colors.teal,
    },
  );
}


// Local notification plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Ask notification permission
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission');
  } else {
    print('User declined or has not accepted permission');
  }

  // When app opened from notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    print("Notification tapped: ${message.data}");

    final route = message.data['route'];
    final announcementId = message.data['announcementId'];

    if (route == '/previewAnnouncement' && announcementId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcementId)
          .get();

      if (doc.exists) {
        navigatorKey.currentState?.pushNamed(
          '/previewAnnouncement',
          arguments: {
            "data": doc.data(),
            "color": Colors.teal,
          },
        );
      } else {
        print(" Announcement not found in Firestore");
      }
    }
  });

  // When app launched from terminated state via notification
  RemoteMessage? initialMessage =
  await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    final route = initialMessage.data['route'];
    final announcementId = initialMessage.data['announcementId'];

    if (route == '/previewAnnouncement' && announcementId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcementId)
          .get();

      if (doc.exists) {
        navigatorKey.currentState?.pushNamed(
          '/previewAnnouncement',
          arguments: {
            "data": doc.data(),
            "color": Colors.teal,
          },
        );
      }
    }
  }

  // Foreground message listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("📩 Foreground message received: ${message.notification?.title}");

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('userSettings')
          .doc(uid)
          .get();

      if (doc.exists && doc.data()?['notificationsEnabled'] == false) {
        print("🔕 Notifications disabled for this user, skipping...");
        return; // Stop here
      }
    }

    // Show local notification if enabled
    if (message.notification != null) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        platformChannelSpecifics,
        payload: message.data['announcementId'],
      );
    }
  });

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );


  await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug);

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        navigatorKey.currentState?.pushNamed(
          '/studentAnnouncement',
          arguments: {
            "announcementId": response.payload!,
            "color": Colors.teal,
          },
        );
      }
    },
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
      navigatorKey: navigatorKey,
      theme: themeNotifier.isDarkMode ? ThemeData.dark() : ThemeData.light(),

      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        MonthYearPickerLocalizations.delegate, // <- add this
      ],
      supportedLocales: [
        const Locale('en', ''),
      ],

      initialRoute: '/login',

      routes: {
        '/login': (context) => LoginScreen(),
        '/adminDashboard': (context) => AdminDashboard(),
        '/mentorDashboard': (context) => MentorDashboard(),
        '/studentDashboard': (context) => StudentDashboard(),

        //  New routes with arguments handled using ModalRoute
        '/announcement': (context) => const AnnouncementScreen(),
        '/studentAnnouncement': (context) => const StudentAnnouncementScreen(),


        '/createAnnouncement': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return CreateAnnouncementScreen(
            subjectId: args['subjectId'],
            subjectName: args['subjectName'],
            sectionId: args['sectionId'],
            sectionName: args['sectionName'],
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
              args['sectionId'] == null ||
              args['mentorId'] == null ||
              args['subjectName'] == null ||
              args['sectionName'] == null) {
            return const Scaffold(
              body: Center(child: Text("Missing arguments for ClassChatScreen")),
            );
          }

          return ClassChatScreen(
            subjectId: args['subjectId'] as String,
            sectionId: args['sectionId'] as String,
            mentorId: args['mentorId'] as String,
            subjectName: args['subjectName'] as String,
            sectionName: args['sectionName'] as String,
            color: args['color'] as Color?, // Can be null
          );
        },

        '/privateChat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PrivateChatScreen(
            mentorId: args['mentorId'],
            mentorName: args['mentorName'],
          );
        },

        '/studentClassChat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return StudentClassChatScreen(
            subjectId: args['subjectId'],
            sectionId: args['sectionId'],
            mentorId: args['mentorId'],
            subjectName: args['subjectName'],
            sectionName: args['sectionName'],
            color: args['color'],
          );
        },

        '/studentShareResources': (context) => const StudentResourceScreen(),
        '/shareResources': (context) => const ResourceScreen(),

        '/createResource': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CreateResourceScreen(
            subjectId: args['subjectId'] ?? '',
            sectionId: args['sectionId'] ?? '',
            subjectName: args['subjectName'] ?? '',
            sectionName: args['sectionName'] ?? '',
            color: args['color'],
            resourceId: args['resourceId'],
            title: args['title']?.toString(),
            description: args['description']?.toString(),
            category: args['category']?.toString(),
            links: args['links'] != null ? List<String>.from(args['links']) : [],
          );
        },

        '/PreviewResourceScreen': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PreviewAnnouncementScreen(data: args['data'],color: args['color'],);
        },

        '/takeAttendance': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TakeAttendanceScreen(
            schoolId: args['schoolId'],          // 🔥 Missing before
            programmeId: args['programmeId'],
            subjectId: args['subjectId'],
            sectionId: args['sectionId'],
            mentorId: args['mentorId'],
            subjectName: args['subjectName'],
            sectionName: args['sectionName'],
            color: args['color'],
          );
        },

        '/weeklyQuiz': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

          return WeeklyQuizScreen(
            subjectId: args['subjectId'],
            sectionId: args['sectionId'],
            mentorId: args['mentorId'],
            subjectName: args['subjectName'],
            sectionName: args['sectionName'],
            color: args['color'],
          );
        },


        '/studentAttendanceRecords': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;

          if (args is Map<String, dynamic>) {
            return StudentAttendanceRecordsScreen(
              sectionId: args['sectionId'] ?? '',
              subjectId: args['subjectId'] ?? '',
              studentId: args['studentId'] ?? '',
              color: args['color'] ?? Colors.blue, // fallback color
            );
          }

          // Fallback UI if arguments are missing/wrong type
          return const Scaffold(
            body: Center(
              child: Text(
                'Missing or invalid arguments for StudentAttendanceRecordsScreen',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        },

        '/studentNoteDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          args['data']['resourceId'] = args['docId'];

          return StudentNotesDetailScreen(
            data: args['data'],
            color: args['color'],
          );
        },

        '/studentQuizzes': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return StudentQuizzesScreen(
            sectionId: args['sectionId'],
            subjectId: args['subjectId'],
            studentId: args['studentId'],
            color: args['color'],
          );
        },
        '/takeQuiz': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TakeQuizScreen(
            quizId: args['quizId'],
            studentId: args['studentId'],
            sectionId: args['sectionId'],
            subjectId: args['subjectId'],
            color: args['color'],
            title: args['title'],
          );
        },


      },
      onGenerateRoute: (settings) {
        if (settings.name == '/studentNotes') {
          final args = settings.arguments as Map<String, dynamic>;

          return MaterialPageRoute(
            builder: (context) => StudentNotesPage(
              subjectId: args['subjectId'],
              sectionId: args['sectionId'],
              subjectName: args['subjectName'],
              sectionName: args['sectionName'],
              color: args['color'],
            ),
          );
        }

        return null; // fallback if no route matched
      },

    );
  }
}
