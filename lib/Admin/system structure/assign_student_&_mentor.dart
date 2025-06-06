import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_mentor_assignment_screen.dart';
import 'edit_student_assignment_screen.dart';

class ManageStudentsAndMentorsScreen extends StatefulWidget {
  @override
  _ManageStudentsAndMentorsScreenState createState() => _ManageStudentsAndMentorsScreenState();
}

class _ManageStudentsAndMentorsScreenState extends State<ManageStudentsAndMentorsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Students and Mentors'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Mentor Assignment'),
            Tab(text: 'Student Enrollment'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MentorAssignmentPage(firestore: _firestore),
          StudentEnrollmentPage(firestore: _firestore),
        ],
      ),
    );
  }
}

class MentorAssignmentPage extends StatefulWidget {
  final FirebaseFirestore firestore;

  const MentorAssignmentPage({Key? key, required this.firestore}) : super(key: key);

  @override
  _MentorAssignmentPageState createState() => _MentorAssignmentPageState();
}

class _MentorAssignmentPageState extends State<MentorAssignmentPage> {
  String? selectedDepartmentId;
  String? selectedSubjectId;
  String? selectedMentorId;
  Set<String> selectedClassIds = {};

  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // Department Dropdown
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('departments').orderBy('name').snapshots(),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final departments = snapshot.data!.docs;
              return DropdownButton<String>(
                value: selectedDepartmentId,
                hint: Text('Select Department'),
                isExpanded: true,
                items: departments.map((doc) {
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedDepartmentId = val;
                    selectedSubjectId = null;
                    selectedMentorId = null;
                    selectedClassIds.clear();
                  });
                },
              );
            },
          ),

          SizedBox(height: 16),

          // Subject Dropdown
          if (selectedDepartmentId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('departments')
                  .doc(selectedDepartmentId)
                  .collection('subjects')
                  .orderBy('name')
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return DropdownButton<String>(
                  value: selectedSubjectId,
                  hint: Text('Select Subject'),
                  isExpanded: true,
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedSubjectId = val;
                      selectedClassIds.clear();
                    });
                  },
                );
              },
            ),

          SizedBox(height: 16),

          // Mentor Dropdown
          if (selectedDepartmentId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('mentors')
                  .where('departmentId', arrayContains: selectedDepartmentId)
                  .orderBy('name')
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return DropdownButton<String>(
                  value: selectedMentorId,
                  hint: Text('Select Mentor'),
                  isExpanded: true,
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedMentorId = val),
                );
              },
            ),

          SizedBox(height: 16),

          // Class checkboxes
          if (selectedDepartmentId != null && selectedSubjectId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('departments')
                  .doc(selectedDepartmentId)
                  .collection('subjects')
                  .doc(selectedSubjectId)
                  .collection('classes')
                  .orderBy('name')
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snapshot.data!.docs.map((doc) {
                    return CheckboxListTile(
                      title: Text(doc['name']),
                      value: selectedClassIds.contains(doc.id),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedClassIds.add(doc.id);
                          } else {
                            selectedClassIds.remove(doc.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),

          SizedBox(height: 24),

          ElevatedButton(
            onPressed: assignMentor,
            child: Text("Assign Mentor"),
          ),

          SizedBox(height: 32),

          // Existing Assignments
          Text(
            "Existing Mentor Assignments",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),

          if (selectedDepartmentId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('subjectMentors')
                  .where('departmentId', isEqualTo: selectedDepartmentId)
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No assignments found.'),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return FutureBuilder<List<String>>(
                      future: _getAssignmentDetails(
                        departmentId: data['departmentId'],
                        subjectId: data['subjectId'],
                        classIds: List<String>.from(data['classIds']),
                        mentorId: data['mentorId'],
                      ),
                      builder: (ctx, detailSnapshot) {
                        if (!detailSnapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final details = detailSnapshot.data!;
                        final departmentName = details[0];
                        final subjectName = details[1];
                        final mentorName = details[2];
                        final classNames = details[3];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subjectName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: Colors.blueAccent),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditAssignmentScreen(
                                              firestore: firestore,
                                              assignmentId: doc.id,
                                              currentData: data,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text('Mentor: $mentorName'),
                                Text('Department: $departmentName'),
                                Text('Classes: $classNames'),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<List<String>> _getAssignmentDetails({
    required String departmentId,
    required String subjectId,
    required List<String> classIds,
    required String mentorId,
  }) async {
    final departmentSnap = await widget.firestore.collection('departments').doc(departmentId).get();
    final subjectSnap = await widget.firestore
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .get();
    final mentorSnap = await widget.firestore.collection('mentors').doc(mentorId).get();

    final classSnaps = await Future.wait(classIds.map((cid) {
      return widget.firestore
          .collection('departments')
          .doc(departmentId)
          .collection('subjects')
          .doc(subjectId)
          .collection('classes')
          .doc(cid)
          .get();
    }));

    final classNames = classSnaps.map((doc) => doc['name']).join(', ');

    return [
      departmentSnap['name'],
      subjectSnap['name'],
      mentorSnap['name'],
      classNames,
    ];
  }

  Future<void> assignMentor() async {
    if (selectedDepartmentId == null || selectedSubjectId == null || selectedMentorId == null || selectedClassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }

    // Check if this subject already has a mentor assigned in this department
    final existing = await widget.firestore.collection('subjectMentors')
        .where('departmentId', isEqualTo: selectedDepartmentId)
        .where('subjectId', isEqualTo: selectedSubjectId)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This subject already has a mentor assigned. Please edit instead of assigning a new one.')),
      );
      return;
    }

    // Proceed to assign if no conflict
    await widget.firestore.collection('subjectMentors').add({
      'departmentId': selectedDepartmentId,
      'subjectId': selectedSubjectId,
      'mentorId': selectedMentorId,
      'classIds': selectedClassIds.toList(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mentor assigned successfully')));
    setState(() {
      selectedSubjectId = null;
      selectedMentorId = null;
      selectedClassIds.clear();
    });
  }

}


class StudentEnrollmentPage extends StatefulWidget {
  final FirebaseFirestore firestore;
  const StudentEnrollmentPage({required this.firestore});

  @override
  _StudentEnrollmentPageState createState() => _StudentEnrollmentPageState();
}

class _StudentEnrollmentPageState extends State<StudentEnrollmentPage> {
  String? selectedDepartmentId;
  String? selectedSubjectId;
  String? selectedClassId;
  Set<String> selectedStudentIds = {};
  String searchQuery = '';
  Map<String, bool> studentEnrolledMap = {};

  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // Department Dropdown
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('departments').orderBy('name').snapshots(),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final departments = snapshot.data!.docs;
              return DropdownButton<String>(
                value: selectedDepartmentId,
                hint: Text('Select Department'),
                isExpanded: true,
                items: departments.map((doc) {
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedDepartmentId = val;
                    selectedSubjectId = null;
                    selectedClassId = null;
                    selectedStudentIds.clear();
                    studentEnrolledMap.clear();
                  });
                },
              );
            },
          ),

          SizedBox(height: 16),

          // Subject Dropdown
          if (selectedDepartmentId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('departments')
                  .doc(selectedDepartmentId)
                  .collection('subjects')
                  .orderBy('name')
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final subjects = snapshot.data!.docs;
                return DropdownButton<String>(
                  value: selectedSubjectId,
                  hint: Text('Select Subject'),
                  isExpanded: true,
                  items: subjects.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedSubjectId = val;
                      selectedClassId = null;
                      selectedStudentIds.clear();
                      studentEnrolledMap.clear();
                    });
                  },
                );
              },
            ),

          SizedBox(height: 16),

          // Class Dropdown
          if (selectedDepartmentId != null && selectedSubjectId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('departments')
                  .doc(selectedDepartmentId)
                  .collection('subjects')
                  .doc(selectedSubjectId)
                  .collection('classes')
                  .orderBy('name')
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final classes = snapshot.data!.docs;
                return DropdownButton<String>(
                  value: selectedClassId,
                  hint: Text('Select Class'),
                  isExpanded: true,
                  items: classes.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedClassId = val;
                      selectedStudentIds.clear();
                      studentEnrolledMap.clear();
                    });
                  },
                );
              },
            ),

          SizedBox(height: 16),

          // Search Field
          if (selectedDepartmentId != null)
            TextField(
              decoration: InputDecoration(
                hintText: 'Search students',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),

          SizedBox(height: 12),

          // Student Selection List
          if (selectedDepartmentId != null && selectedSubjectId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('students')
                  .where('departmentId', isEqualTo: selectedDepartmentId)
                  .orderBy('name')
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final students = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] ?? '').toLowerCase();
                  return searchQuery.isEmpty || name.contains(searchQuery);
                }).toList();

                if (students.isEmpty) return Text('No students found');

                return Column(
                  children: students.map((doc) {
                    final studentId = doc.id;
                    final isEnrolled = studentEnrolledMap[studentId];
                    if (isEnrolled == null && selectedSubjectId != null) {
                      _checkStudentEnrollment(studentId, selectedSubjectId!);
                    }
                    final isSelected = selectedStudentIds.contains(studentId);

                    return CheckboxListTile(
                      title: Text(doc['name']),
                      value: isSelected && isEnrolled != true,
                      onChanged: isEnrolled == true
                          ? null
                          : (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedStudentIds.add(studentId);
                          } else {
                            selectedStudentIds.remove(studentId);
                          }
                        });
                      },
                      secondary: isEnrolled == true
                          ? Text('Enrolled', style: TextStyle(color: Colors.red))
                          : null,
                    );
                  }).toList(),
                );
              },
            ),

          SizedBox(height: 12),

          ElevatedButton(
            onPressed: saveEnrollment,
            child: Text('Save Enrollment'),
          ),

          SizedBox(height: 24),

          // Existing Enrollments Header & Group Edit Button
          if (selectedDepartmentId != null &&
              selectedSubjectId != null &&
              selectedClassId != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Existing Student Assignments",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditGroupEnrollmentScreen(
                          firestore: firestore,
                          departmentId: selectedDepartmentId!,
                          subjectId: selectedSubjectId!,
                          classId: selectedClassId!,
                        ),
                      ),
                    );
                    //Trigger rebuild on return
                    setState(() {
                      studentEnrolledMap.clear(); // Clear old enrollment status
                    });
                  },
                  icon: Icon(Icons.edit),
                  label: Text("Edit Group"),
                )
              ],
            ),

          // Existing Enrollments List
          if (selectedDepartmentId != null &&
              selectedSubjectId != null &&
              selectedClassId != null)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('subjectEnrollments')
                  .where('departmentId', isEqualTo: selectedDepartmentId)
                  .where('subjectId', isEqualTo: selectedSubjectId)
                  .where('classId', isEqualTo: selectedClassId)
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                if (docs.isEmpty)
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No existing student enrollments found.'),
                  );

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final studentId = data['studentId'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: firestore.collection('students').doc(studentId).get(),
                      builder: (ctx, studentSnapshot) {
                        if (!studentSnapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final studentData = studentSnapshot.data!;
                        final studentName = studentData['name'] ?? 'Unknown Student';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    studentName,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),

          SizedBox(height: 24),
        ],
      ),
    );
  }

  void _checkStudentEnrollment(String studentId, String subjectId) async {
    final snapshot = await widget.firestore
        .collection('subjectEnrollments')
        .where('studentId', isEqualTo: studentId)
        .where('subjectId', isEqualTo: subjectId)
        .get();

    if (mounted) {
      setState(() {
        studentEnrolledMap[studentId] = snapshot.docs.isNotEmpty;
      });
    }
  }

  void saveEnrollment() async {
    if (selectedDepartmentId == null ||
        selectedSubjectId == null ||
        selectedClassId == null) return;

    final batch = widget.firestore.batch();
    for (var studentId in selectedStudentIds) {
      final doc = widget.firestore.collection('subjectEnrollments').doc();
      batch.set(doc, {
        'studentId': studentId,
        'departmentId': selectedDepartmentId,
        'subjectId': selectedSubjectId,
        'classId': selectedClassId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Enrollment saved successfully'),
    ));

    setState(() {
      selectedStudentIds.clear();
      studentEnrolledMap.clear();
    });
  }
}