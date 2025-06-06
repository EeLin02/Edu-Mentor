import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageClassesScreen extends StatefulWidget {
  @override
  _ManageClassesScreenState createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  final TextEditingController classController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String? selectedDepartment;
  String? selectedSubject;
  String searchQuery = "";

  String _getName(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('name') ? data['name'] as String : 'Unnamed';
  }


  void _editClass(QueryDocumentSnapshot doc) {
    final currentName = _getName(doc);
    final editController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Class"),
        content: TextField(controller: editController),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
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

  @override
  void dispose() {
    classController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Delete this class?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Delete")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Classes")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Department dropdown
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('departments').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text("No departments found.");
                }

                return DropdownButton<String>(
                  value: selectedDepartment,
                  hint: Text("Select Department"),
                  isExpanded: true,
                  items: snapshot.data!.docs.map((doc) {
                    final name = _getName(doc);
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDepartment = value;
                      selectedSubject = null; // reset subject when department changes
                    });
                  },
                );
              },
            ),

            SizedBox(height: 12),

            // Subject dropdown
            if (selectedDepartment != null)
              StreamBuilder<QuerySnapshot>(
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
                    return Text("No subjects found for this department.");
                  }

                  return DropdownButton<String>(
                    value: selectedSubject,
                    hint: Text("Select Subject"),
                    isExpanded: true,
                    items: snapshot.data!.docs.map((doc) {
                      final name = _getName(doc);
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSubject = value;
                      });
                    },
                  );
                },
              ),

            SizedBox(height: 12),

            // Class name input
            TextField(
              controller: classController,
              decoration: InputDecoration(
                labelText: "Class Name",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                final name = classController.text.trim();
                if (name.isNotEmpty && selectedDepartment != null && selectedSubject != null) {
                  final newClassRef = await FirebaseFirestore.instance
                      .collection('departments')
                      .doc(selectedDepartment)
                      .collection('subjects')
                      .doc(selectedSubject)
                      .collection('classes')
                      .add({'name': name});

                  await newClassRef.update({'classId': newClassRef.id});
                  classController.clear();
                }
              },
              child: Text("Add Class"),
            ),

            SizedBox(height: 16),

            // Search bar
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Classes",
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

            // Class list with search filter
            if (selectedDepartment != null && selectedSubject != null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('departments')
                      .doc(selectedDepartment)
                      .collection('subjects')
                      .doc(selectedSubject)
                      .collection('classes')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text("No classes found."));
                    }

                    final filteredClasses = snapshot.data!.docs.where((doc) {
                      final name = _getName(doc).toLowerCase();
                      return name.contains(searchQuery);
                    }).toList();

                    if (filteredClasses.isEmpty) {
                      return Center(child: Text("No classes match your search."));
                    }

                    return ListView(
                      children: filteredClasses.map((doc) {
                        final name = _getName(doc);

                        return ListTile(
                          title: Text(name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editClass(doc),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirmed = await _showDeleteConfirmDialog();
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
