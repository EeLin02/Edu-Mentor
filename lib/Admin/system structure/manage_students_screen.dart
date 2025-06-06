import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageStudentsMultiAssignScreen extends StatefulWidget {
  @override
  _ManageStudentsMultiAssignScreenState createState() =>
      _ManageStudentsMultiAssignScreenState();
}

class _ManageStudentsMultiAssignScreenState
    extends State<ManageStudentsMultiAssignScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<QueryDocumentSnapshot> departments = [];
  List<QueryDocumentSnapshot> allStudents = [];

  Set<String> selectedStudentIds = {};
  String? selectedDepartmentIdForAssign;
  String filterQuery = '';
  String? filterDepartmentId;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadStudents();
  }

  Future<void> _loadDepartments() async {
    final snapshot =
    await _firestore.collection('departments').orderBy('name').get();
    setState(() {
      departments = snapshot.docs;
    });
  }

  Future<void> _loadStudents() async {
    final snapshot =
    await _firestore.collection('students').orderBy('name').get();
    setState(() {
      allStudents = snapshot.docs;
    });
  }

  List<QueryDocumentSnapshot> get _unassignedStudents =>
      allStudents.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final deptId = data['departmentId'] as String?;
        return deptId == null && name.contains(filterQuery.toLowerCase());
      }).toList();

  List<QueryDocumentSnapshot> get _assignedStudents =>
      allStudents.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final deptId = data['departmentId'] as String?;
        final matchesSearch = name.contains(filterQuery.toLowerCase());
        final matchesDept =
        (filterDepartmentId == null || filterDepartmentId == '')
            ? true
            : deptId == filterDepartmentId;
        return deptId != null && matchesSearch && matchesDept;
      }).toList();

  Future<void> _saveAssignments() async {
    if (selectedDepartmentIdForAssign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select a department.")));
      return;
    }
    if (selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No students selected.")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    final batch = _firestore.batch();
    for (var id in selectedStudentIds) {
      final docRef = _firestore.collection('students').doc(id);
      batch.update(docRef, {'departmentId': selectedDepartmentIdForAssign});
    }
    await batch.commit();

    setState(() {
      isLoading = false;
      selectedStudentIds.clear();
      selectedDepartmentIdForAssign = null;
    });

    await _loadStudents();

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Assignments updated successfully.")));
  }

  Future<void> _editStudentDepartment(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String? currentDept = data['departmentId'];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Edit Student Department'),
            content: DropdownButtonFormField<String>(
              value: currentDept,
              decoration: InputDecoration(labelText: 'Department'),
              items: [
                DropdownMenuItem(value: null, child: Text("No department")),
                ...departments.map((dept) {
                  final deptData = dept.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: dept.id,
                    child: Text(deptData['name'] ?? 'Unnamed'),
                  );
                }),
              ],
              onChanged: (val) => setStateDialog(() => currentDept = val),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _firestore
                      .collection('students')
                      .doc(doc.id)
                      .update({'departmentId': currentDept});
                  Navigator.pop(context);
                  await _loadStudents();
                },
                child: Text("Save"),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteStudent(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete Student"),
        content: Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection('students').doc(id).delete();
      selectedStudentIds.remove(id);
      await _loadStudents();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted successfully")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Manage Student Departments"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Assign Department"),
              Tab(text: "Preview Assigned"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Unassigned students
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDepartmentIdForAssign,
                    decoration: InputDecoration(
                      labelText: "Assign to Department",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text("Select department")),
                      ...departments.map((dept) {
                        final deptData = dept.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: dept.id,
                          child: Text(deptData['name'] ?? 'Unnamed'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => selectedDepartmentIdForAssign = val);
                    },
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Search students",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => filterQuery = val),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                          onPressed: () => setState(() {
                            selectedStudentIds =
                                _unassignedStudents.map((doc) => doc.id).toSet();
                          }),
                          child: Text("Select All")),
                      SizedBox(width: 12),
                      ElevatedButton(
                          onPressed: () => setState(() {
                            selectedStudentIds.clear();
                          }),
                          child: Text("Deselect All")),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _unassignedStudents.isEmpty
                        ? Center(child: Text("No unassigned students"))
                        : ListView.builder(
                      itemCount: _unassignedStudents.length,
                      itemBuilder: (_, index) {
                        final doc = _unassignedStudents[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: Checkbox(
                            value: selectedStudentIds.contains(doc.id),
                            onChanged: (_) => setState(() {
                              if (selectedStudentIds.contains(doc.id)) {
                                selectedStudentIds.remove(doc.id);
                              } else {
                                selectedStudentIds.add(doc.id);
                              }
                            }),
                          ),
                          title: Text(data['name'] ?? 'Unnamed'),
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: selectedStudentIds.isEmpty || isLoading
                        ? null
                        : _saveAssignments,
                    child: Text("Save Assignments"),
                  )
                ],
              ),
            ),

            // Tab 2: Preview assigned students
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: filterDepartmentId,
                    decoration: InputDecoration(
                      labelText: "Filter by Department",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text("All Departments")),
                      ...departments.map((dept) {
                        final deptData = dept.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: dept.id,
                          child: Text(deptData['name'] ?? 'Unnamed'),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => filterDepartmentId = val),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Search assigned students",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => filterQuery = val),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: _assignedStudents.isEmpty
                        ? Center(child: Text("No assigned students"))
                        : ListView.builder(
                      itemCount: _assignedStudents.length,
                      itemBuilder: (_, index) {
                        final doc = _assignedStudents[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final deptId = data['departmentId'];
                        String deptName = 'Unknown';
                        try {
                          final dept = departments.firstWhere((d) => d.id == deptId);
                          deptName = (dept.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
                        } catch (e) {
                          deptName = 'Unknown';
                        }


                        return ListTile(
                          title: Text(data['name'] ?? 'Unnamed'),
                          subtitle: Text("Department: $deptName"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editStudentDepartment(doc),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteStudent(doc.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
