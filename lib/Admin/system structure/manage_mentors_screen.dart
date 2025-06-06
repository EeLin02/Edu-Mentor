import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class ManageMentorsScreen extends StatefulWidget {
  @override
  _ManageMentorsScreenState createState() => _ManageMentorsScreenState();
}

class _ManageMentorsScreenState extends State<ManageMentorsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<QueryDocumentSnapshot> departments = [];
  List<QueryDocumentSnapshot> allMentors = [];

  Set<String> selectedMentorIds = {};
  Set<String> selectedDepartmentIdsForAssign = {};
  String filterQuery = '';
  String? filterDepartmentId;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadMentors();
  }

  Future<void> _loadDepartments() async {
    final snapshot = await _firestore.collection('departments').orderBy('name').get();
    setState(() {
      departments = snapshot.docs;
    });
  }

  Future<void> _loadMentors() async {
    final snapshot = await _firestore.collection('mentors').orderBy('name').get();
    setState(() {
      allMentors = snapshot.docs;
    });
  }

  List<QueryDocumentSnapshot> get _unassignedMentors => allMentors.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString().toLowerCase();
    final deptIds = (data['departmentId'] as List<dynamic>?);
    final isUnassigned = deptIds == null || deptIds.isEmpty;
    return isUnassigned && name.contains(filterQuery.toLowerCase());
  }).toList();

  List<QueryDocumentSnapshot> get _assignedMentors => allMentors.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString().toLowerCase();
    final deptIds = (data['departmentId'] as List<dynamic>? ?? []);
    final matchesSearch = name.contains(filterQuery.toLowerCase());
    final matchesDept = (filterDepartmentId == null || filterDepartmentId == '')
        ? true
        : deptIds.contains(filterDepartmentId);
    return deptIds.isNotEmpty && matchesSearch && matchesDept;
  }).toList();

  Future<void> _saveAssignments() async {
    if (selectedDepartmentIdsForAssign.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select at least one department.")));
      return;
    }
    if (selectedMentorIds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("No mentors selected.")));
      return;
    }

    setState(() => isLoading = true);

    final batch = _firestore.batch();
    for (var id in selectedMentorIds) {
      final docRef = _firestore.collection('mentors').doc(id);
      final mentorDoc = allMentors.firstWhere((doc) => doc.id == id);
      final data = mentorDoc.data() as Map<String, dynamic>;
      final currentDeptIds = List<String>.from(data['departmentId'] ?? []);

      for (var deptId in selectedDepartmentIdsForAssign) {
        if (!currentDeptIds.contains(deptId)) {
          currentDeptIds.add(deptId);
        }
      }

      batch.update(docRef, {'departmentId': currentDeptIds});
    }

    await batch.commit();

    setState(() {
      isLoading = false;
      selectedMentorIds.clear();
      selectedDepartmentIdsForAssign.clear();
      filterQuery = '';
    });

    await _loadMentors();

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Mentor assignments updated successfully.")));
  }

  // Edit mentor departments with multi-select checkboxes
  Future<void> _editMentorDepartments(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    List<String> currentDeptIds = List<String>.from(data['departmentId'] ?? []);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Edit Mentor Departments'),
            content: Container(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: departments.map((dept) {
                  final deptData = dept.data() as Map<String, dynamic>;
                  final deptId = dept.id;
                  final deptName = deptData['name'] ?? 'Unnamed';
                  final isChecked = currentDeptIds.contains(deptId);

                  return CheckboxListTile(
                    title: Text(deptName),
                    value: isChecked,
                    onChanged: (val) {
                      setStateDialog(() {
                        if (val == true && !currentDeptIds.contains(deptId)) {
                          currentDeptIds.add(deptId);
                        } else if (val == false) {
                          currentDeptIds.remove(deptId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  await _firestore.collection('mentors').doc(doc.id).update({'departmentId': currentDeptIds});
                  Navigator.pop(context);
                  await _loadMentors();
                },
                child: Text("Save"),
              ),
            ],
          );
        });
      },
    );
  }

  // Remove one department from a mentor's department list
  Future<void> _removeDepartmentFromMentor(String mentorId, String deptId) async {
    final mentorDoc = allMentors.firstWhere((doc) => doc.id == mentorId);
    final data = mentorDoc.data() as Map<String, dynamic>;
    final currentDeptIds = List<String>.from(data['departmentId'] ?? []);

    currentDeptIds.remove(deptId);

    await _firestore.collection('mentors').doc(mentorId).update({'departmentId': currentDeptIds});
    await _loadMentors();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Removed department from mentor")),
    );
  }

  void _showMultiSelectDepartmentDialog() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        // Use local copy so changes in dialog don't immediately affect state
        Set<String> tempSelected = Set.from(selectedDepartmentIdsForAssign);
        return AlertDialog(
          title: Text("Select Departments"),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: departments.map((dept) {
                final name = (dept.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
                return StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return CheckboxListTile(
                      title: Text(name),
                      value: tempSelected.contains(dept.id),
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            tempSelected.add(dept.id);
                          } else {
                            tempSelected.remove(dept.id);
                          }
                        });
                      },
                    );
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempSelected),
              child: Text("Confirm"),
            )
          ],
        );
      },
    );

    if (selected != null) {
      setState(() => selectedDepartmentIdsForAssign = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Manage Mentors"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Assign Department"),
              Tab(text: "Preview Assigned"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Assign department(s) to unassigned mentors
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _showMultiSelectDepartmentDialog,
                        child: Text("Select Departments"),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedDepartmentIdsForAssign.isEmpty
                              ? "No department selected"
                              : "${selectedDepartmentIdsForAssign.length} selected",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Search mentors",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => filterQuery = val),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _unassignedMentors.isEmpty
                        ? Center(child: Text("No unassigned mentors"))
                        : ListView.builder(
                      itemCount: _unassignedMentors.length,
                      itemBuilder: (_, index) {
                        final doc = _unassignedMentors[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: Checkbox(
                            value: selectedMentorIds.contains(doc.id),
                            onChanged: (_) => setState(() {
                              if (selectedMentorIds.contains(doc.id)) {
                                selectedMentorIds.remove(doc.id);
                              } else {
                                selectedMentorIds.add(doc.id);
                              }
                            }),
                          ),
                          title: Text(data['name'] ?? 'Unnamed'),
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: selectedMentorIds.isEmpty || isLoading ? null : _saveAssignments,
                    child: Text("Save Assignments"),
                  )
                ],
              ),
            ),

            // Tab 2: Preview and manage assigned mentors
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
                        final name = (dept.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
                        return DropdownMenuItem(value: dept.id, child: Text(name));
                      }),
                    ],
                    onChanged: (val) => setState(() => filterDepartmentId = val),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Search mentors",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => filterQuery = val),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: _assignedMentors.isEmpty
                        ? Center(child: Text("No assigned mentors"))
                        : ListView.builder(
                      itemCount: _assignedMentors.length,
                      itemBuilder: (_, index) {
                        final doc = _assignedMentors[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final deptIds = (data['departmentId'] as List<dynamic>?) ?? [];

                        // Build chips for mentor departments
                        final deptChips = deptIds.map((id) {
                          final deptDoc = departments.firstWhereOrNull((d) => d.id == id);
                          final deptName = (deptDoc?.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Chip(
                              label: Text(deptName),
                              onDeleted: () async {
                                await _removeDepartmentFromMentor(doc.id, id);
                              },
                            ),
                          );
                        }).toList();

                        return ListTile(
                          title: Text(data['name'] ?? 'Unnamed'),
                          subtitle: Wrap(
                            children: deptChips,
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.edit),
                            tooltip: "Edit departments",
                            onPressed: () => _editMentorDepartments(doc),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
