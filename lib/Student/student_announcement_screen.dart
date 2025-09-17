import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentAnnouncementScreen extends StatelessWidget {
  const StudentAnnouncementScreen({super.key});

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${_monthString(date.month)} ${date.day}, ${date.year} "
        "${_twoDigits(date.hour)}:${_twoDigits(date.minute)}";
  }

  String _monthString(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final String? announcementId = args?['announcementId']; // from notification
    final String? subjectName = args?['subjectName'];
    final String? className = args?['className'];
    final Color color = (args?['color'] ?? Colors.teal) as Color;
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    // 🔹 Case 1: Notification deep link → open one announcement
    if (announcementId != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Student Announcements"),
          backgroundColor: color,
          foregroundColor: textColor,
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('announcements')
              .doc(announcementId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("Announcement not found"));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? 'No Title',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (data['timestamp'] != null)
                    Text(
                      "Posted on ${_formatTimestamp(data['timestamp'])}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const Divider(height: 24),
                  Text(data['content'] ?? 'No Content',
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          },
        ),
      );
    }

    // 🔹 Case 2: Normal navigation → show list of announcements
    if (subjectName == null || className == null) {
      return const Scaffold(
        body: Center(child: Text("Missing subject or class info")),
      );
    }

    final announcementsCollection =
    FirebaseFirestore.instance.collection('announcements');

    return Scaffold(
      appBar: AppBar(
        title: Text('Announcements · $subjectName - $className',
            style: TextStyle(color: textColor)),
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: announcementsCollection
            .where('subjectName', isEqualTo: subjectName)
            .where('className', isEqualTo: className)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading announcements'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data()! as Map<String, dynamic>;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  leading:
                  Icon(Icons.campaign, color: Colors.teal[300], size: 32),
                  title: Text(
                    data['title'] ?? 'No Title',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: data['timestamp'] != null
                      ? Text(
                    'Posted on ${_formatTimestamp(data['timestamp'])}',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                      : null,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/previewAnnouncement',
                      arguments: {
                        'docid': doc.id,
                        'data': data,
                        'color': color,
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
