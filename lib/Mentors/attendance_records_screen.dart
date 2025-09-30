import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'take_attendance_screen.dart';

class AttendanceRecordsScreen extends StatefulWidget {
  final String sectionId;
  final String subjectId;
  final String mentorId;
  final String subjectName;
  final String sectionName;
  final Color color;
  final String schoolId;
  final String programmeId;

  const AttendanceRecordsScreen({
    super.key,
    required this.schoolId,
    required this.programmeId,
    required this.sectionId,
    required this.subjectId,
    required this.mentorId,
    required this.subjectName,
    required this.sectionName,
    required this.color,
  });

  @override
  State<AttendanceRecordsScreen> createState() => _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  bool _isWithinRange(String dateStr) {
    final date = DateTime.parse(dateStr);
    if (_startDate != null && date.isBefore(_startDate!)) return false;
    if (_endDate != null && date.isAfter(_endDate!)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = widget.color ?? Colors.teal;
    final isLight = appBarColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    final attendanceRef = FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.sectionId)
        .collection(widget.subjectId);

    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance · ${widget.subjectName} - ${widget.sectionName}"),
        backgroundColor: appBarColor,
        foregroundColor: textColor,
      ),
      body: Column(
        children: [
          // Date Filter Row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.date_range, color: Colors.white),
                    label: Text(
                      _startDate == null
                          ? "Start Date"
                          : DateFormat('yyyy-MM-dd').format(_startDate!),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.date_range, color: Colors.white),
                    label: Text(
                      _endDate == null
                          ? "End Date"
                          : DateFormat('yyyy-MM-dd').format(_endDate!),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                ),
              ],
            ),
          ),

          // Attendance List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                // Sort by date descending and filter by selected range
                final filteredDocs = docs
                    .where((doc) => _isWithinRange(doc.id))
                    .toList()
                  ..sort((a, b) => b.id.compareTo(a.id));

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child: Text("No records in selected date range."));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final dateStr = doc.id;

                    Map<String, dynamic> data = {};
                    try {
                      data = doc.data() as Map<String, dynamic>;
                    } catch (_) {}

                    final presentCount = data.values.where((v) => v == true).length;
                    final mcCount = data.values.where((v) => v == "MC").length;
                    final absentCount = data.length - presentCount - mcCount;

                    return Card(
                      margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.event_note),
                        title: Text(
                          DateFormat('EEE, MMM d, yyyy')
                              .format(DateTime.parse(dateStr)),
                        ),
                        subtitle:
                        Text("Present: $presentCount | Absent: $absentCount | MC: $mcCount"),
                          trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Delete Record"),
                                content: Text(
                                  "Are you sure you want to delete the attendance record for ${DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStr))}?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              try {
                                await attendanceRef.doc(dateStr).delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Record deleted.")),
                                );
                                // Return true to TakeAttendanceScreen so it can refresh
                                Navigator.pop(context, true);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to delete: $e")),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TakeAttendanceScreen(
                                schoolId: widget.schoolId,
                                programmeId: widget.programmeId,
                                sectionId: widget.sectionId,
                                subjectId: widget.subjectId,
                                mentorId: widget.mentorId,
                                subjectName: widget.subjectName,
                                sectionName: widget.sectionName,
                                color: widget.color,
                                initialDate: DateTime.parse(dateStr),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
