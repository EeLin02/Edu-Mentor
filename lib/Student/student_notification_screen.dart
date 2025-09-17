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
    final user = _auth.currentUser;
    if (user == null) return;

    final enrollmentSnap = await _firestore
        .collection('subjectEnrollments')
        .where('studentId', isEqualTo: user.uid)
        .get();

    setState(() {
      enrolledSubjects = enrollmentSnap.docs.map((doc) => doc.data()).toList();
      isLoading = false;
    });
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
                    enroll['classId'] == data['classId']);
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

                  return ListTile(
                    leading: const Icon(Icons.campaign, color: Colors.redAccent),
                    title: Text(
                      "${data['subjectName'] ?? ''}.${data['className'] ?? ''}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                          'color': Colors.blue, // can be subject color later
                        },
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
