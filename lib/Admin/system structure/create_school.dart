import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSchoolsScreen extends StatefulWidget {
  @override
  _ManageSchoolsScreenState createState() => _ManageSchoolsScreenState();
}

class _ManageSchoolsScreenState extends State<ManageSchoolsScreen> {
  final TextEditingController schoolController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  String _getName(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('name')
        ? data['name'] as String
        : 'Unnamed';
  }

  void _editSchool(QueryDocumentSnapshot doc) {
    final currentName = _getName(doc);
    final editController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit School"),
        content: TextField(controller: editController),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isNotEmpty) {
                await doc.reference.update({'name': newName});
                Navigator.pop(context);
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Delete this school?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Delete")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    schoolController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Schools")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input field
            TextField(
              controller: schoolController,
              decoration: InputDecoration(
                labelText: "School Name",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 12),

            // Add button
            ElevatedButton(
              onPressed: () async {
                final name = schoolController.text.trim();
                if (name.isNotEmpty) {
                  final newSchoolRef = await FirebaseFirestore.instance
                      .collection('schools')
                      .add({'name': name});

                  await newSchoolRef.update({'schoolId': newSchoolRef.id});
                  schoolController.clear();
                }
              },
              child: Text("Add School"),
            ),

            SizedBox(height: 16),

            // Search bar
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Schools",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),

            SizedBox(height: 12),

            // School list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('schools')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No schools found."));
                  }

                  final filteredSchools = snapshot.data!.docs.where((doc) {
                    final name = _getName(doc).toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  if (filteredSchools.isEmpty) {
                    return Center(child: Text("No schools match your search."));
                  }

                  return ListView(
                    children: filteredSchools.map((doc) {
                      final name = _getName(doc);

                      return ListTile(
                        title: Text(name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editSchool(doc),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmed =
                                await _showDeleteConfirmDialog();
                                if (confirmed == true) {
                                  await doc.reference.delete();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
