import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'image_preview_screen.dart';

class EditAccountScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditAccountScreen({required this.userData});

  @override
  _EditAccountScreenState createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final collection = widget.userData['role'] == 'Student' ? 'students' : 'mentors';

      await FirebaseFirestore.instance.collection(collection).doc(widget.userData['uid']).update({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Account updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to update: $e')),
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
                enabled: false, // disables editing
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
              SizedBox(height: 10),

              // Student ID (read-only, only for students)
              if (widget.userData['role'] == 'Student')
                TextFormField(
                  initialValue: widget.userData['studentId'] ?? '',
                  decoration: InputDecoration(labelText: 'Student ID'),
                  enabled: false,
                ),

              SizedBox(height: 20),
              _buildUploadedFilePreview(),
              ElevatedButton(
                onPressed: _pickAndUploadFile,
                child: Text('Upload File (Image or PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChanges,
                child: Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
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
