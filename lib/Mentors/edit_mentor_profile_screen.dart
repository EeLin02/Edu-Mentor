import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:intl/intl.dart';

class EditMentorProfileScreen extends StatefulWidget {
  final String mentorName;
  final String email;
  final String profileUrl;

  const EditMentorProfileScreen({
    Key? key,
    required this.mentorName,
    required this.email,
    required this.profileUrl,
  }) : super(key: key);

  @override
  _EditMentorProfileScreenState createState() => _EditMentorProfileScreenState();
}

class _EditMentorProfileScreenState extends State<EditMentorProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  File? _pickedImage;
  String profileUrl = "";
  String phoneNumber = '';
  PhoneNumber number = PhoneNumber(isoCode: 'MY');
  bool isPhoneValid = false;
  String? selectedGender;
  DateTime? selectedBirthDate;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMentorData();
    nameController.text = widget.mentorName;
    emailController.text = widget.email;
    profileUrl = widget.profileUrl;
  }

  Future<void> _loadMentorData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('mentors').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        PhoneNumber parsedNumber = await PhoneNumber.getRegionInfoFromPhoneNumber(
          data['phone'] ?? '',
          'MY',
        );

        setState(() {
          nameController.text = data['name'] ?? '';
          emailController.text = user.email ?? '';
          number = parsedNumber;
          phoneController.text = parsedNumber.phoneNumber ?? '';
          phoneNumber = parsedNumber.phoneNumber ?? '';
          selectedGender = data['gender'];
          profileUrl = data['profileUrl'] ?? '';
          selectedBirthDate = (data['birthDate'] as Timestamp?)?.toDate();
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Camera"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _pickedImage = File(picked.path);
        });
      }
    }
  }

  Future<String?> _askForCurrentPassword() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final pwController = TextEditingController();
        return AlertDialog(
          title: Text('Re-enter Current Password'),
          content: TextField(
            controller: pwController,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Current Password'),
            onSubmitted: (_) {
              Navigator.of(context).pop(pwController.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(pwController.text.trim()),
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _reauthenticateUser(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      return true;
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reauthentication failed: ${e.message}')));
      return false;
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = emailController.text.trim();
    final user = _auth.currentUser;

    if (user == null) return;

    if (newEmail == user.email) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email is unchanged')));
      return;
    }

    final currentPassword = await _askForCurrentPassword();
    if (currentPassword == null || currentPassword.isEmpty) return;

    final reauthSuccess = await _reauthenticateUser(currentPassword);
    if (!reauthSuccess) return;

    try {
      await user.updateEmail(newEmail);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email updated successfully')));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update email: ${e.message}')));
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    if (selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select your birth date')),
      );
      return;
    }

    if (!isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    try {
      String? uploadedUrl;
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('mentor_profiles/${user.uid}.jpg');
        await ref.putFile(_pickedImage!);
        uploadedUrl = await ref.getDownloadURL();
      }

      final data = {
        'name': nameController.text.trim(),
        'phone': phoneNumber,
        'gender': selectedGender,
        'birthDate': selectedBirthDate,
        if (uploadedUrl != null) 'profileUrl': uploadedUrl,
      };

      await _firestore.collection('mentors').doc(user.uid).set(data, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong')),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPwController,
                    decoration: InputDecoration(labelText: 'Current Password'),
                    obscureText: true,
                    validator: (val) =>
                    val == null || val.isEmpty ? 'Enter current password' : null,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: newPwController,
                    decoration: InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter new password';
                      if (val.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: confirmPwController,
                    decoration: InputDecoration(labelText: 'Confirm New Password'),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Confirm your new password';
                      if (val != newPwController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final currentPassword = currentPwController.text.trim();
                  final newPassword = newPwController.text.trim();

                  Navigator.of(context).pop(); // close dialog before processing

                  bool reauthSuccess = await _reauthenticateUser(currentPassword);
                  if (!reauthSuccess) return;

                  try {
                    await _auth.currentUser!.updatePassword(newPassword);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Password updated successfully')),
                    );
                  } on FirebaseAuthException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update password: ${e.message}')),
                    );
                  }
                }
              },
              child: Text('Change Password'),
            ),
          ],
        );
      },
    );
  }

  void _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedBirthDate = picked;
      });
    }
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Cancel Editing?"),
        content: Text("Are you sure you want to discard your changes?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Stay on screen
            child: Text("No"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Pop edit screen
            },
            child: Text("Yes"),
          ),
        ],
      ),
    );
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
          selectorConfig: SelectorConfig(
            selectorType: PhoneInputSelectorType.DROPDOWN,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Mentor Profile"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _pickedImage != null
                      ? FileImage(_pickedImage!)
                      : (profileUrl.isNotEmpty
                      ? NetworkImage(profileUrl)
                      : AssetImage("assets/images/mentor_icon.png")
                  as ImageProvider),
                ),
                IconButton(
                  icon: Icon(Icons.camera_alt, color: Colors.teal),
                  onPressed: _pickImage,
                ),
              ],
            ),
            SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                    value!.isEmpty ? 'Enter your name' : null,
                  ),
                  SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Enter email';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$')
                              .hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _updateEmail,
                        child: Text('Update Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  buildPhoneInput(),
                  SizedBox(height: 10),
                  ListTile(
                    title: Text(
                      selectedBirthDate != null
                          ? 'Birth Date: ${DateFormat('yyyy-MM-dd').format(selectedBirthDate!)}'
                          : 'Select Birth Date',
                    ),
                    trailing: Icon(Icons.calendar_today),
                    onTap: _pickBirthDate,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Gender'),
                    value: selectedGender,
                    items: [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedGender = val;
                      });
                    },
                    validator: (val) =>
                    val == null || val.isEmpty ? 'Please select a gender' : null,
                  ),

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[50],
                      foregroundColor: Colors.teal,
                      minimumSize: Size(double.infinity, 48),
                    ),
                    child: Text('Save Profile'),
                  ),

                  SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: _showChangePasswordDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[300],
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                    child: Text('Change Password'),
                  ),

                  SizedBox(height: 10),

                  OutlinedButton(
                    onPressed: _showCancelConfirmationDialog,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey,
                      minimumSize: Size(double.infinity, 48),
                    ),
                    child: Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

