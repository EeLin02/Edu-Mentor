import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditGroupEnrollmentScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String departmentId;
  final String subjectId;
  final String classId;

  const EditGroupEnrollmentScreen({
    required this.firestore,
    required this.departmentId,
    required this.subjectId,
    required this.classId,
  });

  @override
  State<EditGroupEnrollmentScreen> createState() => _EditGroupEnrollmentScreenState();
}

class _EditGroupEnrollmentScreenState extends State<EditGroupEnrollmentScreen> {
  Set<String> selectedStudentIds = {};
  Map<String, String> enrollmentDocIds = {}; // studentId -> enrollment docId
  Set<String> lockedStudentIds = {}; // already enrolled in other class of this subject
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final firestore = widget.firestore;

    // Get all enrollments under the same subject
    final enrollmentsSnapshot = await firestore
        .collection('subjectEnrollments')
        .where('departmentId', isEqualTo: widget.departmentId)
        .where('subjectId', isEqualTo: widget.subjectId)
        .get();

    for (var doc in enrollmentsSnapshot.docs) {
      final data = doc.data();
      final studentId = data['studentId'];
      final classId = data['classId'];

      if (studentId != null) {
        if (classId == widget.classId) {
          selectedStudentIds.add(studentId);
          enrollmentDocIds[studentId] = doc.id;
        } else {
          lockedStudentIds.add(studentId); // enrolled in other class under same subject
        }
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveChanges() async {
    final firestore = widget.firestore;

    final allStudentsSnapshot = await firestore
        .collection('students')
        .where('departmentId', isEqualTo: widget.departmentId)
        .get();

    final batch = firestore.batch();

    for (var studentDoc in allStudentsSnapshot.docs) {
      final studentId = studentDoc.id;

      if (lockedStudentIds.contains(studentId)) continue;

      final isCurrentlyEnrolled = enrollmentDocIds.containsKey(studentId);
      final shouldBeEnrolled = selectedStudentIds.contains(studentId);

      if (!isCurrentlyEnrolled && shouldBeEnrolled) {
        final newDoc = firestore.collection('subjectEnrollments').doc();
        batch.set(newDoc, {
          'studentId': studentId,
          'departmentId': widget.departmentId,
          'subjectId': widget.subjectId,
          'classId': widget.classId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (isCurrentlyEnrolled && !shouldBeEnrolled) {
        final docId = enrollmentDocIds[studentId];
        if (docId != null) {
          batch.delete(firestore.collection('subjectEnrollments').doc(docId));
        }
      }
    }

    await batch.commit();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Edit Enrollments")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Edit Enrollments")),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .where('departmentId', isEqualTo: widget.departmentId)
            .orderBy('name')
            .snapshots(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final students = snapshot.data!.docs
              .where((doc) =>
          !lockedStudentIds.contains(doc.id) &&
              (doc['name']?.toString().toLowerCase() ?? '').contains(_searchKeyword))
              .toList();

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              Text(
                "Select students to enroll in this class",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by student name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchKeyword = value.trim().toLowerCase();
                  });
                },
              ),
              SizedBox(height: 16),
              if (students.isEmpty)
                Text("No matching students found."),
              ...students.map((doc) {
                final studentId = doc.id;
                final isSelected = selectedStudentIds.contains(studentId);
                return CheckboxListTile(
                  title: Text(doc['name'] ?? 'Unnamed'),
                  value: isSelected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selectedStudentIds.add(studentId);
                      } else {
                        selectedStudentIds.remove(studentId);
                      }
                    });
                  },
                );
              }).toList(),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveChanges,
                child: Text("Save Changes"),
              ),
            ],
          );
        },
      ),
    );
  }
}
