import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnnouncementScreen extends StatefulWidget {
  final String subjectName;
  final String className;

  const AnnouncementScreen({
    Key? key,
    required this.subjectName,
    required this.className,
  }) : super(key: key);

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

  void _editAnnouncement(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    print('External links: ${data['externalLinks']}');

    Navigator.pushNamed(
      context,
      '/createAnnouncement',
      arguments: {
        'subjectName': widget.subjectName,
        'className': widget.className,
        'announcementId': doc.id,
        'title': data['title'],
        'description': data['description'],
        'files': data['files'] ?? [],
        'externalLinks': List<String>.from(data['externalLinks'] ?? []), // 👈 updated
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Announcements · ${widget.subjectName} - ${widget.className}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _announcementsCollection
            .where('subjectName', isEqualTo: widget.subjectName)
            .where('className', isEqualTo: widget.className)
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
                  subtitle: Text(
                    data['description'] ?? 'No Description',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: Icon(Icons.edit, color: Colors.blueGrey),
                        onPressed: () => _editAnnouncement(doc),
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
                      arguments: {'docid': doc.id, 'data': data},
                    );
                  },
                )

              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/createAnnouncement',
            arguments: {
              'subjectName': widget.subjectName,
              'className': widget.className,
            },
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Create new announcement',
      ),
    );
  }
}
