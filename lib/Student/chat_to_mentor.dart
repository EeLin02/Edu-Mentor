import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_private_chat_screen.dart';

class StudentClassChatScreen extends StatefulWidget {
  final String subjectId;
  final String classId;
  final String subjectName;
  final String className;
  final String mentorId;
  final Color? color;

  const StudentClassChatScreen({
    super.key,
    required this.subjectId,
    required this.classId,
    required this.subjectName,
    required this.className,
    required this.mentorId,
    this.color,
  });

  @override
  State<StudentClassChatScreen> createState() => _StudentClassChatScreenState();
}

class _StudentClassChatScreenState extends State<StudentClassChatScreen> {
  late Future<Map<String, String>> _mentorInfoFuture;

  @override
  void initState() {
    super.initState();
    _mentorInfoFuture = _fetchMentorInfo();
  }

  Future<Map<String, String>> _fetchMentorInfo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('mentors').doc(widget.mentorId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? 'Unknown Mentor',
          'profileUrl': data['profileUrl'] ?? '',
        };
      } else {
        return {
          'name': 'Mentor Not Found',
          'profileUrl': '',
        };
      }
    } catch (e) {
      print('Error fetching mentor info: $e');
      return {
        'name': 'Error',
        'profileUrl': '',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = widget.color ?? Colors.teal;
    final isLight = appBarColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat With Mentor · ${widget.subjectName} - ${widget.className}'),
        backgroundColor: appBarColor,
        foregroundColor: textColor,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _mentorInfoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Failed to load mentor info.'));
          }

          final mentorName = snapshot.data!['name']!;
          final profileUrl = snapshot.data!['profileUrl']!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty ? const Icon(Icons.person, size: 28) : null,
                ),
                title: Text(
                  mentorName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                trailing: const Icon(Icons.chat_bubble_outline),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrivateChatScreen(
                        mentorId: widget.mentorId,
                        mentorName: mentorName,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
