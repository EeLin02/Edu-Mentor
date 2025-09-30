import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSubjectsScreen extends StatefulWidget {
  @override
  _ManageSubjectsScreenState createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends State<ManageSubjectsScreen> {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String? selectedSchool;
  String? selectedProgramme;


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getFieldName(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('name')
        ? data['name'] as String
        : 'Unnamed';
  }

  String _getFieldCode(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('code')
        ? data['code'] as String
        : 'NoCode';
  }

  /// ------------------------------
  /// Searchable Dialog for Schools
  /// ------------------------------
  void openSchoolSelectionDialog(List<QueryDocumentSnapshot> schools) async {
    final selectedId = await showDialog<String>(
      context: context,
      builder: (context) {
        String? tempSelected = selectedSchool;
        List<QueryDocumentSnapshot> filteredSchools = List.from(schools);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Select School"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Search schools",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          filteredSchools = schools
                              .where((doc) => doc['name']
                              .toString()
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: filteredSchools.map((doc) {
                          return RadioListTile<String>(
                            title: Text(doc['name']),
                            value: doc.id,
                            groupValue: tempSelected,
                            onChanged: (val) {
                              setStateDialog(() {
                                tempSelected = val;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: Text("Select"),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedId != null) {
      setState(() {
        selectedSchool = selectedId;
        selectedProgramme = null; // reset programme
      });
    }
  }

  /// ------------------------------
  /// Searchable Dialog for Programmes
  /// ------------------------------
  void openProgrammeSelectionDialog(List<QueryDocumentSnapshot> progs) async {
    final selectedId = await showDialog<String>(
      context: context,
      builder: (context) {
        String? tempSelected = selectedProgramme;
        List<QueryDocumentSnapshot> filteredProgs = List.from(progs);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Select Programme"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Search programmes",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          filteredProgs = progs
                              .where((doc) => doc['name']
                              .toString()
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: filteredProgs.map((doc) {
                          return RadioListTile<String>(
                            title: Text(doc['name']),
                            value: doc.id,
                            groupValue: tempSelected,
                            onChanged: (val) {
                              setStateDialog(() {
                                tempSelected = val;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: Text("Select"),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedId != null) {
      setState(() {
        selectedProgramme = selectedId;
      });
    }
  }

  /// ------------------------------
  /// Edit Subject Dialog
  /// ------------------------------
  void _showEditDialog(String subjectId, String currentName, String currentCode) {
    final TextEditingController editNameController =
    TextEditingController(text: currentName);
    final TextEditingController editCodeController =
    TextEditingController(text: currentCode);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Subject"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editCodeController,
              decoration: InputDecoration(
                labelText: "Subject Code",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: editNameController,
              decoration: InputDecoration(
                labelText: "Subject Name",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = editNameController.text.trim();
              final newCode = editCodeController.text.trim();
              if (newName.isNotEmpty &&
                  newCode.isNotEmpty &&
                  selectedSchool != null &&
                  selectedProgramme != null) {
                await _firestore
                    .collection('schools')
                    .doc(selectedSchool)
                    .collection('programmes')
                    .doc(selectedProgramme)
                    .collection('subjects')
                    .doc(subjectId)
                    .update({
                  'name': newName,
                  'code': newCode,
                });
                Navigator.pop(context);
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    subjectController.dispose();
    codeController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Subjects")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// --- School Selection ---
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('schools').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final schools = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("School",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => openSchoolSelectionDialog(schools),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedSchool == null
                                  ? "Select School"
                                  : schools.firstWhere((s) => s.id == selectedSchool)['name'],
                              style: TextStyle(
                                fontSize: 15,
                                color: selectedSchool == null
                                    ? Colors.grey.shade500
                                    : Colors.black,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 16),

            /// --- Programme Selection ---
            if (selectedSchool != null)
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('schools')
                    .doc(selectedSchool)
                    .collection('programmes')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final progs = snapshot.data!.docs;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Programme",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => openProgrammeSelectionDialog(progs),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedProgramme == null
                                    ? "Select Programme"
                                    : progs.firstWhere((p) => p.id == selectedProgramme)['name'],
                                style: TextStyle(
                                  fontSize: 15,
                                  color: selectedProgramme == null
                                      ? Colors.grey.shade500
                                      : Colors.black,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            /// --- Subject Code Input ---
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: "Subject Code (e.g. AUG6001 CEM)",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),

            /// --- Subject Name Input ---
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                labelText: "Subject Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                final name = subjectController.text.trim();
                final code = codeController.text.trim();

                if (name.isNotEmpty &&
                    code.isNotEmpty &&
                    selectedSchool != null &&
                    selectedProgramme != null) {
                  final newSubjectRef = await _firestore
                      .collection('schools')
                      .doc(selectedSchool)
                      .collection('programmes')
                      .doc(selectedProgramme)
                      .collection('subjects')
                      .add({
                    'name': name,
                    'code': code,
                  });

                  await newSubjectRef.update({'subjectId': newSubjectRef.id});
                  subjectController.clear();
                  codeController.clear();
                }
              },
              child: Text("Add Subject"),
            ),
            SizedBox(height: 16),

            /// --- Search Field ---
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Subject",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16),

            /// --- Subject List ---
            if (selectedSchool != null && selectedProgramme != null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('schools')
                      .doc(selectedSchool)
                      .collection('programmes')
                      .doc(selectedProgramme)
                      .collection('subjects')
                      .orderBy('code')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final subjects = snapshot.data!.docs.where((doc) {
                      final name = _getFieldName(doc).toLowerCase();
                      final code = _getFieldCode(doc).toLowerCase();
                      final query = searchController.text.toLowerCase();
                      return name.contains(query) || code.contains(query);
                    }).toList();

                    if (subjects.isEmpty) {
                      return Center(child: Text("No subjects found."));
                    }

                    return ListView.builder(
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        final name = _getFieldName(subject);
                        final code = _getFieldCode(subject);

                        return ListTile(
                          title: Text("$code - $name"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _showEditDialog(subject.id, name, code),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text("Confirm Delete"),
                                      content: Text("Delete this subject?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _firestore
                                        .collection('schools')
                                        .doc(selectedSchool)
                                        .collection('programmes')
                                        .doc(selectedProgramme)
                                        .collection('subjects')
                                        .doc(subject.id)
                                        .delete();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
