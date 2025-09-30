import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSectionsScreen extends StatefulWidget {
  @override
  _ManageSectionsScreenState createState() => _ManageSectionsScreenState();
}

class _ManageSectionsScreenState extends State<ManageSectionsScreen> {
  final TextEditingController sectionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // IDs (used for Firestore queries)
  String? selectedSchoolId;
  String? selectedProgrammeId;
  String? selectedSubjectId;

  // Names (used for UI display)
  String? selectedSchoolName;
  String? selectedProgrammeName;
  String? selectedSubjectName;

  String searchQuery = "";

  // 🔹 For time slot creation
  String? selectedDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<Map<String, String>> sectionTimes = [];


  // 🔹 Utility to safely get "name"
  String _getName(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('name')
        ? data['name'] as String
        : 'Unnamed';
  }

  // 🔹 Reusable Searchable Dialog
  Future<Map<String, dynamic>?> _showSearchableDialog(
      BuildContext context, String title, List<Map<String, dynamic>> items) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        TextEditingController searchCtrl = TextEditingController();
        List<Map<String, dynamic>> filtered = List.from(items);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Select $title"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search $title...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        filtered = items
                            .where((s) =>
                            s['name'].toLowerCase().contains(val.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 300,
                    width: double.maxFinite,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final code = filtered[i]['code'];
                        final name = filtered[i]['name'];

                        return ListTile(
                          title: Text(
                            code != null && code.toString().isNotEmpty
                                ? "$code - $name"
                                : name, // ✅ only show code if exists
                          ),
                          onTap: () => Navigator.pop(context, filtered[i]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // 🔹 Styled field
  Widget _buildSelectionField({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value ?? "Select $label",
                    style: TextStyle(
                      fontSize: 15,
                      color: value == null ? Colors.grey.shade500 : Colors.black,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔹 Edit Section
  void _editSection(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final currentName = data['name'] ?? '';
    final editController = TextEditingController(text: currentName);

    // Safely convert Firestore list to List<Map<String, String>>
    List<Map<String, dynamic>> times = (data['times'] as List<dynamic>?)
        ?.map((t) => {
      "day": t["day"] ?? "",
      "start": t["start"] ?? "",
      "end": t["end"] ?? "",
    })
        .toList() ??
        [];

    showDialog(
      context: context,
      builder: (_) {
        String? selectedDay;
        TimeOfDay? start;
        TimeOfDay? end;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit Section"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                        controller: editController,
                        decoration: InputDecoration(labelText: "Section Name")),

                    SizedBox(height: 12),

                    // ✅ Show existing times
                    if (times.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: times.map((t) {
                          return ListTile(
                            title: Text("${t['day']} • ${t['start']} - ${t['end']}"),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setDialogState(() => times.remove(t));
                              },
                            ),
                          );
                        }).toList(),
                      ),

                    SizedBox(height: 12),

                    // Add new time slot
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: "Day"),
                      value: selectedDay,
                      items: [
                        "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
                      ].map((day) =>
                          DropdownMenuItem(value: day, child: Text(day)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedDay = val),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                  context: context, initialTime: TimeOfDay.now());
                              if (picked != null) setDialogState(() => start = picked);
                            },
                            child: Text(start == null
                                ? "Start Time"
                                : "Start: ${start!.format(context)}"),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                  context: context, initialTime: TimeOfDay.now());
                              if (picked != null) setDialogState(() => end = picked);
                            },
                            child: Text(end == null
                                ? "End Time"
                                : "End: ${end!.format(context)}"),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedDay != null && start != null && end != null) {
                          setDialogState(() {
                            times.add({
                              "day": selectedDay!,
                              "start": start!.format(context),
                              "end": end!.format(context),
                            });
                            selectedDay = null;
                            start = null;
                            end = null;
                          });
                        }
                      },
                      child: Text("Add Time Slot"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    final newName = editController.text.trim();
                    await doc.reference.update({
                      'name': newName,
                      'times': times,
                    });
                    Navigator.pop(context);
                  },
                  child: Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // 🔹 Confirm Delete
  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Delete this section?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Delete")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    sectionController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Sections")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            /// --- School ---
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('schools')
                  .orderBy('name')
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final schools = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'name': data['name'] ?? 'Unnamed',
                  };
                }).toList();

                return _buildSelectionField(
                  label: "School",
                  value: selectedSchoolName,
                  onTap: () async {
                    final selected =
                    await _showSearchableDialog(context, "School", schools);
                    if (selected != null) {
                      setState(() {
                        selectedSchoolId = selected['id'];
                        // only show name for school (not code)
                        selectedSchoolName = selected['name'];
                        selectedProgrammeId = null;
                        selectedProgrammeName = null;
                        selectedSubjectId = null;
                        selectedSubjectName = null;
                      });
                    }
                  },
                );
              },
            ),

            SizedBox(height: 12),

            /// --- Programme ---
            if (selectedSchoolId != null)
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(selectedSchoolId)
                    .collection('programmes')
                    .orderBy('name')
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final programmes = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {'id': doc.id, 'name': data['name'] ?? 'Unnamed'};
                  }).toList();

                  return _buildSelectionField(
                    label: "Programme",
                    value: selectedProgrammeName,
                    onTap: () async {
                      final selected = await _showSearchableDialog(
                          context, "Programme", programmes);
                      if (selected != null) {
                        setState(() {
                          selectedProgrammeId = selected['id'];
                          selectedProgrammeName = selected['name'];
                          selectedSubjectId = null;
                          selectedSubjectName = null;
                        });
                      }
                    },
                  );
                },
              ),
            SizedBox(height: 12),

            /// --- Subject ---
            if (selectedProgrammeId != null)
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(selectedSchoolId)
                    .collection('programmes')
                    .doc(selectedProgrammeId)
                    .collection('subjects')
                    .orderBy('name')
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final subjects = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    print("Subject data: $data");  // 👀 debug output
                    return {
                      'id': doc.id,
                      'name': data['name'] ?? 'Unnamed',
                      'code': data.containsKey('code') ? data['code'] : 'NoCode',
                    };
                  }).toList();

                  return _buildSelectionField(
                    label: "Subject",
                    value: selectedSubjectName,
                    onTap: () async {
                      final selected =
                      await _showSearchableDialog(context, "Subject", subjects);
                      if (selected != null) {
                        setState(() {
                          selectedSubjectId = selected['id'];
                          selectedSubjectName =
                          "${selected['code']} - ${selected['name']}"; // ✅ show ABC123 - Mathematics
                        });
                      }
                    },
                  );
                },
              ),

            SizedBox(height: 12),

            /// --- Section Input ---
            TextField(
              controller: sectionController,
              decoration: InputDecoration(
                labelText: "Section Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),

            /// --- Time Picker for Section ---
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Day"),
              value: selectedDay,
              items: [
                "Monday",
                "Tuesday",
                "Wednesday",
                "Thursday",
                "Friday",
                "Saturday",
                "Sunday"
              ]
                  .map((day) =>
                  DropdownMenuItem(value: day, child: Text(day)))
                  .toList(),
              onChanged: (val) => setState(() => selectedDay = val),
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: TimeOfDay.now());
                      if (picked != null) setState(() => startTime = picked);
                    },
                    child: Text(startTime == null
                        ? "Select Start Time"
                        : "Start: ${startTime!.format(context)}"),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: TimeOfDay.now());
                      if (picked != null) setState(() => endTime = picked);
                    },
                    child: Text(endTime == null
                        ? "Select End Time"
                        : "End: ${endTime!.format(context)}"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            ElevatedButton(
              onPressed: () {
                if (selectedDay != null && startTime != null && endTime != null) {
                  setState(() {
                    sectionTimes.add({
                      "day": selectedDay!,
                      "start": startTime!.format(context),
                      "end": endTime!.format(context),
                    });
                    selectedDay = null;
                    startTime = null;
                    endTime = null;
                  });
                }
              },
              child: Text("Add Time Slot"),
            ),
            SizedBox(height: 12),

            if (sectionTimes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sectionTimes
                    .map((t) => ListTile(
                  title: Text(
                      "${t['day']} • ${t['start']} - ${t['end']}"),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() => sectionTimes.remove(t));
                    },
                  ),
                ))
                    .toList(),
              ),

            SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                final name = sectionController.text.trim();
                if (name.isNotEmpty &&
                    selectedSchoolId != null &&
                    selectedProgrammeId != null &&
                    selectedSubjectId != null) {
                  final newSectionRef = await FirebaseFirestore.instance
                      .collection('schools')
                      .doc(selectedSchoolId)
                      .collection('programmes')
                      .doc(selectedProgrammeId)
                      .collection('subjects')
                      .doc(selectedSubjectId)
                      .collection('sections')
                      .add({
                    'name': name,
                    'times': sectionTimes,
                  });

                  await newSectionRef.update({'sectionId': newSectionRef.id});
                  sectionController.clear();
                  setState(() {
                    sectionTimes.clear();
                  });
                }
              },
              child: Text("Add Section"),
            ),
            SizedBox(height: 16),

            /// --- Search ---
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Sections",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
            SizedBox(height: 12),

            /// --- Section List ---
            if (selectedSubjectId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(selectedSchoolId)
                    .collection('programmes')
                    .doc(selectedProgrammeId)
                    .collection('subjects')
                    .doc(selectedSubjectId)
                    .collection('sections')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(child: CircularProgressIndicator());

                  final filteredSections = snapshot.data!.docs.where((doc) {
                    final name = _getName(doc).toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  if (filteredSections.isEmpty) {
                    return Center(child: Text("No sections found."));
                  }

                  return Column(
                    children: filteredSections.map((doc) {
                      final name = _getName(doc);
                      return ListTile(
                        title: Text(name),   // <-- This will now show "B1"
                        subtitle: (doc.data() as Map<String, dynamic>)['times'] != null &&
                            ((doc.data() as Map<String, dynamic>)['times'] as List).isNotEmpty
                            ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: (doc.data() as Map<String, dynamic>)['times']
                              .map<Widget>((t) => Text(
                            "${t['day']} • ${t['start']} - ${t['end']}",
                          ))
                              .toList(),
                        )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editSection(doc),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmed = await _showDeleteConfirmDialog();
                                if (confirmed == true) {
                                  await doc.reference.delete();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
