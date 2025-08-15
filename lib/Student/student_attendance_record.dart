import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAttendanceRecordsScreen extends StatefulWidget {
  final String classId;
  final String subjectId;
  final String studentId; // student UID
  final Color color;

  const StudentAttendanceRecordsScreen({
    Key? key,
    required this.classId,
    required this.subjectId,
    required this.studentId,
    required this.color,
  }) : super(key: key);

  @override
  _StudentAttendanceRecordsScreenState createState() =>
      _StudentAttendanceRecordsScreenState();
}

class _StudentAttendanceRecordsScreenState
    extends State<StudentAttendanceRecordsScreen> {
  double attendanceRate = 0.0;
  List<Map<String, dynamic>> attendanceList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.classId)
        .collection(widget.subjectId)
        .get();

    int totalSessions = 0;
    int presentCount = 0;
    List<Map<String, dynamic>> tempList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // Extract date from doc ID if no date field exists
      final date = data['date'] ?? doc.id;

      // If this doc has the student's record
      if (data.containsKey(widget.studentId)) {
        totalSessions++;
        final status = data[widget.studentId] == true ? "Present" : "Absent";
        if (status == "Present") presentCount++;

        tempList.add({
          "date": date,
          "status": status,
        });
      }
    }

    setState(() {
      attendanceList = tempList;
      attendanceRate = totalSessions > 0
          ? (presentCount / totalSessions) * 100
          : 0.0;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = widget.color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.color,
        title: Text(
          "View Attendance",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          const SizedBox(height: 20),
          // Attendance Percentage Circle
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 150,
                  width: 150,
                  child: CircularProgressIndicator(
                    value: attendanceRate / 100,
                    strokeWidth: 10,
                    color: widget.color,
                    backgroundColor: widget.color.withOpacity(0.2),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${attendanceRate.toStringAsFixed(0)}%",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Attendance Rate",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Attendance Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                WidgetStateProperty.all(Colors.grey[200]),
                columns: const [
                  DataColumn(label: Text("Date")),
                  DataColumn(label: Text("Status")),
                ],
                rows: attendanceList.map((record) {
                  final status = record['status'];
                  return DataRow(
                    cells: [
                      DataCell(Text(record['date'] ?? '')),
                      DataCell(Row(
                        children: [
                          Icon(
                            status == "Present"
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: status == "Present"
                                ? Colors.green
                                : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(
                              color: status == "Present"
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
