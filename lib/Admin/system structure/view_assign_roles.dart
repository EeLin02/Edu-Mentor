import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectData {
  final String subjectId;
  final String subjectName;
  final String departmentId;
  final String departmentName;

  SubjectData({
    required this.subjectId,
    required this.subjectName,
    required this.departmentId,
    required this.departmentName,
  });
}

class AssignmentEntry {
  final String id;
  final String name;
  final String role; // "Student" or "Mentor"
  final String classId;
  final String className;
  final SubjectData subject;

  AssignmentEntry({
    required this.id,
    required this.name,
    required this.role,
    required this.classId,
    required this.className,
    required this.subject,
  });
}

class AssignmentsDashboardScreen extends StatefulWidget {
  @override
  _AssignmentsDashboardScreenState createState() => _AssignmentsDashboardScreenState();
}

class _AssignmentsDashboardScreenState extends State<AssignmentsDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<Map<String,
      Map<String,
          Map<String, List<AssignmentEntry>>>>> _futureGroupedAssignments;

  @override
  void initState() {
    super.initState();
    _futureGroupedAssignments = _fetchAndGroupAssignmentsByDepartment();
  }

  Future<String> _getUserName(String collection, String userId) async {
    final doc = await _firestore.collection(collection).doc(userId).get();
    if (doc.exists) {
      final data = doc.data()!;
      return data['name'] ?? 'Unknown Name';
    }
    return 'Unknown Name';
  }

  Future<String> _getClassName(String departmentId, String subjectId,
      String classId) async {
    final classDoc = await _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('classes')
        .doc(classId)
        .get();

    if (classDoc.exists && classDoc.data()!.containsKey('name')) {
      return classDoc.data()!['name'] as String;
    }
    return classId; // fallback to id if no name found
  }

  Future<SubjectData> _fetchSubjectData(String departmentId,
      String subjectId) async {
    final deptDoc = await _firestore
        .collection('departments')
        .doc(departmentId)
        .get();
    final departmentName = deptDoc.exists && deptDoc.data()!.containsKey('name')
        ? deptDoc.data()!['name'] as String
        : 'Unknown Department';

    final subjectDoc =
    await _firestore.collection('departments').doc(departmentId).collection(
        'subjects').doc(subjectId).get();
    final subjectName = subjectDoc.exists &&
        subjectDoc.data()!.containsKey('name')
        ? subjectDoc.data()!['name'] as String
        : 'Unknown Subject';

    return SubjectData(
      subjectId: subjectId,
      subjectName: subjectName,
      departmentId: departmentId,
      departmentName: departmentName,
    );
  }

  Future<Map<String,
      Map<String,
          Map<String,
              List<
                  AssignmentEntry>>>>> _fetchAndGroupAssignmentsByDepartment() async {
    Map<String, Map<String, Map<String, List<AssignmentEntry>>>> grouped = {};

    final enrollmentsSnapshot = await _firestore.collection(
        'subjectEnrollments').get();
    for (var doc in enrollmentsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final departmentId = data['departmentId'];
      final subjectId = data['subjectId'];
      final studentId = data['studentId'];
      final classId = data['classId'];

      final studentName = await _getUserName('students', studentId);
      final subject = await _fetchSubjectData(departmentId, subjectId);
      final className = await _getClassName(departmentId, subjectId, classId);

      final entry = AssignmentEntry(
        id: studentId,
        name: studentName,
        role: 'Student',
        classId: classId,
        className: className,
        subject: subject,
      );

      grouped.putIfAbsent(departmentId, () => {});
      grouped[departmentId]!.putIfAbsent(subjectId, () => {});
      grouped[departmentId]![subjectId]!.putIfAbsent(classId, () => []);
      grouped[departmentId]![subjectId]![classId]!.add(entry);
    }

    final mentorsSnapshot = await _firestore.collection('subjectMentors').get();
    for (var doc in mentorsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final departmentId = data['departmentId'];
      final subjectId = data['subjectId'];
      final mentorId = data['mentorId'];
      final classId = data['classId'] ??
          'No Class'; // use 'No Class' if not assigned

      final mentorName = await _getUserName('mentors', mentorId);
      final subject = await _fetchSubjectData(departmentId, subjectId);
      final className = classId == 'No Class'
          ? 'No Class'
          : await _getClassName(departmentId, subjectId, classId);

      final entry = AssignmentEntry(
        id: mentorId,
        name: mentorName,
        role: 'Mentor',
        classId: classId,
        className: className,
        subject: subject,
      );

      grouped.putIfAbsent(departmentId, () => {});
      grouped[departmentId]!.putIfAbsent(subjectId, () => {});
      grouped[departmentId]![subjectId]!.putIfAbsent(classId, () => []);
      if (!grouped[departmentId]![subjectId]![classId]!.any((e) =>
      e.id == mentorId && e.role == 'Mentor')) {
        grouped[departmentId]![subjectId]![classId]!.add(entry);
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assignments Overview',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.lightBlue[100],
        elevation: 4,
      ),
      body: FutureBuilder<
          Map<String, Map<String, Map<String, List<AssignmentEntry>>>>>(
        future: _futureGroupedAssignments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(
                color: Colors.indigo.shade700));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.redAccent)),
            );
          }

          final grouped = snapshot.data ?? {};
          if (grouped.isEmpty) {
            return Center(
              child: Text(
                'No assignments found.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            );
          }

          final sortedDeptIds = grouped.keys.toList()
            ..sort((a, b) {
              final aName = grouped[a]!.values.first.values.first[0].subject
                  .departmentName;
              final bName = grouped[b]!.values.first.values.first[0].subject
                  .departmentName;
              return aName.compareTo(bName);
            });

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: sortedDeptIds.length,
            itemBuilder: (context, deptIndex) {
              final deptId = sortedDeptIds[deptIndex];
              final subjectsMap = grouped[deptId]!;

              final sortedSubjectIds = subjectsMap.keys.toList()
                ..sort((a, b) {
                  final aName = subjectsMap[a]!.values.first[0].subject
                      .subjectName;
                  final bName = subjectsMap[b]!.values.first[0].subject
                      .subjectName;
                  return aName.compareTo(bName);
                });

              return Card(
                margin: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 5,
                shadowColor: Colors.indigo.shade200,
                child: Theme(
                  data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    collapsedBackgroundColor: Colors.indigo.shade100,
                    backgroundColor: Colors.indigo.shade50,
                    collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      subjectsMap.values.first.values.first[0].subject
                          .departmentName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    children: sortedSubjectIds.where((subjectId) {
                      final classesMap = subjectsMap[subjectId]!;
                      return classesMap.values.any((entries) =>
                      entries.isNotEmpty);
                    }).map((subjectId) {
                      final classesMap = subjectsMap[subjectId]!;
                      final sortedClassIds = classesMap.keys
                          .where((classId) =>
                      classId != 'No Class') // filter out no class
                          .toList()
                        ..sort();

                      final subjectName = classesMap.values.first[0].subject
                          .subjectName;

                      //shows mentors name
                      final mentors = classesMap.entries
                          .expand((entry) => entry.value)
                          .where((e) => e.role == 'Mentor')
                          .toList();

                      return Padding(
                        padding: const EdgeInsets.only(
                            left: 12, right: 12, bottom: 8),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            collapsedBackgroundColor: Colors.indigo.shade200,
                            backgroundColor: Colors.indigo.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subjectName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.indigo.shade900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (mentors.isNotEmpty)
                                  ...mentors.map((mentor) =>
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8.0),
                                        child: Text(
                                          mentor.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.indigo.shade900,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )),
                              ],
                            ),

                            children: sortedClassIds.where((classId) {
                              final entries = classesMap[classId]!;
                              return entries.any((e) =>
                              e.role == 'Student'); // only show classes with students
                            }).map((classId) {
                              final entries = classesMap[classId]!;

                              // only keep students
                              final studentEntries = entries.where((e) =>
                              e.role == 'Student').toList();
                              studentEntries.sort((a, b) =>
                                  a.name.compareTo(b.name));

                              final studentCount = studentEntries.length;

                              return Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.indigo.shade100,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Class: ${studentEntries[0]
                                              .className}',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.indigo.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade200,
                                          borderRadius: BorderRadius.circular(
                                              12),
                                        ),
                                        child: Text(
                                          'Students: $studentCount',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.indigo.shade900,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: studentEntries.map((entry) {
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.blue.shade400,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      title: Text(
                                        entry.name,
                                        style: TextStyle(
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      dense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 0),
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}