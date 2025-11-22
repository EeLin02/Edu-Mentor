import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentNotesPage extends StatefulWidget {
  final String subjectId;
  final String sectionId;
  final String subjectName;
  final String sectionName;
  final Color color;

  const StudentNotesPage({
    super.key,
    required this.subjectId,
    required this.sectionId,
    required this.subjectName,
    required this.sectionName,
    required this.color,
  });

  @override
  State<StudentNotesPage> createState() => _StudentNotesPageState();
}

class _StudentNotesPageState extends State<StudentNotesPage> {
  final _savedRef = FirebaseFirestore.instance.collection('savedResources');
  final currentUser = FirebaseAuth.instance.currentUser;

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.subjectName} - Notes",
          style: TextStyle(color: textColor),
        ),
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _savedRef
            .where('studentId', isEqualTo: currentUser?.uid)
            .where('subjectId', isEqualTo: widget.subjectId)
            .where('sectionId', isEqualTo: widget.sectionId)
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
            return const Center(child: Text('No notes found for this subject section.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled Note';
              final resourceId = data['resourceId'];
              final timestamp = data['timestamp'] as Timestamp?;

              final formattedTime =
              timestamp != null ? _formatTimestamp(timestamp) : "No timestamp";

              return Card(
                elevation: 6, // ⬆ stronger shadow
                shadowColor: Colors.black.withOpacity(0.3), // soft dark shadow
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                color: Colors.white, //  solid white for contrast
                child: ListTile(
                  leading: Icon(Icons.note_alt_outlined, color: color, size: 32),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black, //  title in black
                    ),
                  ),
                  subtitle: Text(
                    "Saved on $formattedTime",
                    style: const TextStyle(
                      color: Colors.black54, //  readable grey text
                    ),
                  ),
                  onTap: () async {
                    if (resourceId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Resource ID missing.")),
                      );
                      return;
                    }

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

                    final fullData = resourceSnap.data()!..['resourceId'] = resourceId;

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
