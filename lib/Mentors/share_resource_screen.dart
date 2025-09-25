import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class ResourceScreen extends StatefulWidget {
  const ResourceScreen({Key? key}) : super(key: key);

  @override
  State<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends State<ResourceScreen> {
  final _resourcesCollection = FirebaseFirestore.instance.collection('resources');

  void _deleteResource(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Resource'),
        content: const Text('Are you sure you want to delete this resource?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await _resourcesCollection.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource deleted')),
      );
    }
  }

  void _editResource(DocumentSnapshot doc, String subjectName, String sectionName, Color color) {
    final data = doc.data() as Map<String, dynamic>;

    Navigator.pushNamed(
      context,
      '/createResource',
      arguments: {
        'subjectId': data['subjectId'],   // include these too
        'sectionId': data['sectionId'],   // so editing works properly
        'subjectName': subjectName,
        'sectionName': sectionName,
        'resourceId': doc.id,
        'title': data['title'],
        'description': data['description'],
        'category': data['category'],
        'links': List<String>.from(data['externalLinks'] ?? []), // ✅ fixed
        'color': color,
      },
    );
  }


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

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String subjectName = args['subjectName'];
    final String sectionName = args['sectionName'];
    final Color color = args['color'] ?? Colors.indigo;

    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resources · $subjectName - $sectionName', style: TextStyle(color: textColor)),
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _resourcesCollection
            .where('subjectName', isEqualTo: subjectName)
            .where('sectionName', isEqualTo: sectionName)
            .orderBy('category')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading resources'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No resources available.'));
          }

          // Group resources by category
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (var doc in docs) {
            final data = doc.data()! as Map<String, dynamic>;
            final category = data['category'] ?? 'Uncategorized';
            grouped.putIfAbsent(category, () => []);
            grouped[category]!.add(doc);
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: grouped.entries.map((entry) {
              final category = entry.key;
              final resources = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  backgroundColor: Colors.grey[50],
                  collapsedBackgroundColor: Colors.grey[100],
                  title: Row(
                    children: [
                      const Icon(Icons.category, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  children: resources.map((doc) {
                    final data = doc.data()! as Map<String, dynamic>;
                    final title = data['title'] ?? 'Untitled Resource';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.library_books, color: Colors.blueGrey),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        subtitle: data['timestamp'] != null
                            ? Text(
                          'Posted on ${_formatTimestamp(data['timestamp'])}',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () => _editResource(doc, subjectName, sectionName, color),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteResource(doc.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/PreviewResourceScreen',
                            arguments: {'docid': doc.id, 'data': data, 'color': color},
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: color,
        foregroundColor: textColor,
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/createResource',
            arguments: {
              'subjectId': args['subjectId'],
              'sectionId': args['sectionId'],
              'subjectName': subjectName,
              'sectionName': sectionName,
              'color': color,
            },
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Add new resource',
      ),
    );
  }
}
