import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentEntry {
  final String id;
  final String name;
  final String role; // "Student" or "Mentor"
  final String schoolId;
  final String programmeId;
  final String subjectId;
  final String sectionId;
  final String studentIdNo;

  AssignmentEntry({
    required this.id,
    required this.name,
    required this.role,
    required this.schoolId,
    required this.programmeId,
    required this.subjectId,
    required this.sectionId,
    this.studentIdNo = '',
  });
}

class AssignmentsDashboardScreen extends StatefulWidget {
  @override
  _AssignmentsDashboardScreenState createState() =>
      _AssignmentsDashboardScreenState();
}

class _AssignmentsDashboardScreenState
    extends State<AssignmentsDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Overlay stuff
  final LayerLink _schoolLink = LayerLink();
  OverlayEntry? _schoolOverlay;

  final LayerLink _programmeLink = LayerLink();
  OverlayEntry? _programmeOverlay;

  String selectedSchoolId = '';
  String selectedProgrammeId = '';
  String searchQuery = '';

  List<Map<String, dynamic>> schools = [];
  List<Map<String, dynamic>> programmes = [];

  late Future<List<AssignmentEntry>> _futureAssignments;

  // 🔹 make cache available everywhere
  final Map<String, String> subjectNameCache = {};

  // Controllers
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _programmeController = TextEditingController();

 // Autocomplete filtered lists
  List<Map<String, dynamic>> filteredSchools = [];
  List<Map<String, dynamic>> filteredProgrammes = [];

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _programmeController.dispose();
    super.dispose();
  }

  void _showSchoolOverlay() {
    _hideSchoolOverlay();

    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _schoolLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            child: ListView(
              shrinkWrap: true,
                children: filteredSchools.isEmpty
                ? [ListTile(title: Text("No schools found"))]
                    : filteredSchools.map((school) {
                return ListTile(
                  title: Text(school['name']),
                  onTap: () {
                    setState(() {
                      selectedSchoolId = school['id'];
                      _schoolController.text = school['name'];
                      filteredSchools = schools;
                      selectedProgrammeId = '';
                      _programmeController.clear();
                      _futureAssignments = Future.value([]); // reset until programme chosen
                      _loadProgrammes(selectedSchoolId);
                    });
                    _hideSchoolOverlay();  //  close overlay after selection
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    _schoolOverlay = overlay;
  }

  void _hideSchoolOverlay() {
    _schoolOverlay?.remove();
    _schoolOverlay = null;
  }

  void _showProgrammeOverlay() {
    _hideProgrammeOverlay();

    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _programmeLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            child: ListView(
              shrinkWrap: true,
              children: filteredProgrammes.map((programme) {
                return ListTile(
                  title: Text(programme['name']),
                  onTap: () {
                    setState(() {
                      selectedProgrammeId = programme['id'];
                      _programmeController.text = programme['name'];
                      filteredProgrammes = programmes;
                      _futureAssignments = _fetchAssignments();
                    });
                    _hideProgrammeOverlay();
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    _programmeOverlay = overlay;
  }

  void _hideProgrammeOverlay() {
    _programmeOverlay?.remove();
    _programmeOverlay = null;
  }



  Future<void> _loadSchools() async {
    final snapshot = await _firestore.collection('schools').get();
    setState(() {
      schools = snapshot.docs
          .map((d) => {'id': d.id, 'name': d['name'] ?? 'Unnamed School'})
          .toList();
    });
  }

  Future<void> _loadProgrammes(String schoolId) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('programmes')
        .get();
    setState(() {
      programmes = snapshot.docs
          .map((d) => {'id': d.id, 'name': d['name'] ?? 'Unnamed Programme'})
          .toList();
    });
  }

  Future<Map<String, dynamic>> _loadUserNames(String collection) async {
    final snapshot = await _firestore.collection(collection).get();
    final map = <String, dynamic>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['disabled'] != true) {
        map[doc.id] = {
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'studentIdNo': data['studentIdNo'] ?? '',
        };
      }
    }
    return map;
  }


  Future<String> _getSubjectName(String schoolId, String programmeId, String subjectId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('programmes')
          .doc(programmeId)
          .collection('subjects')
          .doc(subjectId)
          .get();
      if (doc.exists) {
        final name = doc['name'] ?? subjectId;
        final code = doc['code'] ?? '';
        return code.isNotEmpty ? "$name ($code)" : name;
      }
    } catch (_) {}
    return subjectId;
  }


  Future<String> _getSectionName(String schoolId, String programmeId, String subjectId, String sectionId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('programmes')
          .doc(programmeId)
          .collection('subjects')
          .doc(subjectId)
          .collection('sections')
          .doc(sectionId)
          .get();
      if (doc.exists) return doc['name'] ?? sectionId;
    } catch (_) {}
    return sectionId;
  }


  Future<List<AssignmentEntry>> _fetchAssignments() async {
    final studentData = await _loadUserNames("students");
    final mentorData = await _loadUserNames("mentors");

    List<AssignmentEntry> entries = [];

    // 🔹 Students
    Query studentQuery = _firestore.collection('subjectEnrollments');
    if (selectedSchoolId.isNotEmpty) {
      studentQuery = studentQuery.where('schoolId', isEqualTo: selectedSchoolId);
    }
    if (selectedProgrammeId.isNotEmpty) {
      studentQuery = studentQuery.where('programmeId', isEqualTo: selectedProgrammeId);
    }

    final enrollSnap = await studentQuery.get();
    for (var doc in enrollSnap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final sid = d['studentId'];
      if (sid == null || !studentData.containsKey(sid)) continue;

      final sName = studentData[sid]['name'] ?? 'Unknown';
      final sEmail = studentData[sid]['email'] ?? '';
      final sIdNo = studentData[sid]['studentIdNo'] ?? '';
      final displayName = sEmail.isNotEmpty ? "$sName ($sEmail)" : sName;

      entries.add(AssignmentEntry(
        id: sid,
        name: displayName,
        role: 'Student',
        schoolId: d['schoolId'],
        programmeId: d['programmeId'],
        subjectId: d['subjectId'],
        sectionId: d['sectionId'] ?? '',
        studentIdNo: sIdNo,
      ));
    }

    // 🔹 Mentors
    Query mentorQuery = _firestore.collection('subjectMentors');
    if (selectedSchoolId.isNotEmpty) {
      mentorQuery = mentorQuery.where('schoolId', isEqualTo: selectedSchoolId);
    }
    if (selectedProgrammeId.isNotEmpty) {
      mentorQuery = mentorQuery.where('programmeId', isEqualTo: selectedProgrammeId);
    }

    final mentorSnap = await mentorQuery.get();
    for (var doc in mentorSnap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final mid = d['mentorId'];
      if (mid == null || !mentorData.containsKey(mid)) continue;

      final mName = mentorData[mid]['name'] ?? 'Unknown';
      final mEmail = mentorData[mid]['email'] ?? '';
      final displayName = mEmail.isNotEmpty ? "$mName ($mEmail)" : mName;

      entries.add(AssignmentEntry(
        id: mid,
        name: displayName,
        role: 'Mentor',
        schoolId: d['schoolId'],
        programmeId: d['programmeId'],
        subjectId: d['subjectId'],
        sectionId: d['sectionId'] ?? '',
      ));
    }

    //  Cache subject names
    for (var e in entries) {
      if (!subjectNameCache.containsKey(e.subjectId)) {
        subjectNameCache[e.subjectId] =
        await _getSubjectName(e.schoolId, e.programmeId, e.subjectId);
      }
    }

    return entries;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Assignments Overview"),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus(); // close keyboard
            _hideSchoolOverlay();
            _hideProgrammeOverlay();
          },
          child: Column(
            children: [
          // 🔹 School Search Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Select School"),
                CompositedTransformTarget(
                  link: _schoolLink,
                  child: TextField(
                    controller: _schoolController,
                    decoration: InputDecoration(
                      hintText: "Type school name",
                      prefixIcon: Icon(Icons.school),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () {
                      setState(() => filteredSchools = schools);
                      _showSchoolOverlay();
                    },
                    onChanged: (val) {
                      setState(() {
                        if (val.isEmpty) {
                          // Reset to show full list when field is cleared
                          filteredSchools = schools;
                        } else {
                          filteredSchools = schools
                              .where((s) =>
                              (s['name'] as String).toLowerCase().contains(val.toLowerCase()))
                              .toList();
                        }
                      });
                      _showSchoolOverlay();
                    },
                  ),
                ),
              ],
            ),
          ),


// 🔹 Programme Search Field
          if (selectedSchoolId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Select Programme"),
                  CompositedTransformTarget(
                    link: _programmeLink,
                    child: TextField(
                      controller: _programmeController,
                      decoration: InputDecoration(
                        hintText: "Type programme name",
                        prefixIcon: Icon(Icons.menu_book),
                        border: OutlineInputBorder(),
                      ),
                      onTap: () {
                        setState(() => filteredProgrammes = programmes);
                        _showProgrammeOverlay();
                      },
                      onChanged: (val) {
                        setState(() {
                          if (val.isEmpty) {
                            filteredProgrammes = programmes;
                          } else {
                            filteredProgrammes = programmes
                                .where((p) =>
                                (p['name'] as String).toLowerCase().contains(val.toLowerCase()))
                                .toList();
                          }
                        });
                        _showProgrammeOverlay();
                      },
                    ),
                  ),
                ],
              ),
            ),



          // 🔹 Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search by Subject Name or Mentor Name",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) =>
                  setState(() => searchQuery = val.toLowerCase()),
            ),
          ),

          // 🔹 Data View
          Expanded(
            child: (selectedSchoolId.isEmpty || selectedProgrammeId.isEmpty)
                ? Center(
              child: Text(
                "Please select a school and programme",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            )
                : FutureBuilder<List<AssignmentEntry>>(
              future: _futureAssignments,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var entries = snapshot.data!;

                // Filters
                if (searchQuery.isNotEmpty) {
                  entries = entries.where((e) {
                    final subjName = subjectNameCache[e.subjectId]?.toLowerCase() ?? '';
                    final matchesSubject = subjName.contains(searchQuery);
                    final matchesMentor = e.role == 'Mentor' && e.name.toLowerCase().contains(searchQuery);
                    return matchesSubject || matchesMentor;
                  }).toList();
                }


                if (entries.isEmpty) {
                  return Center(child: Text("No assignments found."));
                }

                // Group by subject → section
                final Map<String, Map<String, List<AssignmentEntry>>> grouped =
                {};
                for (var e in entries) {
                  grouped.putIfAbsent(e.subjectId, () => {});
                  grouped[e.subjectId]!.putIfAbsent(e.sectionId, () => []);
                  grouped[e.subjectId]![e.sectionId]!.add(e);
                }

                return ListView(
                  children: grouped.entries.map((subjectEntry) {
                    final subjectId = subjectEntry.key;
                    final sections = subjectEntry.value;

                    // Mentors unique per subject
                    final Map<String, Set<String>> mentorSections = {};
                    for (var secEntry in sections.entries) {
                      for (var e in secEntry.value) {
                        if (e.role == 'Mentor') {
                          mentorSections.putIfAbsent(e.name, () => {});
                          mentorSections[e.name]!.add(e.sectionId);
                        }
                      }
                    }

                    final firstEntry = sections.values.first.first;
                    return FutureBuilder<String>(
                      future: _getSubjectName(firstEntry.schoolId, firstEntry.programmeId, subjectId),
                      builder: (context, subjectSnap) {
                        final subjectName = subjectSnap.data ?? subjectId;


                        return Card(
                          margin: EdgeInsets.all(10),
                          child: ExpansionTile(
                            title: Text("Subject: $subjectName"),
                            subtitle: mentorSections.isNotEmpty
                                ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: mentorSections.entries.map((m) {
                                final mentorName = m.key;
                                final sectionIds = m.value.toList();

                                // Fetch all section names
                                return FutureBuilder<List<String>>(
                                  future: Future.wait(sectionIds.map((secId) {
                                    final firstEntry = sections[secId]!.first;
                                    return _getSectionName(
                                      firstEntry.schoolId,
                                      firstEntry.programmeId,
                                      subjectId,
                                      secId,
                                    );
                                  })),
                                  builder: (context, secSnap) {
                                    if (!secSnap.hasData) return Text("$mentorName (Loading sections...)");
                                    final sectionNames = secSnap.data!;
                                    return Text(
                                      "$mentorName (Sections: ${sectionNames.join(', ')})",
                                      style: TextStyle(fontSize: 13),
                                    );
                                  },
                                );
                              }).toList(),
                            )
                                : Text("No mentors assigned"),

                            children: sections.entries.map((secEntry) {
                              final sectionId = secEntry.key;
                              final students = secEntry.value
                                  .where((e) => e.role == 'Student')
                                  .toList();

                              final firstEntry = secEntry.value.first;
                              return FutureBuilder<String>(
                                future: _getSectionName(
                                  firstEntry.schoolId,
                                  firstEntry.programmeId,
                                  subjectId,
                                  sectionId,
                                ),
                                builder: (context, secSnap) {
                                  final sectionName = secSnap.data ?? sectionId;


                                  return ListTile(
                                    title: Text(
                                        "Section: $sectionName (Students: ${students.length})"),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SectionDetailsScreen(
                                            subjectName: subjectName,
                                            sectionName: sectionName,
                                            mentors: mentorSections.keys
                                                .toList(),
                                            students: students,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    )
    );
  }
}

/// 🔹 Details Screen
class SectionDetailsScreen extends StatefulWidget {
  final String subjectName;
  final String sectionName;
  final List<String> mentors;
  final List<AssignmentEntry> students;

  SectionDetailsScreen({
    required this.subjectName,
    required this.sectionName,
    required this.mentors,
    required this.students,
  });

  @override
  _SectionDetailsScreenState createState() => _SectionDetailsScreenState();
}

class _SectionDetailsScreenState extends State<SectionDetailsScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    var filtered = widget.students;
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((s) =>
      s.name.toLowerCase().contains(searchQuery) ||
          s.studentIdNo.toLowerCase().contains(searchQuery))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.subjectName} - ${widget.sectionName}"), // ✅ AppBar shows both
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Subject + Section + Mentors block
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Subject: ${widget.subjectName}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text("Section: ${widget.sectionName}",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                if (widget.mentors.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text("Mentors: ${widget.mentors.join(', ')}"),
                ]
              ],
            ),
          ),

          // 🔎 Search bar
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search Student",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) =>
                  setState(() => searchQuery = val.toLowerCase()),
            ),
          ),

          // 👩‍🎓 Student list
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final s = filtered[i];
                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text(s.name),
                  subtitle: Text("ID: ${s.studentIdNo}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
