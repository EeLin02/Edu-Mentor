import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentEnrollScreen extends StatefulWidget {
  final String studentId;
  const StudentEnrollScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  _StudentEnrollScreenState createState() => _StudentEnrollScreenState();
}

class _StudentEnrollScreenState extends State<StudentEnrollScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  String? schoolId;
  String? programmeId;

  /// subjectId -> sectionId
  Map<String, String?> selectedSections = {};
  List<Map<String, dynamic>> subjects = [];

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
  }

  Future<void> _loadStudentInfo() async {
    final doc = await _firestore
        .collection("students")
        .doc(widget.studentId)
        .get();
    if (doc.exists) {
      schoolId = doc.data()?['schoolId'] as String?;
      programmeId = doc.data()?['programmeId'] as String?;
      await _loadSubjects();
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadSubjects() async {
    if (schoolId == null || programmeId == null) return;
    final snap = await _firestore
        .collection("schools")
        .doc(schoolId)
        .collection("programmes")
        .doc(programmeId)
        .collection("subjects")
        .get();

    subjects = snap.docs.map((d) => {
      "id": d.id,
      "name": d.data()?["name"] as String? ?? "Unknown",
    } as Map<String, dynamic>).toList();  // cast here
  }

  Future<void> _saveEnrollments() async {
    // --- Check school/programme first
    if (schoolId == null || programmeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Missing school or programme info.")),
      );
      return;
    }

    print("🔎 Saving enrollments with: schoolId=$schoolId, programmeId=$programmeId");
    print("🔎 Selected sections: $selectedSections");

    final batch = _firestore.batch();

    for (var entry in selectedSections.entries) {
      final subjectId = entry.key;
      final sectionId = entry.value;

      // 👉 Add debug print here
      print("schoolId=$schoolId, programmeId=$programmeId, subjectId=$subjectId, sectionId=$sectionId");

      // 👉 Add guard here
      if (subjectId.isEmpty || sectionId == null || sectionId.isEmpty) {
        print("⚠️ Skipping invalid subject/section");
        continue;
      }

      print("➡️ Processing subjectId=$subjectId, sectionId=$sectionId");

      if (subjectId.isEmpty || sectionId == null || sectionId.isEmpty) {
        print("⚠️ Skipping invalid subject/section");
        continue;
      }

      // ✅ Fetch subject + section docs
      final subjectDoc = await _firestore
          .collection("schools")
          .doc(schoolId)
          .collection("programmes")
          .doc(programmeId)
          .collection("subjects")
          .doc(subjectId)
          .get();

      final sectionDoc = await _firestore
          .collection("schools")
          .doc(schoolId)
          .collection("programmes")
          .doc(programmeId)
          .collection("subjects")
          .doc(subjectId)
          .collection("sections")
          .doc(sectionId)
          .get();

      final subjectName = subjectDoc.data()?['name'] ?? 'Unknown Subject';
      final sectionName = sectionDoc.data()?['name'] ?? 'Unknown Section';

      // save student enrollment with names
      final docRef = _firestore
          .collection("subjectEnrollments")
          .doc("${widget.studentId}_$subjectId");

      batch.set(docRef, {
        "studentId": widget.studentId,
        "schoolId": schoolId,
        "programmeId": programmeId,
        "subjectId": subjectId,
        "sectionId": sectionId,
        "subjectName": subjectName,
        "sectionName": sectionName,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // increment section count
      final secRef = _firestore
          .collection("schools")
          .doc(schoolId!)
          .collection("programmes")
          .doc(programmeId!)
          .collection("subjects")
          .doc(subjectId)
          .collection("sections")
          .doc(sectionId);

      batch.set(secRef, {
        "currentCount": FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Enrollment saved successfully!")),
      );
      setState(() {
        selectedSections.clear();
      });
    } catch (e) {
      print("❌ Batch commit failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving enrollment: $e")),
      );
    }
  }

  Stream<DocumentSnapshot?> _getPendingRequest(String subjectId, String? sectionId) {
    return _firestore
        .collection("enrollmentRequests")
        .where("studentId", isEqualTo: widget.studentId)
        .where("subjectId", isEqualTo: subjectId)
        .where("currentSectionId", isEqualTo: sectionId)
        .where("status", isEqualTo: "pending")
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }


  void _addSubjectDialog() async {
    String query = "";
    Map<String, dynamic>? selectedSubject;

    // Get already enrolled subjectIds
    final enrolledSnap = await _firestore
        .collection("subjectEnrollments")
        .where("studentId", isEqualTo: widget.studentId)
        .get();
    final enrolledIds = enrolledSnap.docs.map((d) => d["subjectId"] as String).toSet();

    // Also exclude already chosen but not saved
    final alreadySelected = selectedSections.keys.toSet();

    // Exclude both
    final excludedIds = {...enrolledIds, ...alreadySelected};

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = subjects
                .where((s) =>
            !excludedIds.contains(s["id"]) &&
                s["name"].toLowerCase().contains(query.toLowerCase()))
                .toList();

            return AlertDialog(
              title: Text("Select Subject"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: "Search subject...",
                      ),
                      onChanged: (val) {
                        setDialogState(() => query = val);
                      },
                    ),
                    SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? Center(child: Text("No subjects available"))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final subj = filtered[i];
                          return ListTile(
                            title: Text(subj["name"]),
                            onTap: () {
                              selectedSubject = subj;
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedSubject != null) {
      setState(() {
        selectedSections[selectedSubject!["id"]] = null;
      });
    }
  }



  Widget _buildSectionSelector(String subjectId, String subjectName) {
    if (schoolId == null || programmeId == null || subjectId.isEmpty) {
      return SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("schools")
          .doc(schoolId)
          .collection("programmes")
          .doc(programmeId)
          .collection("subjects")
          .doc(subjectId)
          .collection("sections")
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return SizedBox.shrink();

        final sections = snap.data!.docs;

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subjectName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                ...sections.map((s) {
                  final data = s.data() as Map<String, dynamic>;
                  final secId = s.id;
                  final secName = data["name"] ?? '';
                  final limit = data["limit"] ?? 0;
                  final currentCount = data["currentCount"] ?? 0;
                  final isFull = (limit == 0) || (currentCount >= limit);

                  return RadioListTile<String>(
                    value: secId,
                    groupValue: selectedSections[subjectId],
                    title: Text("$secName (${currentCount}/$limit)"),
                    onChanged: isFull
                        ? null
                        : (val) {
                      setState(() {
                        selectedSections[subjectId] = val;
                      });
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnrolledSubject(String subjectId, String subjectName, String? sectionId) {
    // ❌ Prevent null/empty Firestore paths
    if (schoolId == null || programmeId == null || subjectId.isEmpty || sectionId == null || sectionId.isEmpty) {
      return Card(
        child: ListTile(
          title: Text(subjectName),
          subtitle: const Text("Invalid subject/section reference"),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot?>(
      stream: _getPendingRequest(subjectId, sectionId),
      builder: (context, requestSnap) {
        final hasPending = requestSnap.hasData && requestSnap.data != null;
        final pendingDoc = requestSnap.data;

        if (hasPending) {
          final type = pendingDoc!["type"] as String;
          return Card(
            child: ListTile(
              title: Text(subjectName),
              subtitle: Text("Pending ${type == "drop" ? "Drop" : "Exchange"} Request"),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == "cancel") {
                    await pendingDoc.reference.delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Request cancelled.")),
                    );
                  } else if (value == "changeToExchange") {
                    _showExchangeDialog(subjectId, sectionId, existingDoc: pendingDoc);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: "cancel", child: Text("Cancel Request")),
                  if (type == "drop")
                    const PopupMenuItem(value: "changeToExchange", child: Text("Change to Exchange")),
                ],
              ),
            ),
          );
        }

        // 🟦 Default: no pending request → safe FutureBuilder
        return FutureBuilder<DocumentSnapshot>(
          future: _firestore
              .collection("schools")
              .doc(schoolId!)
              .collection("programmes")
              .doc(programmeId!)
              .collection("subjects")
              .doc(subjectId)
              .collection("sections")
              .doc(sectionId) // ✅ safe because of guards above
              .get(),
          builder: (context, sectionSnap) {
            if (sectionSnap.connectionState == ConnectionState.waiting) {
              return Card(
                child: ListTile(
                  title: Text(subjectName),
                  subtitle: const Text("Loading section..."),
                ),
              );
            }

            if (!sectionSnap.hasData || !sectionSnap.data!.exists) {
              return Card(
                child: ListTile(
                  title: Text(subjectName),
                  subtitle: const Text("Section not found"),
                ),
              );
            }

            final sectionData = sectionSnap.data!.data() as Map<String, dynamic>;
            final sectionName = sectionData["name"] ?? sectionId;

            return Card(
              child: ListTile(
                title: Text(subjectName),
                subtitle: Text("Enrolled in section: $sectionName"),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == "drop") {
                      _sendDropRequest(subjectId, sectionId);
                    } else if (value == "exchange") {
                      _showExchangeDialog(subjectId, sectionId);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: "drop", child: Text("Request Drop")),
                    const PopupMenuItem(value: "exchange", child: Text("Request Exchange")),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }



  Future<void> _sendDropRequest(String subjectId, String? sectionId) async {
    await _firestore.collection("enrollmentRequests").add({
      "studentId": widget.studentId,
      "schoolId": schoolId,
      "programmeId": programmeId,
      "subjectId": subjectId,
      "currentSectionId": sectionId,
      "requestedSectionId": null,
      "type": "drop",
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Drop request submitted!")),
    );
  }


  Future<void> _showExchangeDialog(
      String subjectId,
      String? currentSectionId, {
        DocumentSnapshot? existingDoc,
      }) async {
    String? newSectionId;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Select new section"),
          content: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection("schools")
                .doc(schoolId)
                .collection("programmes")
                .doc(programmeId)
                .collection("subjects")
                .doc(subjectId)
                .collection("sections")
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return CircularProgressIndicator();
              final sections = snap.data!.docs;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: sections.map((s) {
                  final secId = s.id;
                  final name = s["name"];
                  return RadioListTile<String>(
                    value: secId,
                    groupValue: newSectionId,
                    title: Text(name),
                    onChanged: (val) {
                      newSectionId = val;
                      (ctx as Element).markNeedsBuild();
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: Text("Request"),
              onPressed: () async {
                if (newSectionId != null && newSectionId != currentSectionId) {
                  if (existingDoc != null) {
                    // 🔄 Update existing drop → exchange
                    await existingDoc.reference.update({
                      "requestedSectionId": newSectionId,
                      "type": "exchange",
                      "updatedAt": FieldValue.serverTimestamp(),
                    });
                  } else {
                    // ➕ New exchange request
                    await _firestore.collection("enrollmentRequests").add({
                      "studentId": widget.studentId,
                      "schoolId": schoolId,
                      "programmeId": programmeId,
                      "subjectId": subjectId,
                      "currentSectionId": currentSectionId,
                      "requestedSectionId": newSectionId,
                      "type": "exchange",
                      "status": "pending",
                      "createdAt": FieldValue.serverTimestamp(),
                    });
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Exchange request submitted!")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Enroll in Subjects"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addSubjectDialog,
          )
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // --- Section: Selected (before saving)
          if (selectedSections.isNotEmpty) ...[
            Text("New Subjects to Enroll",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            ...selectedSections.entries.map((entry) {
              final subj = subjects.firstWhere((s) => s["id"] == entry.key);
              return _buildSectionSelector(entry.key, subj["name"]);
            }),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: selectedSections.values.any((v) => v != null)
                  ? _saveEnrollments
                  : null,
              icon: Icon(Icons.save),
              label: Text("Save Enrollment"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            Divider(),
          ],

          // --- Section: Already Enrolled
          Text("Enrolled Subjects",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection("subjectEnrollments")
                .where("studentId", isEqualTo: widget.studentId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return CircularProgressIndicator();
              if (snap.data!.docs.isEmpty) {
                return Text("No enrolled subjects yet.");
              }

              final enrolled = snap.data!.docs;
              return Column(
                children: enrolled.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final subjectId = data["subjectId"] as String? ?? "";
                  final sectionId = data["sectionId"] as String?;

                  final Map<String, dynamic> subj = subjects.firstWhere(
                        (s) => s["id"] == subjectId,
                    orElse: () => {"id": subjectId, "name": "Unknown"},
                  );

                  return _buildEnrolledSubject(
                      subjectId, subj["name"], sectionId);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
