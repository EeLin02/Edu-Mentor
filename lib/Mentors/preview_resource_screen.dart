import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../file_preview_screen.dart'; //  import our new preview screen

class PreviewResourceScreen extends StatelessWidget {
  final String subjectId;

  const PreviewResourceScreen({Key? key, required this.subjectId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subjects')
            .doc(subjectId)
            .collection('resources')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.teal));
          }

          final resources = snapshot.data!.docs;

          if (resources.isEmpty) {
            return const Center(child: Text("No resources available."));
          }

          return ListView.builder(
            itemCount: resources.length,
            itemBuilder: (context, index) {
              final resource = resources[index];
              final fileName = resource['fileName'];
              final fileUrl = resource['fileUrl'];

              return ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.teal),
                title: Text(fileName),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FilePreviewScreen(fileUrl: fileUrl,
                        fileName: fileName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
