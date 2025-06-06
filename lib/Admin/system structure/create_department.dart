import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_mentors_screen.dart';
import 'manage_students_screen.dart';

class ManageDepartmentsScreen extends StatefulWidget {
  @override
  _ManageDepartmentsScreenState createState() => _ManageDepartmentsScreenState();
}

class _ManageDepartmentsScreenState extends State<ManageDepartmentsScreen> {
  final TextEditingController deptController = TextEditingController();
  String searchQuery = "";

  String _getDepartmentName(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('name') ? data['name'] as String : 'Unnamed';
  }

  void _editDepartment(QueryDocumentSnapshot doc) {
    final currentName = _getDepartmentName(doc);
    final editController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Department"),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            labelText: "Department Name",
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
    deptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Departments"),
        actions: [
          IconButton(
            icon: Icon(Icons.people),
            tooltip: "Manage Mentors",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ManageMentorsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.school),
            tooltip: "Manage Students",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ManageStudentsMultiAssignScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Add Department
            TextField(
              controller: deptController,
              decoration: InputDecoration(
                labelText: "Department Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final newDept = deptController.text.trim();
                if (newDept.isNotEmpty) {
                  final newDeptRef = await FirebaseFirestore.instance.collection('departments').add({
                    'name': newDept,
                  });

                  // Store the document ID inside the department (optional for internal linking)
                  await newDeptRef.update({
                    'departmentId': newDeptRef.id,
                  });

                  deptController.clear();
                }
              },
              child: Text("Add Department"),
            ),
            SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                labelText: "Search",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
            SizedBox(height: 16),

            // Department List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('departments').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No departments found."));
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final name = _getDepartmentName(doc);
                    return name.toLowerCase().contains(searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final name = _getDepartmentName(doc);

                      return ListTile(
                        title: Text(name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editDepartment(doc),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => doc.reference.delete(),
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