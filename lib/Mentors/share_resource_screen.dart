import 'package:flutter/material.dart';

class ShareResourcesScreen extends StatelessWidget {
  final String subjectName;
  final String className;

  const ShareResourcesScreen({
    Key? key,
    required this.subjectName,
    required this.className,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController _linkController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text('Resources · $subjectName - $className'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Share a resource link", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: "Paste Google Drive / link",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final link = _linkController.text.trim();
                if (link.isNotEmpty) {
                  // Upload to Firestore
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Resource shared")),
                  );
                }
              },
              icon: Icon(Icons.link),
              label: Text("Share"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            ),
          ],
        ),
      ),
    );
  }
}
