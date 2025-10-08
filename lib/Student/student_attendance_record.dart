import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAttendanceRecordsScreen extends StatefulWidget {
  final String sectionId;
  final String subjectId;
  final String studentId;
  final Color color;

  const StudentAttendanceRecordsScreen({
    Key? key,
    required this.sectionId,
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

  int presentCount = 0;
  int absentCount = 0;
  int mcCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.subjectId)
        .collection(widget.sectionId)
        .get();

    int totalSessions = 0;
    int present = 0;
    int absent = 0;
    int mc = 0;

    List<Map<String, dynamic>> tempList = [];

    for (var doc in snapshot.docs) {
      final date = doc.id; // "2025-10-03"
      final data = doc.data();

      if (data.containsKey(widget.studentId)) {
        totalSessions++;
        String status;

        final value = data[widget.studentId];
        if (value == "P") {
          status = "Present";
          present++;
        } else if (value == "MC") {
          status = "MC";
          mc++;
        } else if (value == "A") {
          status = "Absent";
          absent++;
        } else {
          status = "N/A"; // optional fallback
        }


        tempList.add({"date": date, "status": status});
      }
    }

    setState(() {
      attendanceList = tempList;
      presentCount = present;
      absentCount = absent;
      mcCount = mc;
      attendanceRate = totalSessions > 0 ? (present / totalSessions)
          * 100 : 0.0;
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

          // Summary counts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryCard("Present", presentCount, Colors.green),
                _buildSummaryCard("Absent", absentCount, Colors.red),
                _buildSummaryCard("MC", mcCount, Colors.orange),
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
                                : status == "MC"
                                ? Icons.medical_services
                                : Icons.cancel,
                            color: status == "Present"
                                ? Colors.green
                                : status == "MC"
                                ? Colors.orange
                                : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(
                              color: status == "Present"
                                  ? Colors.green
                                  : status == "MC"
                                  ? Colors.orange
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

  Widget _buildSummaryCard(String label, int count, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
