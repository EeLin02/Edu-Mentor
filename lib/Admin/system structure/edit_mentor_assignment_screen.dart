import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditAssignmentScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String assignmentId;
  final Map<String, dynamic> currentData;

  const EditAssignmentScreen({
    Key? key,
    required this.firestore,
    required this.assignmentId,
    required this.currentData,
  }) : super(key: key);

  @override
  _EditAssignmentScreenState createState() => _EditAssignmentScreenState();
}

class _EditAssignmentScreenState extends State<EditAssignmentScreen> {
  String? selectedDepartmentId;
  String? selectedSubjectId;
  String? selectedMentorId;
  Set<String> selectedClassIds = {};

  @override
  void initState() {
    super.initState();
    selectedDepartmentId = widget.currentData['departmentId'];
    selectedSubjectId = widget.currentData['subjectId'];
    selectedMentorId = widget.currentData['mentorId'];
    selectedClassIds = Set<String>.from(widget.currentData['classIds']);
  }

  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Assignment'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: confirmDeleteAssignment,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Edit Department"),
            StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('departments').orderBy('name').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return CircularProgressIndicator();
                return DropdownButton<String>(
                  value: selectedDepartmentId,
                  hint: Text("Select Department"),
                  isExpanded: true,
                  items: snap.data!.docs.map((doc) {
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
            if (selectedDepartmentId != null) ...[
              Text("Edit Subject"),
              StreamBuilder<QuerySnapshot>(
                stream: firestore
                    .collection('departments')
                    .doc(selectedDepartmentId)
                    .collection('subjects')
                    .orderBy('name')
                    .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return CircularProgressIndicator();
                  return DropdownButton<String>(
                    value: selectedSubjectId,
                    hint: Text("Select Subject"),
                    isExpanded: true,
                    items: snap.data!.docs.map((doc) {
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
            ],

            SizedBox(height: 16),
            if (selectedDepartmentId != null) ...[
              Text("Edit Mentor"),
              StreamBuilder<QuerySnapshot>(
                stream: firestore
                    .collection('mentors')
                    .where('departmentId', arrayContains: selectedDepartmentId)
                    .orderBy('name')
                    .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return CircularProgressIndicator();
                  return DropdownButton<String>(
                    value: selectedMentorId,
                    hint: Text("Select Mentor"),
                    isExpanded: true,
                    items: snap.data!.docs.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedMentorId = val);
                    },
                  );
                },
              ),
            ],

            SizedBox(height: 16),
            if (selectedDepartmentId != null && selectedSubjectId != null) ...[
              Text("Edit Classes"),
              StreamBuilder<QuerySnapshot>(
                stream: firestore
                    .collection('departments')
                    .doc(selectedDepartmentId)
                    .collection('subjects')
                    .doc(selectedSubjectId)
                    .collection('classes')
                    .orderBy('name')
                    .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return CircularProgressIndicator();
                  return Column(
                    children: snap.data!.docs.map((d) {
                      final isSelected = selectedClassIds.contains(d.id);
                      return CheckboxListTile(
                        title: Text(d['name']),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) selectedClassIds.add(d.id);
                            else selectedClassIds.remove(d.id);
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],

            SizedBox(height: 24),
            ElevatedButton(
              onPressed: saveUpdatedAssignment,
              child: Text("Update Assignment"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveUpdatedAssignment() async {
    if (selectedDepartmentId == null ||
        selectedSubjectId == null ||
        selectedMentorId == null ||
        selectedClassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select all fields')),
      );
      return;
    }

    await widget.firestore.collection('subjectMentors').doc(widget.assignmentId).update({
      'departmentId': selectedDepartmentId,
      'subjectId': selectedSubjectId,
      'mentorId': selectedMentorId,
      'classIds': selectedClassIds.toList(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assignment updated successfully')));
    Navigator.pop(context);
  }

  void confirmDeleteAssignment() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete Assignment"),
        content: Text("Are you sure you want to delete this assignment?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.firestore.collection('subjectMentors').doc(widget.assignmentId).delete();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit screen
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assignment deleted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }
}
