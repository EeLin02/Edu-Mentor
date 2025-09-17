import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'private_chat_screen.dart';

class ClassChatScreen extends StatefulWidget {
  final String subjectId;
  final String classId;
  final String subjectName;
  final String className;
  final Color? color;
  final String mentorId;

  const ClassChatScreen({
    Key? key,
    required this.subjectId,
    required this.classId,
    required this.subjectName,
    required this.className,
    required this.mentorId,
    this.color,
  }) : super(key: key);

  @override
  State<ClassChatScreen> createState() => _ClassChatScreenState();
}

class _ClassChatScreenState extends State<ClassChatScreen> {
  late Future<List<Map<String, String>>> _enrolledStudentsFuture;
  List<Map<String, String>> _allStudents = [];
  List<Map<String, String>> _filteredStudents = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _enrolledStudentsFuture = _fetchEnrolledStudents();
  }

  Future<List<Map<String, String>>> _fetchEnrolledStudents() async {
    final firestore = FirebaseFirestore.instance;

    final enrollmentSnap = await firestore
        .collection('subjectEnrollments')
        .where('subjectId', isEqualTo: widget.subjectId)
        .where('classId', isEqualTo: widget.classId)
        .get();

    final studentIds = enrollmentSnap.docs
        .map((doc) => doc.data()['studentId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (studentIds.isEmpty) return [];

    final List<Map<String, String>> students = [];

    for (final id in studentIds) {
      final doc = await firestore.collection('students').doc(id).get();
      if (doc.exists) {
        final data = doc.data();
        students.add({
          'id': id,
          'name': data?['name']?.toString() ?? 'Unknown',
          'profileUrl': data?['profileUrl']?.toString() ?? '',
        });
      }
    }

    // Store results locally for searching
    setState(() {
      _allStudents = students;
      _filteredStudents = students;
    });

    return students;
  }

  void _filterStudents(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredStudents = _allStudents.where((student) {
        final name = student['name']?.toLowerCase() ?? '';
        return name.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = widget.color ?? Colors.teal;
    final isLight = appBarColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Class Chat · ${widget.subjectName} - ${widget.className}'),
        backgroundColor: appBarColor,
        foregroundColor: textColor,
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _enrolledStudentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _allStudents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (_allStudents.isEmpty) {
            return const Center(child: Text("No students enrolled."));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search students by name...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _filterStudents,
                ),
              ),
              Expanded(
                child: _filteredStudents.isEmpty
                    ? const Center(child: Text("No matching students found."))
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredStudents.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final student = _filteredStudents[index];
                    final name = student['name'] ?? 'Unnamed';
                    final profileUrl = student['profileUrl'] ?? '';
                    final studentId = student['id'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profileUrl.isNotEmpty
                            ? NetworkImage(profileUrl)
                            : null,
                        child: profileUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(name),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrivateChatScreen(
                              studentId: studentId,
                              studentName: name,
                              mentorId: widget.mentorId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
