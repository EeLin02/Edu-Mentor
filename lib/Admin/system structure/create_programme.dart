import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageProgrammesScreen extends StatefulWidget {
  final String? schoolId;   // optional, in case you pass from a school tile
  final String? schoolName; // optional

  ManageProgrammesScreen({this.schoolId, this.schoolName});

  @override
  _ManageProgrammesScreenState createState() => _ManageProgrammesScreenState();
}

class _ManageProgrammesScreenState extends State<ManageProgrammesScreen> {
  final TextEditingController programmeController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String? selectedSchoolId;
  String? selectedSchoolName;

  @override
  void initState() {
    super.initState();
    selectedSchoolId = widget.schoolId;
    selectedSchoolName = widget.schoolName;
  }

  String _getName(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && data.containsKey('name')
        ? data['name'] as String
        : 'Unnamed';
  }

  void _editProgramme(QueryDocumentSnapshot doc) {
    final currentName = _getName(doc);
    final editController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Programme"),
        content: TextField(controller: editController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                try {
                  // 🔹 Check if another programme with this name already exists
                  final existing = await FirebaseFirestore.instance
                      .collection('schools')
                      .doc(selectedSchoolId)
                      .collection('programmes')
                      .where('name', isEqualTo: newName)
                      .get();

                  if (existing.docs.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Programme name already exists")),
                    );
                    return;
                  }

                  // 🔹 Update programme name
                  await doc.reference.update({'name': newName});
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              } else {
                Navigator.pop(context); // no change
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Delete this programme?"),
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
    programmeController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Programmes")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown to select school
            // --- School Selection ---
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('schools').orderBy('name').get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final schools = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'name': data['name'] ?? 'Unnamed',
                  };
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("School",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        // Open dialog with search
                        final selected = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) {
                            TextEditingController searchCtrl = TextEditingController();
                            List<Map<String, dynamic>> filtered = schools;

                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return AlertDialog(
                                  title: Text("Select School"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: searchCtrl,
                                        decoration: InputDecoration(
                                          hintText: "Search schools...",
                                          prefixIcon: Icon(Icons.search),
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (val) {
                                          setDialogState(() {
                                            filtered = schools
                                                .where((s) => s['name']
                                                .toLowerCase()
                                                .contains(val.toLowerCase()))
                                                .toList();
                                          });
                                        },
                                      ),
                                      SizedBox(height: 12),
                                      Container(
                                        height: 300, // scrollable list
                                        width: double.maxFinite,
                                        child: ListView.builder(
                                          itemCount: filtered.length,
                                          itemBuilder: (_, i) {
                                            return ListTile(
                                              title: Text(filtered[i]['name']),
                                              onTap: () => Navigator.pop(context, filtered[i]),
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

                        if (selected != null) {
                          setState(() {
                            selectedSchoolId = selected['id'];
                            selectedSchoolName = selected['name'];
                          });
                        }
                      },
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
                              selectedSchoolName ?? "Select School",
                              style: TextStyle(
                                fontSize: 15,
                                color: selectedSchoolName == null
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

            SizedBox(height: 12),

            // Input field
            TextField(
              controller: programmeController,
              decoration: InputDecoration(
                labelText: "Programme Name",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 12),

            // Add button
            ElevatedButton(
              onPressed: () async {
                if (selectedSchoolId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please select a school first")),
                  );
                  return;
                }

                final name = programmeController.text.trim();
                if (name.isNotEmpty) {
                  try {
                    // 1. Check for duplicates first
                    final existing = await FirebaseFirestore.instance
                        .collection('schools')
                        .doc(selectedSchoolId)
                        .collection('programmes')
                        .where('name', isEqualTo: name)
                        .get();

                    if (existing.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Programme already exists")),
                      );
                      return;
                    }
                    // 2. Add new programme
                    final newProgrammeRef = await FirebaseFirestore.instance
                        .collection('schools')
                        .doc(selectedSchoolId)
                        .collection('programmes')
                        .add({
                      'name': name,
                      'programmeId': '', // temp, update next
                      'schoolId': selectedSchoolId,
                    });

                    // 3. Update programmeId
                    await newProgrammeRef
                        .update({'programmeId': newProgrammeRef.id});
                    programmeController.clear();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Programme added successfully")),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              },
              child: Text("Add Programme"),
            ),

            SizedBox(height: 16),

            // Search bar
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search Programmes",
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

            // Programme list
            Expanded(
              child: selectedSchoolId == null
                  ? Center(child: Text("Select a school to view programmes"))
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(selectedSchoolId)
                    .collection('programmes')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No programmes found."));
                  }

                  final filteredProgrammes =
                  snapshot.data!.docs.where((doc) {
                    final name = _getName(doc).toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  if (filteredProgrammes.isEmpty) {
                    return Center(
                        child: Text("No programmes match your search."));
                  }

                  return ListView(
                    children: filteredProgrammes.map((doc) {
                      final name = _getName(doc);

                      return ListTile(
                        title: Text(name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editProgramme(doc),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmed =
                                await _showDeleteConfirmDialog();
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
            ),
          ],
        ),
      ),
    );
  }
}
