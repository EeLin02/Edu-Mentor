import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'take_attendance_screen.dart';

class AttendanceRecordsScreen extends StatelessWidget {
  final String classId;
  final String subjectId;
  final String mentorId;
  final String subjectName;
  final String className;
  final Color color;

  const AttendanceRecordsScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.mentorId,
    required this.subjectName,
    required this.className,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final attendanceRef = FirebaseFirestore.instance
        .collection('attendance')
        .doc(classId)
        .collection(subjectId);

    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance · $subjectName - $className"),
        backgroundColor: color,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: attendanceRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No attendance records found."));
          }

          // Sort by document ID (which is date string like '2025-08-01')
          docs.sort((a, b) => b.id.compareTo(a.id)); // Descending

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final dateStr = doc.id;

              Map<String, dynamic> data = {};
              try {
                data = doc.data() as Map<String, dynamic>;
              } catch (_) {}

              final presentCount = data.values.where((v) => v == true).length;
              final absentCount = data.length - presentCount;

              return ListTile(
                leading: const Icon(Icons.event_note),
                title: Text(
                  DateFormat('EEE, MMM d, yyyy').format(DateTime.parse(dateStr)),
                ),
                subtitle: Text("Present: $presentCount | Absent: $absentCount"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TakeAttendanceScreen(
                        classId: classId,
                        subjectId: subjectId,
                        mentorId: mentorId,
                        subjectName: subjectName,
                        className: className,
                        color: color,
                        initialDate: DateTime.parse(dateStr), // pass for edit mode
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
