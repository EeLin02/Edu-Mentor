import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:intl/intl.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
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
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('students').doc(user.uid).get();
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
    final pwController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Re-enter Current Password'),
          content: TextField(
            controller: pwController,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Current Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, pwController.text.trim()),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reauthentication failed.")),
      );
      return false;
    }
  }

  Future<void> _updateEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newEmail = emailController.text.trim();
    if (newEmail == user.email) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email is unchanged')));
      return;
    }

    final password = await _askForCurrentPassword();
    if (password == null || password.isEmpty) return;

    final success = await _reauthenticateUser(password);
    if (!success) return;

    try {
      await user.updateEmail(newEmail);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email updated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed')));
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null || !_formKey.currentState!.validate()) return;

    if (selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select birth date')));
      return;
    }

    if (!isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid phone number')));
      return;
    }

    try {
      String? uploadedUrl;
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance.ref().child('student_profiles/${user.uid}.jpg');
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

      await _firestore.collection('students').doc(user.uid).set(data, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile')));
    }
  }

  Future<void> _changePasswordDialog() async {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Change Password"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPw,
                obscureText: true,
                decoration: InputDecoration(labelText: "Current Password"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: newPw,
                obscureText: true,
                decoration: InputDecoration(labelText: "New Password"),
                validator: (val) => val!.length < 6 ? "Min 6 chars" : null,
              ),
              TextFormField(
                controller: confirmPw,
                obscureText: true,
                decoration: InputDecoration(labelText: "Confirm Password"),
                validator: (val) =>
                val != newPw.text ? "Passwords do not match" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            child: Text("Change"),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                final success = await _reauthenticateUser(currentPw.text.trim());
                if (success) {
                  await _auth.currentUser!.updatePassword(newPw.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Password changed")));
                }
              }
            },
          )
        ],
      ),
    );
  }

  Widget buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InternationalPhoneNumberInput(
          onInputChanged: (value) => phoneNumber = value.phoneNumber ?? '',
          onInputValidated: (valid) => setState(() => isPhoneValid = valid),
          selectorConfig: SelectorConfig(selectorType: PhoneInputSelectorType.DROPDOWN),
          ignoreBlank: false,
          autoValidateMode: AutovalidateMode.onUserInteraction,
          initialValue: number,
          textFieldController: phoneController,
          inputDecoration: InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()),
        ),
        if (!isPhoneValid && phoneController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 8),
            child: Text("Invalid phone number", style: TextStyle(color: Colors.red, fontSize: 12)),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Student Profile"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                        : AssetImage("assets/images/student_icon.png") as ImageProvider),
                  ),
                  IconButton(
                    icon: Icon(Icons.camera_alt, color: Colors.teal),
                    onPressed: _pickImage,
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Name"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _updateEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Update Email'),
                ),
              ),

              SizedBox(height: 10),
              buildPhoneInput(),
              SizedBox(height: 10),
              ListTile(
                title: Text(
                  selectedBirthDate == null
                      ? "Select Birth Date"
                      : DateFormat('yyyy-MM-dd').format(selectedBirthDate!),
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedBirthDate ?? DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => selectedBirthDate = picked);
                  }
                },
              ),
              DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: InputDecoration(labelText: "Gender"),
                items: [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (val) => setState(() => selectedGender = val),
                validator: (val) => val == null ? "Required" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 48),
                ),
                child: Text('Save Profile'),
              ),

              SizedBox(height: 10),

              ElevatedButton(
                onPressed: _changePasswordDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                ),
                child: Text('Change Password'),
              ),

              SizedBox(height: 10),

              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                  foregroundColor: Colors.grey,
                  side: BorderSide(color: Colors.grey),
                ),
                child: Text('Cancel'),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
