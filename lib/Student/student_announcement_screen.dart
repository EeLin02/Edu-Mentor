import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentAnnouncementScreen extends StatefulWidget {
  const StudentAnnouncementScreen({super.key});

  @override
  State<StudentAnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<StudentAnnouncementScreen> {
  final _announcementsCollection = FirebaseFirestore.instance.collection('announcements');

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${_monthString(date.month)} ${date.day}, ${date.year} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}";
  }

  String _monthString(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String subjectName = args['subjectName'];
    final String className = args['className'];
    final Color color = args['color'] ?? Colors.teal;
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Announcements · $subjectName - $className', style: TextStyle(color: textColor)),
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _announcementsCollection
            .where('subjectName', isEqualTo: subjectName)
            .where('className', isEqualTo: className)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading announcements'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text('No announcements yet.'));
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: Icon(Icons.campaign, color: Colors.teal[300], size: 32),
                  title: Text(
                    data['title'] ?? 'No Title',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
