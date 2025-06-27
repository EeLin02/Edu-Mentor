import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({Key? key}) : super(key: key);

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}


class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final _announcementsCollection = FirebaseFirestore.instance.collection('announcements');

  void _deleteAnnouncement(String docId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? 'unknown_user';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Announcement'),
        content: Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await _announcementsCollection.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Announcement deleted')));
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    // Example format: "Jun 11, 2025 14:32"
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


  void _editAnnouncement(DocumentSnapshot doc, String subjectName, String className, Color color) {

    final data = doc.data() as Map<String, dynamic>;
    print('External links: ${data['externalLinks']}');

    Navigator.pushNamed(
      context,
      '/createAnnouncement',
      arguments: {
        'subjectName': subjectName,
        'className': className,
        'announcementId': doc.id,
        'title': data['title'],
        'description': data['description'],
        'files': data['files'] ?? [],
        'externalLinks': List<String>.from(data['externalLinks'] ?? []), // 👈 updated
        'color': color,
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String subjectName = args['subjectName'];
    final String className = args['className'];
    final Color color = args['color'] ?? Colors.teal;
    // Compute text color based on background brightness
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Announcements · $subjectName - $className', style: TextStyle(color: textColor)),
        backgroundColor: color,
        foregroundColor: textColor, // Also set icon colors etc.
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: Icon(Icons.edit, color: Colors.blueGrey),
                        onPressed: () => _editAnnouncement(doc, subjectName, className, color),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteAnnouncement(doc.id),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/previewAnnouncement',
                      arguments: {'docid': doc.id, 'data': data,'color': color,},
                    );
                  },
                )

              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: color,
        foregroundColor: textColor,
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/createAnnouncement',
            arguments: {
              'subjectName': subjectName,
              'className': className,
              'color': color,
            },
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Create new announcement',
      ),
    );
  }
}
