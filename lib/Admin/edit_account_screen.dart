import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'image_preview_screen.dart';

class EditAccountScreen extends StatefulWidget {
  final String userId;        // 👈 Add this
  final String role;
  final Map<String, dynamic> userData;

  const EditAccountScreen({
    Key? key,
    required this.userId,
    required this.role,
    required this.userData,
  }) : super(key: key);

  @override
  _EditAccountScreenState createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  List<String> selectedProgrammeIds = [];

  late TextEditingController nameController;
  late TextEditingController phoneController;

  String? selectedSchoolId;
  String? selectedSchoolName;
  String? selectedProgrammeId;
  String? selectedProgrammeName;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    phoneController = TextEditingController(text: widget.userData['phone'] ?? '');

    // Initialize selections
    selectedSchoolId = widget.userData['schoolId'];
    if (widget.userData['role'] == 'Student') {
      selectedProgrammeId = widget.userData['programmeId'];
    } else {
      selectedProgrammeIds = List<String>.from(widget.userData['programmeIds'] ?? []);
    }

    // Preload school/programme names for display
    _fetchNames();
  }

  Future<void> _fetchNames() async {
    if (selectedSchoolId != null) {
      // Get school name
      final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(selectedSchoolId).get();
      if (schoolDoc.exists) {
        selectedSchoolName = (schoolDoc.data() as Map<String, dynamic>)['name'];
      }

      if (widget.userData['role'] == 'Student' && selectedProgrammeId != null) {
        // Student: fetch programme name
        final progDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(selectedSchoolId)
            .collection('programmes')
            .doc(selectedProgrammeId)
            .get();
        if (progDoc.exists) {
          selectedProgrammeName = (progDoc.data() as Map<String, dynamic>)['name'];
        }
      } else if (widget.userData['role'] == 'Mentor' && selectedProgrammeIds.isNotEmpty) {
        // Mentor: fetch multiple programme names
        final progsSnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(selectedSchoolId)
            .collection('programmes')
            .where(FieldPath.documentId, whereIn: selectedProgrammeIds)
            .get();

        selectedProgrammeName = progsSnapshot.docs.map((d) => d['name'] as String).join(", ");
      }

      setState(() {}); // refresh UI
    }
  }


  Future<void> _saveChanges() async {
    try {
      final updateData = <String, dynamic>{};

      // --- name
      if (nameController.text.trim().isNotEmpty &&
          nameController.text.trim() != widget.userData['name']) {
        updateData['name'] = nameController.text.trim();
      }

      // --- phone
      if (phoneController.text.trim().isNotEmpty &&
          phoneController.text.trim() != widget.userData['phone']) {
        updateData['phone'] = phoneController.text.trim();
      }

      // --- school (only if changed)
      if (selectedSchoolId != null &&
          selectedSchoolId != widget.userData['schoolId']) {
        updateData['schoolId'] = selectedSchoolId;
      }

      // --- programmes
      if (widget.userData['role'] == 'Student') {
        if (selectedProgrammeId != null &&
            selectedProgrammeId != widget.userData['programmeId']) {
          updateData['programmeId'] = selectedProgrammeId;
        }
      } else if (widget.userData['role'] == 'Mentor') {
        if (selectedProgrammeIds.isNotEmpty &&
            selectedProgrammeIds.toSet() !=
                (List<String>.from(widget.userData['programmeIds'] ?? [])).toSet()) {
          updateData['programmeIds'] = selectedProgrammeIds;
        }
      }

      // --- apply updates if anything changed
      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(widget.role == 'Student' ? 'students' : 'mentors')
            .doc(widget.userId)
            .update(updateData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Changes saved successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No changes to save")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to save changes: $e")),
      );
    }
  }



  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      try {
        final ref = FirebaseStorage.instance.ref().child('user_uploads/${widget.userData['uid']}/$fileName');
        await ref.putFile(file);
        final fileUrl = await ref.getDownloadURL();

        final collection = widget.userData['role'] == 'Student' ? 'students' : 'mentors';
        await FirebaseFirestore.instance.collection(collection).doc(widget.userData['uid']).update({
          'fileUrl': fileUrl,
        });

        setState(() {
          widget.userData['fileUrl'] = fileUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File uploaded successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleAccountStatus(bool disable) async {
    try {
      final collection = widget.userData['role'] == 'Student' ? 'students' : 'mentors';
      await FirebaseFirestore.instance.collection(collection).doc(widget.userData['uid']).update({
        'disabled': disable,
      });

      setState(() {
        widget.userData['disabled'] = disable;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(disable ? '✅ Account disabled' : '✅ Account enabled'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to update status: $e')),
      );
    }
  }

  Widget _buildUploadedFilePreview() {
    final fileUrl = widget.userData['fileUrl'];
    if (fileUrl == null) return SizedBox.shrink();

    bool isPdf = fileUrl.toLowerCase().endsWith('.pdf');
    return ListTile(
      leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: Colors.deepPurple),
      title: Text(isPdf ? 'View PDF' : 'View Image'),
      onTap: () async {
        if (isPdf) {
          await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ImagePreviewScreen(imageUrl: fileUrl)),
          );
        }
      },
    );
  }

  Future<void> _selectSchool() async {
    final snapshot = await FirebaseFirestore.instance.collection('schools').orderBy('name').get();
    final schools = snapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, 'name': data['name'] ?? 'Unnamed'};
    }).toList();

    final selected = await _showSearchDialog("Select School", schools, singleSelect: true);
    if (selected != null) {
      setState(() {
        selectedSchoolId = selected['id'];
        selectedSchoolName = selected['name'];
        selectedProgrammeId = null;
        selectedProgrammeName = null;
        selectedProgrammeIds = [];
      });
      // ✅ Make sure schoolId gets saved on Save Changes
      widget.userData['schoolId'] = null;
    }
  }

  Future<void> _selectProgramme() async {
    if (selectedSchoolId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(selectedSchoolId)
        .collection('programmes')
        .orderBy('name')
        .get();

    final programmes = snapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, 'name': data['name'] ?? 'Unnamed'};
    }).toList();

    if (widget.userData['role'] == 'Student') {
      // Student: single select
      final selected = await _showSearchDialog(
        "Select Programme",
        programmes,
        singleSelect: true,
      );
      if (selected != null) {
        setState(() {
          selectedProgrammeId = selected['id'];
          selectedProgrammeName = selected['name'];
        });


      }
    } else {
      // Mentor: multi-select with search
      final selectedList = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (ctx) {
          TextEditingController searchController = TextEditingController();
          List<Map<String, dynamic>> filteredProgrammes = List.from(programmes);

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text("Select Programmes"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search programmes...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          filteredProgrammes = programmes
                              .where((p) => p['name'].toLowerCase().contains(val.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.maxFinite,
                      height: 300,
                      child: ListView.builder(
                        itemCount: filteredProgrammes.length,
                        itemBuilder: (_, i) {
                          final prog = filteredProgrammes[i];
                          final isSelected = selectedProgrammeIds.contains(prog['id']);

                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(prog['name']),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedProgrammeIds.add(prog['id']);
                                } else {
                                  selectedProgrammeIds.remove(prog['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final selectedItems = programmes
                          .where((p) => selectedProgrammeIds.contains(p['id']))
                          .toList();
                      Navigator.pop(ctx, selectedItems);
                    },
                    child: Text("OK"),
                  ),
                ],
              );
            },
          );
        },
      );

      if (selectedList != null) {
        setState(() {
          selectedProgrammeIds = selectedList.map((s) => s['id'] as String).toList();
        });

      }
    }
  }




  Future<dynamic> _showSearchDialog(
      String title, List<Map<String, dynamic>> items,
      {bool singleSelect = true, List<String>? preselectedIds}) async {
    TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = items;
    Set<String> selectedIds = {...?preselectedIds};

    return await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      setDialogState(() {
                        filtered = items
                            .where((s) => s['name'].toLowerCase().contains(val.toLowerCase()))
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
                        final item = filtered[i];
                        if (singleSelect) {
                          return ListTile(
                            title: Text(item['name']),
                            onTap: () => Navigator.pop(context, item),
                          );
                        } else {
                          return CheckboxListTile(
                            value: selectedIds.contains(item['id']),
                            title: Text(item['name']),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedIds.add(item['id']);
                                } else {
                                  selectedIds.remove(item['id']);
                                }
                              });
                            },
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: singleSelect
                  ? []
                  : [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selectedItems =
                    items.where((s) => selectedIds.contains(s['id'])).toList();
                    Navigator.pop(context, selectedItems);
                  },
                  child: Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.userData['disabled'] == true;

    return Scaffold(
      appBar: AppBar(title: Text('Edit Account'), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Email (read-only)
              TextFormField(
                initialValue: widget.userData['email'] ?? '',
                decoration: InputDecoration(labelText: 'Email'),
                enabled: false,
              ),
              SizedBox(height: 10),

              // Role (read-only)
              TextFormField(
                initialValue: widget.userData['role'] ?? 'Unknown',
                decoration: InputDecoration(labelText: 'Role'),
                enabled: false,
              ),
              SizedBox(height: 10),

              // Student/Mentor ID (read-only)
              TextFormField(
                initialValue: widget.userData['studentIdNo'] ??
                    widget.userData['mentorIdNo'] ??
                    'N/A',
                decoration: InputDecoration(labelText: 'ID Number'),
                enabled: false,
              ),
              SizedBox(height: 10),

              // Name (editable)
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) => value!.isEmpty ? 'Enter a name' : null,
              ),
              SizedBox(height: 10),

              // Phone (editable)
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone'),
                validator: (value) => value!.isEmpty ? 'Enter a phone number' : null,
              ),
              SizedBox(height: 20),

              // School Selection
              Text("School", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 6),
              GestureDetector(
                onTap: _selectSchool,
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
                          color: selectedSchoolName == null ? Colors.grey.shade500 : Colors.black,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Programme Selection
              if (selectedSchoolId != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Programme(s)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 6),
                    GestureDetector(
                      onTap: _selectProgramme,
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
                                widget.userData['role'] == 'Student'
                                    ? (selectedProgrammeName ?? "Select Programme")
                                    : (selectedProgrammeIds.isEmpty
                                    ? "Select Programmes"
                                    : "${selectedProgrammeIds.length} programme(s) selected"),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: (widget.userData['role'] == 'Student'
                                      ? selectedProgrammeName == null
                                      : selectedProgrammeIds.isEmpty)
                                      ? Colors.grey.shade500
                                      : Colors.black,
                                ),
                              ),
                            ),

                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              SizedBox(height: 20),

              _buildUploadedFilePreview(),
              ElevatedButton(
                onPressed: _pickAndUploadFile,
                child: Text('Upload File (Image or PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChanges,
                child: Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _toggleAccountStatus(!isDisabled),
                child: Text(isDisabled ? 'Enable Account' : 'Disable Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDisabled ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
