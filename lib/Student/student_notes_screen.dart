import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentNotesPage extends StatefulWidget {
  const StudentNotesPage({super.key});

  @override
  State<StudentNotesPage> createState() => _StudentNotesPageState();
}

class _StudentNotesPageState extends State<StudentNotesPage> {
  final _savedRef = FirebaseFirestore.instance.collection('savedResources');
  final currentUser = FirebaseAuth.instance.currentUser;

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${date.month}/${date.day}/${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String subjectName = args['subjectName'];
    final String className = args['className'];
    final Color color = args['color'] ?? Colors.indigo;

    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _savedRef
            .where('studentId', isEqualTo: currentUser?.uid)
            .where('subjectName', isEqualTo: subjectName)
            .where('className', isEqualTo: className)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading notes'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No saved notes yet.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled Resource';
              final timestampRaw = data['timestamp'];
              String? formattedTime;

              if (timestampRaw is Timestamp) {
                formattedTime = _formatTimestamp(timestampRaw);
              } else {
                formattedTime = null;
              }

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: Icon(Icons.note_alt_outlined, color: Colors.orange[600], size: 32),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: formattedTime != null
                      ? Text('Saved on $formattedTime', style: const TextStyle(color: Colors.grey))
                      : null,
                  onTap: () async {
                    final resourceId = data['resourceId'];
                    final resourceSnap = await FirebaseFirestore.instance
                        .collection('resources')
                        .doc(resourceId)
                        .get();

                    if (!resourceSnap.exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Original resource not found.")),
                      );
                      return;
                    }

                    final fullData = resourceSnap.data()!;
                    fullData['resourceId'] = resourceId;

                    Navigator.pushNamed(
                      context,
                      '/studentNoteDetail',
                      arguments: {
                        'docId': doc.id,
                        'data': fullData,
                        'color': color,
                      },
                    );
                  },

                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
