import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_records_screen.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final String subjectId;
  final String classId;
  final String mentorId;
  final String subjectName;
  final String className;
  final Color? color;
  final DateTime? initialDate;

  const TakeAttendanceScreen({
    Key? key,
    required this.subjectId,
    required this.classId,
    required this.mentorId,
    required this.subjectName,
    required this.className,
    this.color,
    this.initialDate,
  }) : super(key: key);

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, String> _attendance = {}; // 'P' or 'A'
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  bool _alreadySaved = false;
  late DateTime selectedDate;

  bool get _isEditMode => widget.initialDate != null;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
    _loadStudentsAndAttendance();
  }

  Future<void> _loadStudentsAndAttendance() async {
    try {
      final enrollments = await _firestore
          .collection('subjectEnrollments')
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('classId', isEqualTo: widget.classId)
          .get();

      final ids = enrollments.docs.map((e) => e['studentId'] as String).toList();

      final students = <Map<String, dynamic>>[];
      for (String id in ids) {
        final doc = await _firestore.collection('students').doc(id).get();
        if (doc.exists) {
          students.add({
            'id': id,
            'name': doc['name'] ?? 'Unnamed',
            'photo': doc['profileUrl'] ?? '',
          });
        }
      }

      final dateStr = selectedDate.toIso8601String().split('T')[0];
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(widget.classId)
          .collection(widget.subjectId)
          .doc(dateStr)
          .get();

      final data = attendanceDoc.data() ?? {};

      setState(() {
        _students = students;
        _attendance = {
          for (var s in students)
            s['id']: data[s['id']] == true ? 'P' : 'A'
        };
        _alreadySaved = attendanceDoc.exists && !_isEditMode;
        _loading = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveAttendance() async {
    final dateStr = selectedDate.toIso8601String().split('T')[0];
    final docRef = _firestore
        .collection('attendance')
        .doc(widget.classId)
        .collection(widget.subjectId)
        .doc(dateStr);

    final data = {
      for (var entry in _attendance.entries)
        entry.key: entry.value == 'P'
    };

    await docRef.set(data);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditMode ? 'Attendance updated.' : 'Attendance saved.')),
    );

    if (!_isEditMode) {
      setState(() {
        _alreadySaved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = widget.color ?? Colors.teal;
    final isLight = appBarColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_isEditMode ? 'Edit' : 'Take'} Attendance · ${widget.subjectName} - ${widget.className}'),
        backgroundColor: appBarColor,
        foregroundColor: textColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
          ? const Center(child: Text("No students enrolled."))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${_isEditMode ? 'Editing record for' : 'Date:'} ${selectedDate.toLocal().toString().split(' ')[0]}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                final id = student['id'];
                final name = student['name'];
                final photo = student['photo'];
                final status = _attendance[id] ?? 'A';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                          backgroundColor: widget.color?.withOpacity(0.2) ?? Colors.grey[300],
                          child: photo.isEmpty
                              ? Icon(Icons.person, color: widget.color ?? Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Radio<String>(
                                    activeColor: widget.color ?? Colors.teal,
                                    value: 'P',
                                    groupValue: status,
                                    onChanged: (val) {
                                      setState(() {
                                        _attendance[id] = val!;
                                      });
                                    },
                                  ),
                                  const Text('Present'),
                                  const SizedBox(width: 12),
                                  Radio<String>(
                                    activeColor: widget.color ?? Colors.teal,
                                    value: 'A',
                                    groupValue: status,
                                    onChanged: (val) {
                                      setState(() {
                                        _attendance[id] = val!;
                                      });
                                    },
                                  ),
                                  const Text('Absent'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (!_alreadySaved || _isEditMode)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveAttendance,
                icon: const Icon(Icons.save), label: Text(_isEditMode ? "Update Attendance" : "Save Attendance"),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text("Attendance already submitted for today.",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16,
                  color: Colors.grey,),
              ),
            ),
        ],
      ),
      floatingActionButton: !_isEditMode
          ? FloatingActionButton.extended(
        heroTag: "viewHistory",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttendanceRecordsScreen(
                classId: widget.classId,
                subjectId: widget.subjectId,
                mentorId: widget.mentorId,
                subjectName: widget.subjectName,
                className: widget.className,
                color: widget.color ?? Colors.teal,
              ),
            ),
          );
        },
        icon: const Icon(Icons.history),
        label: const Text("View Records"),
        backgroundColor: widget.color ?? Colors.teal,
        foregroundColor: Colors.white,

      )
          : null,
    );
  }
}
