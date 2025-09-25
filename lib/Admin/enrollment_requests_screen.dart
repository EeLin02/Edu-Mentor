import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentRequestsScreen extends StatefulWidget {
  @override
  _EnrollmentRequestsScreenState createState() => _EnrollmentRequestsScreenState();
}

class _EnrollmentRequestsScreenState extends State<EnrollmentRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _approveRequest(DocumentSnapshot reqDoc) async {
    final data = reqDoc.data() as Map<String, dynamic>;
    final type = data["type"];
    final studentId = data["studentId"];
    final subjectId = data["subjectId"];
    final currentSectionId = data["currentSectionId"];
    final requestedSectionId = data["requestedSectionId"];
    final schoolId = data["schoolId"];
    final programmeId = data["programmeId"];

    final batch = _firestore.batch();

    final enrollmentRef = _firestore
        .collection("subjectEnrollments")
        .doc("${studentId}_$subjectId");

    if (type == "drop") {
      batch.delete(enrollmentRef);

      if (currentSectionId != null) {
        final secRef = _firestore
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId)
            .collection("sections")
            .doc(currentSectionId);
        batch.update(secRef, {"currentCount": FieldValue.increment(-1)});
      }
    } else if (type == "exchange" && requestedSectionId != null) {
      batch.update(enrollmentRef, {"sectionId": requestedSectionId});

      // decrement old
      final oldSecRef = _firestore
          .collection("schools")
          .doc(schoolId)
          .collection("programmes")
          .doc(programmeId)
          .collection("subjects")
          .doc(subjectId)
          .collection("sections")
          .doc(currentSectionId);
      batch.update(oldSecRef, {"currentCount": FieldValue.increment(-1)});

      // increment new
      final newSecRef = _firestore
          .collection("schools")
          .doc(schoolId)
          .collection("programmes")
          .doc(programmeId)
          .collection("subjects")
          .doc(subjectId)
          .collection("sections")
          .doc(requestedSectionId);
      batch.update(newSecRef, {"currentCount": FieldValue.increment(1)});
    }

    // instead of updating status, just delete the request
    batch.delete(reqDoc.reference);

    await batch.commit();
  }

  Future<void> _rejectRequest(DocumentSnapshot reqDoc) async {
    await reqDoc.reference.delete();
  }

  Future<String> _getStudentDisplay(String? studentId) async {
    if (studentId == null) return "Unknown student";
    final snap = await _firestore.collection("students").doc(studentId).get();
    if (snap.exists) {
      final data = snap.data()!;
      final name = data["name"] as String? ?? "Unknown";
      final idNo = data["studentIdNo"] as String? ?? "";
      return "$name ($idNo)";
    }
    return studentId;
  }

  Future<String> _getSubjectName(String? schoolId, String? programmeId, String? subjectId) async {
    if (schoolId == null || programmeId == null || subjectId == null) return "Unknown subject";
    final snap = await _firestore
        .collection("schools")
        .doc(schoolId)
        .collection("programmes")
        .doc(programmeId)
        .collection("subjects")
        .doc(subjectId)
        .get();
    if (snap.exists) {
      return snap.data()?["name"] as String? ?? subjectId;
    }
    return subjectId;
  }

  Future<String> _getSectionName(
      String? schoolId, String? programmeId, String? subjectId, String? sectionId) async {
    if (schoolId == null || programmeId == null || subjectId == null || sectionId == null) return "-";
    final snap = await _firestore
        .collection("schools")
        .doc(schoolId)
        .collection("programmes")
        .doc(programmeId)
        .collection("subjects")
        .doc(subjectId)
        .collection("sections")
        .doc(sectionId)
        .get();
    if (snap.exists) {
      return snap.data()?["name"] as String? ?? sectionId;
    }
    return sectionId;
  }


  @override
  Widget build(BuildContext context) {
    final stream = _firestore
        .collection("enrollmentRequests")
        .where("status", isEqualTo: "pending")
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text("Enrollment Requests")),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return Center(child: Text("No pending requests."));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (_, i) {
              final req = requests[i];
              final data = req.data() as Map<String, dynamic>;

              return FutureBuilder<List<String>>(
                future: Future.wait([
                  _getStudentDisplay(data["studentId"] as String?),
                  _getSubjectName(
                    data["schoolId"] as String?,
                    data["programmeId"] as String?,
                    data["subjectId"] as String?,
                  ),
                  data["currentSectionId"] != null
                      ? _getSectionName(
                    data["schoolId"] as String?,
                    data["programmeId"] as String?,
                    data["subjectId"] as String?,
                    data["currentSectionId"] as String?,
                  )
                      : Future.value("-"),
                  data["requestedSectionId"] != null
                      ? _getSectionName(
                    data["schoolId"] as String?,
                    data["programmeId"] as String?,
                    data["subjectId"] as String?,
                    data["requestedSectionId"] as String?,
                  )
                      : Future.value("-"),
                ]),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return Card(
                      child: ListTile(
                        title: Text("${data['type'].toUpperCase()} request"),
                        subtitle: Text("Loading details..."),
                      ),
                    );
                  }

                  final studentName = snap.data![0];
                  final subjectName = snap.data![1];
                  final fromSection = snap.data![2];
                  final toSection = snap.data![3];

                  return Card(
                    child: ListTile(
                      title: Text("${data['type'].toUpperCase()} request"),
                      subtitle: Text(
                        "Student: $studentName\n"
                            "Subject: $subjectName\n"
                            "From: $fromSection → To: $toSection",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => _approveRequest(req),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectRequest(req),
                          ),
                        ],
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
