import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentResourceScreen extends StatefulWidget {
  const StudentResourceScreen({super.key});

  @override
  State<StudentResourceScreen> createState() => _StudentResourceScreenState();
}

class _StudentResourceScreenState extends State<StudentResourceScreen> {
  final _resourcesCollection = FirebaseFirestore.instance.collection('resources');
  final _savedCollection = FirebaseFirestore.instance.collection('savedResources');
  final currentUser = FirebaseAuth.instance.currentUser;

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${_monthString(date.month)} ${date.day}, ${date.year} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}";
  }

  String _monthString(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<void> _toggleBookmark(String resourceId, Map<String, dynamic> resourceData) async {
    if (currentUser == null) return;

    final query = await _savedCollection
        .where('studentId', isEqualTo: currentUser!.uid)
        .where('resourceId', isEqualTo: resourceId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete(); // Unsave
    } else {
      await _savedCollection.add({
        'studentId': currentUser!.uid,
        'resourceId': resourceId,
        'title': resourceData['title'] ?? '',
        'subjectName': resourceData['subjectName'] ?? '',
        'className': resourceData['className'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {}); // Refresh
  }

  Future<bool> _isBookmarked(String resourceId) async {
    if (currentUser == null) return false;

    final snapshot = await _savedCollection
        .where('studentId', isEqualTo: currentUser!.uid)
        .where('resourceId', isEqualTo: resourceId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
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
          if (snapshot.hasError) return const Center(child: Text('Error loading resources'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No resources available.'));

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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  ...resources.map((doc) {
                    final data = doc.data()! as Map<String, dynamic>;

                    return FutureBuilder<bool>(
                      future: _isBookmarked(doc.id),
                      builder: (context, bookmarkSnapshot) {
                        final isBookmarked = bookmarkSnapshot.data ?? false;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: Icon(Icons.library_books, color: Colors.teal[300], size: 32),
                            title: Text(
                              data['title'] ?? 'No Title',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: data['timestamp'] != null
                                ? Text(
                              'Posted on ${_formatTimestamp(data['timestamp'])}',
                              style: TextStyle(color: Colors.grey[600]),
                            )
                                : null,
                            trailing: IconButton(
                              icon: Icon(
                                isBookmarked ? Icons.star : Icons.star_border,
                                color: isBookmarked ? Colors.amber : Colors.grey,
                              ),
                              onPressed: () => _toggleBookmark(doc.id, data),
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/PreviewResourceScreen',
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
                  }).toList(),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
