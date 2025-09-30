import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AssignMentorScreen extends StatefulWidget {
  @override
  _AssignMentorScreenState createState() => _AssignMentorScreenState();
}

class _AssignMentorScreenState extends State<AssignMentorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? selectedSchool;
  Map<String, dynamic>? selectedProgramme;

  // Mentor selected per subject
  Map<String, String?> selectedMentorBySubject = {};

  // Selected sections per subject (local selection)
  Map<String, Set<String>> selectedSectionsBySubject = {};

  // Limits per subject -> section
  Map<String, Map<String, int>> sectionLimitsBySubject = {};

  // Keep TextEditingController per subject -> section so UI updates correctly
  final Map<String, Map<String, TextEditingController>> _limitControllers = {};

  // Map existing DB doc ids: subjectId -> sectionId -> docId
  final Map<String, Map<String, String>> existingDocIds = {};

  TextEditingController _searchCtrl = TextEditingController();
  String searchQuery = "";

  int totalStudentsInProgramme = 0;

  // --------------------------
  // Dialogs / fetch helpers
  // --------------------------
  Future<Map<String, dynamic>?> _showSelectionDialog({
    required String title,
    required List<Map<String, dynamic>> items,
  }) async {
    TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = items;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setStateDialog(() {
                        filtered = items
                            .where((e) =>
                            e['name'].toString().toLowerCase().contains(val.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: double.maxFinite,
                    height: 300,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        return ListTile(
                          title: Text(filtered[i]['name'].toString()),
                          onTap: () => Navigator.pop(ctx, filtered[i]),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getSchools() async {
    final snapshot = await _firestore.collection('schools').get();
    return snapshot.docs.map((d) => {'id': d.id, 'name': d['name']}).toList();
  }

  Future<List<Map<String, dynamic>>> _getProgrammes(String schoolId) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('programmes')
        .get();
    return snapshot.docs.map((d) => {'id': d.id, 'name': d['name']}).toList();
  }

  Future<void> _fetchTotalStudents(String schoolId, String programmeId) async {
    final snap = await _firestore
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .where('programmeId', isEqualTo: programmeId)
        .where('disabled', isEqualTo: false)
        .get();

    setState(() {
      totalStudentsInProgramme = snap.size;
    });
  }

  Stream<QuerySnapshot> _getSubjects(String schoolId, String programmeId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('programmes')
        .doc(programmeId)
        .collection('subjects')
        .snapshots();
  }

  // --------------------------
  // Loading existing assignments
  // --------------------------
  Future<void> _loadAssignments(String schoolId, String programmeId) async {
    // Clear previous local state & controllers
    selectedMentorBySubject.clear();
    selectedSectionsBySubject.clear();
    sectionLimitsBySubject.clear();

    // dispose existing controllers
    _disposeAllLimitControllers();
    _limitControllers.clear();
    existingDocIds.clear();

    final snapshot = await _firestore
        .collection("subjectMentors")
        .where("schoolId", isEqualTo: schoolId)
        .where("programmeId", isEqualTo: programmeId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final subjectId = (data['subjectId'] ?? '').toString();
      final sectionId = (data['sectionId'] ?? '').toString();
      final docId = doc.id;
      final mentorId = data['mentorId']?.toString();
      final limit = (data['limit'] is int) ? data['limit'] as int : (int.tryParse((data['limit'] ?? '0').toString()) ?? 0);

      if (subjectId.isEmpty || sectionId.isEmpty) continue;

      // store doc id for this subject/section so we can update/delete later
      existingDocIds.putIfAbsent(subjectId, () => {});
      existingDocIds[subjectId]![sectionId] = docId;

      // store mentor (last mentor seen for subject will be kept)
      if (mentorId != null) selectedMentorBySubject[subjectId] = mentorId;

      // mark section as selected
      selectedSectionsBySubject.putIfAbsent(subjectId, () => {});
      selectedSectionsBySubject[subjectId]!.add(sectionId);

      // store limits
      sectionLimitsBySubject.putIfAbsent(subjectId, () => {});
      sectionLimitsBySubject[subjectId]![sectionId] = limit;

      // initialize controller for this subject/section
      _limitControllers.putIfAbsent(subjectId, () => {});
      _limitControllers[subjectId]![sectionId] = TextEditingController(text: limit.toString());
    }

    setState(() {});
  }

  // --------------------------
  // Save (upsert + delete)
  // --------------------------
  Future<void> _saveAssignments() async {
    if (selectedSchool == null || selectedProgramme == null) return;

    final batch = _firestore.batch();

    // 1) Build a set of all subject/section pairs that currently exist in DB (for this school+programme)
    //    from existingDocIds map
    final Map<String, Set<String>> existingSubjectSections = {};
    existingDocIds.forEach((subj, secMap) {
      existingSubjectSections[subj] = secMap.keys.toSet();
    });

    // 2) For every subject currently selected -> ensure doc (create/update)
    for (final subjectId in selectedSectionsBySubject.keys) {
      final selectedSections = selectedSectionsBySubject[subjectId] ?? {};
      final limitsForSubject = sectionLimitsBySubject[subjectId] ?? {};
      final mentorId = selectedMentorBySubject[subjectId];

      for (final secId in selectedSections) {
        final docId = "${selectedSchool!['id']}_${selectedProgramme!['id']}_${subjectId}_$secId";
        final docRef = _firestore.collection("subjectMentors").doc(docId);

        final limit = limitsForSubject[secId] ?? 0;

        // upsert (create or merge update)
        batch.set(docRef, {
          "schoolId": selectedSchool!['id'],
          "programmeId": selectedProgramme!['id'],
          "subjectId": subjectId,
          "sectionId": secId,
          "mentorId": mentorId ?? FieldValue.delete(),
          "limit": limit,
          "updatedAt": FieldValue.serverTimestamp(),
          "createdAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // also update the actual section doc so StudentEnrollScreen sees limit/currentCount
        final secRef = _firestore
            .collection("schools")
            .doc(selectedSchool!['id'])
            .collection("programmes")
            .doc(selectedProgramme!['id'])
            .collection("subjects")
            .doc(subjectId)
            .collection("sections")
            .doc(secId);

        batch.set(secRef, {
          "limit": limit,
          "currentCount": FieldValue.increment(0), // ensures field exists, does not increment
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

      }
    }

    // 3) For every existing DB record that is NOT in selectedSectionsBySubject -> delete it
    existingSubjectSections.forEach((subjectId, dbSections) {
      final selected = selectedSectionsBySubject[subjectId] ?? <String>{};
      for (final secId in dbSections) {
        if (!selected.contains(secId)) {
          // delete this DB doc (we have the saved doc id in existingDocIds)
          final docId = existingDocIds[subjectId]?[secId];
          if (docId != null) {
            final docRef = _firestore.collection("subjectMentors").doc(docId);
            batch.delete(docRef);
          }
        }
      }
    });

    // Commit batch
    await batch.commit();

    // Reload assignments from DB so UI becomes authoritative
    await _loadAssignments(selectedSchool!['id'], selectedProgramme!['id']);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Assignments saved successfully!")),
    );
  }

  // --------------------------
  // controller utils
  // --------------------------
  void _disposeAllLimitControllers() {
    for (final subjMap in _limitControllers.values) {
      for (final ctrl in subjMap.values) {
        ctrl.dispose();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _disposeAllLimitControllers();
    super.dispose();
  }

  // --------------------------
  // Build UI
  // --------------------------
  Widget _buildSelectBox({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool disabled = false,   // add disabled flag
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,   //  prevent tapping if disabled
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: disabled ? Colors.grey.shade400 : Colors.blue,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: disabled ? Colors.grey.shade200 : Colors.white, //  grey out bg
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value.isNotEmpty ? value : label,
              style: TextStyle(
                fontSize: 16,
                color: disabled
                    ? Colors.grey
                    : (value.isNotEmpty ? Colors.black : Colors.grey.shade600),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: disabled ? Colors.grey : Colors.black,
            ),
          ],
        ),
      ),
    );
  }


  // When user toggles checkbox we must keep both selectedSectionsBySubject and sectionLimitsBySubject consistent
  void _toggleSectionSelection(String subjectId, String secId, bool checked) {
    setState(() {
      if (checked) {
        selectedSectionsBySubject.putIfAbsent(subjectId, () => {});
        selectedSectionsBySubject[subjectId]!.add(secId);

        sectionLimitsBySubject.putIfAbsent(subjectId, () => {});
        // keep existing limit if present, otherwise default 0
        final existing = sectionLimitsBySubject[subjectId]?[secId] ?? 0;
        sectionLimitsBySubject[subjectId]![secId] = existing;

        // ensure controller exists
        _limitControllers.putIfAbsent(subjectId, () => {});
        _limitControllers[subjectId]!.putIfAbsent(secId, () => TextEditingController(text: existing.toString()));
      } else {
        selectedSectionsBySubject[subjectId]?.remove(secId);
        sectionLimitsBySubject[subjectId]?.remove(secId);

        // dispose and remove controller
        final ctrl = _limitControllers[subjectId]?[secId];
        ctrl?.dispose();
        _limitControllers[subjectId]?.remove(secId);

        // cleanup empty maps
        if (selectedSectionsBySubject[subjectId]?.isEmpty ?? true) selectedSectionsBySubject.remove(subjectId);
        if (sectionLimitsBySubject[subjectId]?.isEmpty ?? true) sectionLimitsBySubject.remove(subjectId);
        if (_limitControllers[subjectId]?.isEmpty ?? true) _limitControllers.remove(subjectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Assign Mentors"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSelectBox(
            label: "Select School",
            value: selectedSchool?['name'] ?? "",
            onTap: () async {
              final schools = await _getSchools();
              final result = await _showSelectionDialog(
                title: "Select School",
                items: schools,
              );
              if (result != null) {
                setState(() {
                  selectedSchool = result;
                  selectedProgramme = null;
                  totalStudentsInProgramme = 0;
                });
              }
            },
          ),
            _buildSelectBox(
              label: "Select Programme",
              value: selectedProgramme?['name'] ?? "",
              disabled: selectedSchool == null,   //  greyed out if no school
              onTap: () async {
                if (selectedSchool == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please select a school first")),
                  );
                  return;
                }

                final progs = await _getProgrammes(selectedSchool!['id']);
                final result = await _showSelectionDialog(
                  title: "Select Programme",
                  items: progs,
                );
                if (result != null) {
                  setState(() {
                    selectedProgramme = result;
                  });
                  await _fetchTotalStudents(selectedSchool!['id'], selectedProgramme!['id']);
                  await _loadAssignments(selectedSchool!['id'], selectedProgramme!['id']);
                }
              },
            ),

          if (selectedProgramme != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Total Students in Programme: $totalStudentsInProgramme",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          if (selectedSchool != null && selectedProgramme != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search subjects...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  setState(() {
                    searchQuery = val.toLowerCase();
                  });
                },
              ),
            ),
          if (selectedSchool != null && selectedProgramme != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getSubjects(selectedSchool!['id'], selectedProgramme!['id']),
                builder: (ctx, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                  final subjects = snapshot.data!.docs.where((doc) {
                    final name = (doc['name'] ?? '').toString().toLowerCase();
                    final code = (doc['code'] ?? '').toString().toLowerCase();
                    return name.contains(searchQuery) || code.contains(searchQuery);
                  }).toList();

                  if (subjects.isEmpty) return Center(child: Text("No subjects found."));

                  return ListView(
                    children: subjects.map((doc) {
                      final subjectId = doc.id;
                      final subjectName = doc['name'] ?? '';
                      final subjectCode = doc['code'] ?? '';


                      final currLimits = sectionLimitsBySubject[subjectId] ?? {};
                      final currSelected = selectedSectionsBySubject[subjectId] ?? {};

                      // compute total using currLimits
                      final totalForSubject = currLimits.values.fold<int>(0, (a, b) => a + b);
                      final overLimit = totalForSubject > totalStudentsInProgramme;

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      subjectName,
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (subjectCode.isNotEmpty)
                                    Text(
                                      "($subjectCode)",   // e.g. Marketing (6001CEM)
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8),
                              // mentors dropdown
                              StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection("mentors")
                                    .where("programmeIds", arrayContains: selectedProgramme!['id'])
                                    .where("disabled", isEqualTo: false)
                                    .snapshots(),
                                builder: (ctx2, snapMentors) {
                                  if (!snapMentors.hasData) return SizedBox.shrink();
                                  final mentorDocs = snapMentors.data!.docs;

                                  // Remove duplicates (if any) and get unique mentor IDs
                                  final mentors = {
                                    for (var m in mentorDocs) m.id: m
                                  }.values.toList();

                                  // Ensure the current selected value exists in items
                                  final mentorValue = mentors.any((m) => m.id == selectedMentorBySubject[subjectId])
                                      ? selectedMentorBySubject[subjectId]
                                      : null;

                                  return DropdownSearch<String>(
                                    items: mentors.map((m) => m['name']?.toString() ?? '').toList(),
                                    selectedItem: mentorValue != null
                                        ? mentors
                                        .where((m) => m.id == mentorValue)
                                        .map((m) => m['name']?.toString())
                                        .firstOrNull // ✅ safe extension
                                        : null,
                                    popupProps: PopupProps.menu(
                                      showSearchBox: true,
                                      searchFieldProps: TextFieldProps(
                                        decoration: InputDecoration(
                                          hintText: "Search mentor...",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    dropdownDecoratorProps: DropDownDecoratorProps(
                                      dropdownSearchDecoration: InputDecoration(
                                        labelText: "Select Mentor",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final selected = mentors.firstWhere(
                                            (m) => (m['name']?.toString() ?? '') == val,
                                      );
                                      setState(() {
                                        selectedMentorBySubject[subjectId] = selected.id; // ✅ safe assign
                                      });
                                    },
                                  )
                                  ;
                                },
                              ),

                              SizedBox(height: 10),
                              // sections
                              StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('schools')
                                    .doc(selectedSchool!['id'])
                                    .collection('programmes')
                                    .doc(selectedProgramme!['id'])
                                    .collection('subjects')
                                    .doc(subjectId)
                                    .collection('sections')
                                    .snapshots(),
                                builder: (ctx3, secSnap) {
                                  if (!secSnap.hasData) return SizedBox.shrink();
                                  final sections = secSnap.data!.docs;

                                  return Column(
                                    children: sections.map((s) {
                                      final secId = s.id;
                                      final secName = s['name'] ?? '';

                                      final isSelected = currSelected.contains(secId);

                                      // ensure controller exists if selected OR if limit exists
                                      _limitControllers.putIfAbsent(subjectId, () => {});
                                      if (!_limitControllers[subjectId]!.containsKey(secId)) {
                                        final val = sectionLimitsBySubject[subjectId]?[secId] ?? 0;
                                        _limitControllers[subjectId]![secId] =
                                            TextEditingController(text: val.toString());
                                      }
                                      final controller = _limitControllers[subjectId]![secId]!;

                                      return Row(
                                        children: [
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (checked) {
                                              _toggleSectionSelection(subjectId, secId, checked ?? false);
                                            },
                                          ),
                                          Expanded(child: Text(secName)),
                                          SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(hintText: "Limit"),
                                              onChanged: (val) {
                                                final num = int.tryParse(val) ?? 0;
                                                setState(() {
                                                  sectionLimitsBySubject.putIfAbsent(subjectId, () => {});
                                                  sectionLimitsBySubject[subjectId]![secId] = num;
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text("/ $totalStudentsInProgramme"),
                                        ],
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Total assigned: $totalForSubject / $totalStudentsInProgramme",
                                style: TextStyle(
                                  color: overLimit ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

          if (selectedProgramme != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: _saveAssignments,
                icon: Icon(Icons.save),
                label: Text("Save Assignments"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white),
              ),
            ),

        ],
      ),
    );
  }
}
