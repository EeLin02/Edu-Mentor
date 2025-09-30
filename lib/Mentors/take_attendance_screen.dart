import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_records_screen.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final String schoolId;
  final String programmeId;
  final String subjectId;
  final String sectionId;
  final String mentorId;
  final String subjectName;
  final String sectionName;
  final Color? color;
  final DateTime? initialDate;

  const TakeAttendanceScreen({
    Key? key,
    required this.schoolId,
    required this.programmeId,
    required this.subjectId,
    required this.sectionId,
    required this.mentorId,
    required this.subjectName,
    required this.sectionName,
    this.color,
    this.initialDate,
  }) : super(key: key);

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}


class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, String> _attendance = {}; // 'P', 'A', 'MC'
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _loading = true;
  bool _alreadySaved = false;
  late DateTime selectedDate;
  String _searchQuery = '';
  List<Map<String, dynamic>> _classTimes = [];
  bool _hasClassOnSelectedDate = false;
  late TextEditingController _searchController;

  bool get _isEditMode => widget.initialDate != null;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
    _searchController = TextEditingController();

    _loadClassTimes().then((_) async {
      _checkIfClassExists();
      if (_hasClassOnSelectedDate) {
        await _loadStudentsAndAttendance();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClassTimes() async {
    try {
      final secDoc = await _firestore
          .collection('schools')
          .doc(widget.schoolId)
          .collection('programmes')
          .doc(widget.programmeId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('sections')
          .doc(widget.sectionId)
          .get();

      if (secDoc.exists) {
        final data = secDoc.data() ?? {};
        _classTimes = List<Map<String, dynamic>>.from(data['times'] ?? []);
      }
    } catch (e) {
      print("Error fetching section times: $e");
    }
  }

  void _checkIfClassExists() {
    final weekdayName = _weekdayName(selectedDate.weekday);
    print("SelectedDate: $selectedDate, WeekdayName: $weekdayName");

    _hasClassOnSelectedDate = _classTimes.any((t) {
      final dayStr = (t['day'] as String).trim().toLowerCase();
      final match = dayStr == weekdayName.toLowerCase();
      print("Checking class time day: '$dayStr', matches: $match");
      return match;
    });

    print("_hasClassOnSelectedDate: $_hasClassOnSelectedDate");
  }


  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Monday";
      case DateTime.tuesday:
        return "Tuesday";
      case DateTime.wednesday:
        return "Wednesday";
      case DateTime.thursday:
        return "Thursday";
      case DateTime.friday:
        return "Friday";
      case DateTime.saturday:
        return "Saturday";
      case DateTime.sunday:
        return "Sunday";
      default:
        return "";
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadStudentsAndAttendance() async {
    try {
      final enrollments = await _firestore
          .collection('subjectEnrollments')
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('sectionId', isEqualTo: widget.sectionId)
          .get();

      final ids = enrollments.docs
          .map((e) => e['studentId'] as String)
          .toList();

      final students = <Map<String, dynamic>>[];
      for (String id in ids) {
        final doc = await _firestore.collection('students').doc(id).get();
        if (doc.exists) {
          students.add({
            'id': id,
            'name': doc.data()?['name'] ?? 'Unnamed',
            'photo': doc.data()?['profileUrl'] ?? '',
            'studentIdNo': doc.data()?['studentIdNo'] ?? '',
          });
        }
      }

      final dateStr = selectedDate.toIso8601String().split('T')[0];
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(widget.sectionId)
          .collection(widget.subjectId)
          .doc(dateStr)
          .get();

      final data = attendanceDoc.data() ?? {};

      setState(() {
        _students = students;
        _filteredStudents = students;
        _attendance = {
          for (var s in students)
            s['id']: data[s['id']] == true
                ? 'P'
                : data[s['id']] == 'MC'
                ? 'MC'
                : 'A'
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
    // Ensure all students are marked
    bool allSelected = _students.every((s) => _attendance[s['id']] != null);
    if (!allSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            'Please mark attendance for all students before saving.')),
      );
      return;
    }

    final dateStr = selectedDate.toIso8601String().split('T')[0];
    final docRef = _firestore
        .collection('attendance')
        .doc(widget.sectionId)
        .collection(widget.subjectId)
        .doc(dateStr);

    final data = {
      for (var entry in _attendance.entries)
        entry.key: entry.value == 'P'
            ? true
            : entry.value == 'MC'
            ? 'MC'
            : false
    };

    await docRef.set(data);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
          _isEditMode ? 'Attendance updated.' : 'Attendance saved.')),
    );

    if (!_isEditMode) {
      setState(() {
        _alreadySaved = true;
      });
    }
  }

  void _filterStudents(String query) {
    setState(() {
      _searchQuery = query.trim(); // clean user input
      final normalizedQuery = _searchQuery.toLowerCase();

      _filteredStudents = _students.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        return name.contains(normalizedQuery); // keyword match
      }).toList();
    });
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(today) ? today : selectedDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _loading = true;
      });

      _checkIfClassExists(); // check selectedDate

      if (_hasClassOnSelectedDate) {
        await _loadStudentsAndAttendance();
      } else {
        setState(() => _loading = false); // "No class on this day"
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final appBarColor = widget.color ?? Colors.teal;
    final isLight = appBarColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_isEditMode ? 'Edit' : 'Take'} Attendance · ${widget
              .subjectName} - ${widget.sectionName}',
        ),
        backgroundColor: appBarColor,
        foregroundColor: textColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Date row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_isEditMode
                      ? 'Editing record for'
                      : 'Date:'} ${selectedDate.toLocal().toString().split(
                      ' ')[0]}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                ),
                if (!_isEditMode)
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text("Select Date"),
                  ),
              ],
            ),
          ),

          // States
          if (!_hasClassOnSelectedDate)
            const Expanded(
              child: Center(child: Text("No class on this day.")),
            )
          else
            if (_students.isEmpty)
              const Expanded(
                child: Center(child: Text("No students enrolled.")),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // 🔍 Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterStudents,
                        decoration: InputDecoration(
                          hintText: "Search student by name...",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                                _filteredStudents = _students;
                              });
                            },
                          )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                    ),


                    // Student list
                    Expanded(
                      child: _filteredStudents.isEmpty
                          ? const Center(
                        child: Text("No students match your search."),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: photo.isNotEmpty
                                        ? NetworkImage(photo)
                                        : null,
                                    backgroundColor:
                                    widget.color?.withOpacity(0.2) ??
                                        Colors.grey[300],
                                    child: photo.isEmpty
                                        ? Icon(Icons.person,
                                        color: widget.color ?? Colors.grey)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if ((student['studentIdNo'] ?? '').isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                "(${student['studentIdNo']})", // show ID beside name
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),

                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Radio<String>(
                                              activeColor: widget.color ??
                                                  Colors.teal,
                                              value: 'P',
                                              groupValue: status,
                                              onChanged: (val) {
                                                setState(() {
                                                  _attendance[id] = val!;
                                                });
                                              },
                                            ),
                                            const Text('Present'),
                                            const SizedBox(width: 8),
                                            Radio<String>(
                                              activeColor: widget.color ??
                                                  Colors.teal,
                                              value: 'A',
                                              groupValue: status,
                                              onChanged: (val) {
                                                setState(() {
                                                  _attendance[id] = val!;
                                                });
                                              },
                                            ),
                                            const Text('Absent'),
                                            const SizedBox(width: 8),
                                            Radio<String>(
                                              activeColor: widget.color ??
                                                  Colors.teal,
                                              value: 'MC',
                                              groupValue: status,
                                              onChanged: (val) {
                                                setState(() {
                                                  _attendance[id] = val!;
                                                });
                                              },
                                            ),
                                            const Text('MC'),
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

                    // Save button or already saved
                    if (_hasClassOnSelectedDate &&
                        (!_alreadySaved || _isEditMode))
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _saveAttendance,
                          icon: const Icon(Icons.save),
                          label: Text(_isEditMode
                              ? "Update Attendance"
                              : "Save Attendance"),
                        ),
                      )
                    else
                      if (_alreadySaved && _hasClassOnSelectedDate)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            "Attendance already submitted for this date.",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
        ],
      ),
      floatingActionButton: !_isEditMode
          ? FloatingActionButton.extended(
        heroTag: "viewHistory",
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AttendanceRecordsScreen(
                    schoolId: widget.schoolId,
                    programmeId: widget.programmeId,
                    sectionId: widget.sectionId,
                    subjectId: widget.subjectId,
                    mentorId: widget.mentorId,
                    subjectName: widget.subjectName,
                    sectionName: widget.sectionName,
                    color: widget.color ?? Colors.teal,
                  ),
            ),
          );

          if (result == true) {
            setState(() {
              _loading = true;
            });
            await _loadStudentsAndAttendance();
          }
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
