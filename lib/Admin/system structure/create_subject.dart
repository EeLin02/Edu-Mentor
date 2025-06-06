import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSubjectsScreen extends StatefulWidget {
  @override
  _ManageSubjectsScreenState createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends State<ManageSubjectsScreen> {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String? selectedDepartment;

  String _getFieldName(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('name') ? data['name'] as String : 'Unnamed Subject';
  }

  void _showEditDialog(String subjectId, String currentName) {
    final TextEditingController editController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Subject"),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            labelText: "Subject Name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('departments')
                    .doc(selectedDepartment)
                    .collection('subjects')
                    .doc(subjectId)
                    .update({'name': newName});
                Navigator.pop(context);
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    subjectController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Subjects")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Department Dropdown
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('departments').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text("No departments available.");
                }

                return DropdownButton<String>(
                  value: selectedDepartment,
                  hint: Text("Select a Department"),
                  isExpanded: true,
                  items: snapshot.data!.docs.map((doc) {
                    final name = (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed Department';
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDepartment = value;
                    });
                  },
                );
              },
            ),
            SizedBox(height: 12),

            // Subject Name Input
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                labelText: "Subject Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                final name = subjectController.text.trim();
                if (name.isNotEmpty && selectedDepartment != null) {
                  final newSubjectRef = await FirebaseFirestore.instance
                      .collection('departments')
                      .doc(selectedDepartment)
                      .collection('subjects')
                      .add({'name': name});

                  await newSubjectRef.update({'subjectId': newSubjectRef.id});

                  subjectController.clear();
                }
              },
              child: Text("Add Subject"),
            ),
            SizedBox(height: 16),

            // Search Field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Subject",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16),

            // Subject List
            if (selectedDepartment != null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('departments')
                      .doc(selectedDepartment)
                      .collection('subjects')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text("No subjects found."));
                    }

                    print("Subjects count from Firestore: ${snapshot.data!.docs.length}");

                    final subjects = snapshot.data!.docs.where((doc) {
                      final name = _getFieldName(doc).toLowerCase();
                      final query = searchController.text.toLowerCase();
                      return name.contains(query);
                    }).toList();

                    print("Filtered subjects count: ${subjects.length}");

                    if (subjects.isEmpty) {
                      return Center(child: Text("No subjects match the search."));
                    }

                    return ListView.builder(
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        final name = _getFieldName(subject);

                        return ListTile(
                          title: Text(name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditDialog(subject.id, name),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text("Confirm Delete"),
                                      content: Text("Delete this subject?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await FirebaseFirestore.instance
                                        .collection('departments')
                                        .doc(selectedDepartment)
                                        .collection('subjects')
                                        .doc(subject.id)
                                        .delete();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
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