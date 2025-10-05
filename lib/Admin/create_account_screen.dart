import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class CreateAccountScreen extends StatefulWidget {
  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedRole;
  String? selectedSchool;
  String? selectedProgramme; // for student
  String generateMentorId(String uid) {
    // Example: M + first 8 chars of UID
    return "M${uid.substring(0, 8).toUpperCase()}";
  }

  List<String> selectedProgrammeIds = []; // for mentor multiple programmes

  File? pickedFile;
  String fileName = '';
  PhoneNumber number = PhoneNumber(isoCode: 'MY');
  String phoneNumber = '';
  bool isPhoneValid = false;

  @override
  void initState() {
    super.initState();
    // Keep studentIdController in sync with email username
    emailController.addListener(() {
      if (selectedRole == 'Student') {
        final emailText = emailController.text;
        if (studentIdController.text != emailText) {
          studentIdController.text = emailText;
        }
      }
    });
  }

  Future<void> pickFile() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image),
              title: Text("Pick Image"),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(type: FileType.image);
                if (result != null && result.files.single.path != null) {
                  setState(() {
                    pickedFile = File(result.files.single.path!);
                    fileName = result.files.single.name;
                  });
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf),
              title: Text("Pick PDF"),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.single.path != null) {
                  setState(() {
                    pickedFile = File(result.files.single.path!);
                    fileName = result.files.single.name;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> checkStudentIdExists(String studentIdNo) async {
    final snapshot = await _firestore
        .collection('students')
        .where('studentIdNo', isEqualTo: studentIdNo)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  String getFullEmail(String username) {
    if (selectedRole == 'Student') {
      return '$username@student.newinti.edu.my';
    } else if (selectedRole == 'Mentor') {
      return '$username@newinti.edu.my';
    } else {
      return username; // fallback
    }
  }

  Future<void> createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedRole == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select a role")));
      return;
    }

    if (selectedRole == 'Student' && selectedProgramme == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select a programme")));
      return;
    }

    if (selectedRole == 'Mentor' && selectedProgrammeIds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select at least one programme")));
      return;
    }

    if (selectedRole == 'Student' &&
        await checkStudentIdExists(studentIdController.text.trim())) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Student ID already exists")));
      return;
    }

    try {
      final fullEmail = getFullEmail(emailController.text.trim());

      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: fullEmail,
        password: "Temp@123", // temporary password
      );

      // Immediately send password reset email
      await _auth.sendPasswordResetEmail(email: fullEmail);

      String? fileUrl;
      if (pickedFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_uploads/${userCredential.user!.uid}/$fileName');
        await ref.putFile(pickedFile!);
        fileUrl = await ref.getDownloadURL();
      }

      final Map<String, dynamic> userData = {
        'name': nameController.text.trim(),
        'email': fullEmail,
        'phone': phoneNumber,
        'role': selectedRole,
        'schoolId': selectedSchool,
        'disabled': false,
        if (fileUrl != null) 'fileUrl': fileUrl,
      };

      if (selectedRole == 'Student') {
        userData['programmeId'] = selectedProgramme;
        userData['studentIdNo'] = studentIdController.text.trim();
      } else if (selectedRole == 'Mentor') {
        userData['programmeIds'] = selectedProgrammeIds;
        userData['mentorIdNo'] = generateMentorId(userCredential.user!.uid);
      }


      final collectionName =
      selectedRole == 'Student' ? 'students' : 'mentors';

      await _firestore
          .collection(collectionName)
          .doc(userCredential.user!.uid)
          .set(userData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account created successfully")),
      );

      // Reset form
      _formKey.currentState!.reset();
      nameController.clear();
      emailController.clear();
      passwordController.clear();
      studentIdController.clear();
      phoneController.clear();
      setState(() {
        pickedFile = null;
        fileName = '';
        selectedRole = null;
        selectedSchool = null;
        selectedProgramme = null;
        selectedProgrammeIds = [];
        phoneNumber = '';
        isPhoneValid = false;
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Firebase error')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }


  // Function to open searchable school selection
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
        selectedProgramme = null;
        selectedProgrammeIds = [];
      });
    }
  }

// Function to open programme selection dialog (for both students and mentors)
  void openProgrammeSelectionDialog(List<QueryDocumentSnapshot> progs, {bool multiple = false}) async {
    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        List<String> tempSelected = multiple ? List.from(selectedProgrammeIds) : [];
        List<QueryDocumentSnapshot> filteredProgs = List.from(progs);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Select Programme${multiple ? 's' : ''}"),
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
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
                          final id = doc.id;
                          final name = doc['name'];
                          if (multiple) {
                            return CheckboxListTile(
                              title: Text(name),
                              value: tempSelected.contains(id),
                              onChanged: (bool? value) {
                                setStateDialog(() {
                                  if (value == true) tempSelected.add(id);
                                  else tempSelected.remove(id);
                                });
                              },
                            );
                          } else {
                            return RadioListTile<String>(
                              title: Text(name),
                              value: id,
                              groupValue: tempSelected.isEmpty ? null : tempSelected.first,
                              onChanged: (val) {
                                setStateDialog(() {
                                  tempSelected = [val!];
                                });
                              },
                            );
                          }
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

    if (selectedIds != null) {
      setState(() {
        if (multiple) {
          selectedProgrammeIds = selectedIds;
        } else {
          selectedProgramme = selectedIds.first;
        }
      });
    }
  }




  Widget buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InternationalPhoneNumberInput(
          onInputChanged: (PhoneNumber value) {
            setState(() {
              phoneNumber = value.phoneNumber ?? '';
            });
          },
          onInputValidated: (bool isValid) {
            setState(() {
              isPhoneValid = isValid;
            });
          },
          selectorConfig: SelectorConfig(selectorType: PhoneInputSelectorType.DROPDOWN),
          ignoreBlank: false,
          autoValidateMode: AutovalidateMode.onUserInteraction,
          initialValue: number,
          textFieldController: phoneController,
          formatInput: true,
          inputDecoration: InputDecoration(
            labelText: "Phone Number",
            border: OutlineInputBorder(),
          ),
        ),
        if (!isPhoneValid && phoneController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
            child: Text(
              'Enter a valid phone number',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  String? validateStudentId(String? value) {
    if (value == null || value.isEmpty) return 'Enter student ID';
    final pattern = RegExp(r'^[A-Za-z]{1}[0-9]{8}$');
    if (!pattern.hasMatch(value)) return 'Student ID format: P + 8 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Account")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Name"),
                validator: (value) => value!.isEmpty ? 'Enter your name' : null,
              ),
              SizedBox(height: 10),

              // Email username
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email Username",
                  suffixText: selectedRole == 'Student'
                      ? '@student.newinti.edu.my'
                      : selectedRole == 'Mentor'
                      ? '@newinti.edu.my'
                      : '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter your email username';
                  final fullEmail = getFullEmail(value);
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(fullEmail)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // Student ID
              if (selectedRole == 'Student')
                TextFormField(
                  controller: studentIdController,
                  decoration: InputDecoration(labelText: "Student ID No."),
                  validator: validateStudentId,
                ),
              SizedBox(height: 10),

              // Password
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (value) =>
                value!.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              SizedBox(height: 10),

              // Role
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Role"),
                items: ['Student', 'Mentor']
                    .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                    .toList(),
                value: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value;
                    emailController.clear();
                    studentIdController.clear();
                    selectedSchool = null;
                    selectedProgramme = null;
                    selectedProgrammeIds = [];
                  });
                },
                validator: (value) => value == null ? 'Please select a role' : null,
              ),
              SizedBox(height: 10),

              // School selection button
              if (selectedRole != null)
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('schools').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return CircularProgressIndicator();
                    final schools = snapshot.data!.docs;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Select School"),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => openSchoolSelectionDialog(schools),
                          child: Text(
                            selectedSchool == null
                                ? "Select School"
                                : schools.firstWhere((s) => s.id == selectedSchool)['name'],
                          ),
                        ),
                      ],
                    );
                  },
                ),

// Programme selection for student
              if (selectedRole == 'Student' && selectedSchool != null)
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
                        Text("Select Programme"),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => openProgrammeSelectionDialog(progs),
                          child: Text(selectedProgramme == null
                              ? "Select Programme"
                              : progs.firstWhere((p) => p.id == selectedProgramme)['name']),
                        ),
                      ],
                    );
                  },
                ),

// Programme selection for mentor (multiple)
              if (selectedRole == 'Mentor' && selectedSchool != null)
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
                        Text("Select Programmes"),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => openProgrammeSelectionDialog(progs, multiple: true),
                          child: Text(
                            selectedProgrammeIds.isEmpty
                                ? "Select Programmes"
                                : "${selectedProgrammeIds.length} programmes selected",
                          ),
                        ),
                      ],
                    );
                  },
                ),

              SizedBox(height: 10),

              buildPhoneInput(),
              SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: pickFile,
                      icon: Icon(Icons.upload_file),
                      label: Text(fileName.isEmpty ? "Upload ID File" : fileName),
                    ),
                  ),
                  if (pickedFile != null)
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          pickedFile = null;
                          fileName = '';
                        });
                      },
                    ),
                ],
              ),
              SizedBox(height: 20),

              ElevatedButton(
                onPressed: createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text("Create Account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
