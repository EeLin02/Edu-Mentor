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
        title: Text('Delete Resource'),
        content: Text('Are you sure you want to delete this resource?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await _resourcesCollection.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resource deleted')));
    }
  }

  void _editResource(DocumentSnapshot doc, String subjectName, String className, Color color) {
    final data = doc.data() as Map<String, dynamic>;

    Navigator.pushNamed(
      context,
      '/createResource',
      arguments: {
        'subjectName': subjectName,
        'className': className,
        'resourceId': doc.id,
        'title': data['title'],
        'description' :data['description'],
        'category': data['category'],
        'links': List<String>.from(data['links'] ?? []),
        'color': color,
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String subjectName = args['subjectName'];
    final String className = args['className'];
    final Color color = args['color'] ?? Colors.indigo;

    // Dynamic text color based on background color brightness
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resources · $subjectName - $className', style: TextStyle(color: textColor)),
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _resourcesCollection
            .where('subjectName', isEqualTo: subjectName)
            .where('className', isEqualTo: className)
            .orderBy('category')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading resources'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No resources available.'));
          }

          // Group resources by category
          final Map<String, List<QueryDocumentSnapshot>> categorizedResources = {};
          for (var doc in docs) {
            final data = doc.data()! as Map<String, dynamic>;
            final category = data['category'] ?? 'Uncategorized';
            categorizedResources.putIfAbsent(category, () => []).add(doc);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: categorizedResources.entries.map((entry) {
              final category = entry.key;
              final resources = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...resources.map((doc) {
                    final data = doc.data()! as Map<String, dynamic>;
                    final title = data['title'] ?? 'Untitled Resource';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Icon(Icons.library_books, color: Colors.teal[300], size: 32),
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
                              onPressed: () => _editResource(doc, subjectName, className, color),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteResource(doc.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/PreviewResourceScreen',
                            arguments: {'docid': doc.id, 'data': data,'color': color,},
                          );
                        },
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ],
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
              'subjectName': subjectName,
              'className': className,
              'color': color,
            },
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add new resource',
      ),
    );
  }
}
