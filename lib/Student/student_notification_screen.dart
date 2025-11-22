import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentNotificationScreen extends StatefulWidget {
  const StudentNotificationScreen({super.key});

  @override
  State<StudentNotificationScreen> createState() => _StudentNotificationScreenState();
}

class _StudentNotificationScreenState extends State<StudentNotificationScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> enrolledSubjects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEnrolledSubjects();
  }

  Future<void> _loadEnrolledSubjects() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      final enrollmentSnapshot = await FirebaseFirestore.instance
          .collection('subjectEnrollments')
          .where('studentId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> loadedSubjects = [];

      for (var doc in enrollmentSnapshot.docs) {
        final data = doc.data();

        final subjectId = data['subjectId'];
        final programmeId = data['programmeId'];
        final schoolId = data['schoolId'];
        final sectionId = data['sectionId'];

        // Get subject document
        final subjectDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('programmes')
            .doc(programmeId)
            .collection('subjects')
            .doc(subjectId)
            .get();

        // Get section document
        final sectionDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('programmes')
            .doc(programmeId)
            .collection('subjects')
            .doc(subjectId)
            .collection('sections')
            .doc(sectionId)
            .get();

        // Get student customization (color)
        final customizationQuery = await FirebaseFirestore.instance
            .collection('studentCustomizations')
            .where('studentId', isEqualTo: userId)
            .where('sectionId', isEqualTo: sectionId)
            .limit(1)
            .get();

        int? customColor;
        if (customizationQuery.docs.isNotEmpty) {
          final customizationData = customizationQuery.docs.first.data();
          if (customizationData.containsKey('color')) {
            customColor = customizationData['color'];
          }
        }

        if (subjectDoc.exists && sectionDoc.exists) {
          final subjectData = subjectDoc.data()!;
          final sectionData = sectionDoc.data()!;

          loadedSubjects.add({
            'subjectId': subjectId,
            'sectionId': sectionId,
            'programmeId': programmeId,
            'schoolId': schoolId,

            ...sectionData,
            ...data,

            'subjectName': subjectData['name'] ?? '',
            'subjectCode': subjectData['code'] ?? '',

            //  attach color if found
            'color': customColor,
          });
        }
      }

      setState(() {
        enrolledSubjects = loadedSubjects;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading subjects: $e");
    }
  }

  String _formatDate(Timestamp ts) {
    final date = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${date.day} ${months[date.month]}";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (enrolledSubjects.isEmpty) {
      return const Center(child: Text("No enrolled classes found."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page title like in your screenshot
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            "Notifications",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // Notifications list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading notifications"));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return enrolledSubjects.any((enroll) =>
                enroll['subjectId'] == data['subjectId'] &&
                    enroll['sectionId'] == data['sectionId']);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text("No notifications yet."));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  //  Find the enrolled subject details for this announcement
                  final subjectInfo = enrolledSubjects.firstWhere(
                        (enroll) =>
                    enroll['subjectId'] == data['subjectId'] &&
                        enroll['sectionId'] == data['sectionId'],
                    orElse: () => {},
                  );

                  return ListTile(
                    leading: Icon(
                      Icons.campaign,
                      color: subjectInfo['color'] != null
                          ? Color(subjectInfo['color'] as int)
                          : Colors.redAccent,
                    ),
                    title: Text(
                      "${subjectInfo['subjectName'] ?? ''} "
                          ".${subjectInfo['subjectCode'] ?? ''} "
                          ".${subjectInfo['sectionName'] ?? ''}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: subjectInfo['color'] != null
                            ? Color(subjectInfo['color'] as int)
                            : Colors.blue,
                      ),
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'] ?? 'No Title'),
                        if (data['timestamp'] != null)
                          Text(
                            _formatDate(data['timestamp']),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/previewAnnouncement',
                        arguments: {
                          'docid': docs[index].id,
                          'data': data,
                          'color': subjectInfo['color'] != null
                              ? Color(subjectInfo['color'] as int)
                              : Colors.blue,                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
