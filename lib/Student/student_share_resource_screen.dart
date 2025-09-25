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
    return "${_monthString(date.month)} ${date.day}, ${date.year} "
        "${_twoDigits(date.hour)}:${_twoDigits(date.minute)}";
  }

  String _monthString(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
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
        'sectionName': resourceData['sectionName'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {}); // Refresh UI
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
    final String sectionName = args['sectionName'];
    final Color color = args['color'] ?? Colors.indigo;

    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resources · $subjectName - $sectionName',
            style: TextStyle(color: textColor)),
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
          if (docs.isEmpty) return const Center(child: Text('No resources available.'));

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
                      Text(category,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  children: resources.map((doc) {
                    final data = doc.data()! as Map<String, dynamic>;

                    return FutureBuilder<bool>(
                      future: _isBookmarked(doc.id),
                      builder: (context, bookmarkSnapshot) {
                        final isBookmarked = bookmarkSnapshot.data ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.library_books,
                                color: Colors.blueGrey),
                            title: Text(
                              data['title'] ?? 'No Title',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            subtitle: data['timestamp'] != null
                                ? Text(
                              'Posted on ${_formatTimestamp(data['timestamp'])}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54),
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
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
