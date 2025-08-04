import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditForumPostScreen extends StatefulWidget {
  final String postId;
  final String initialText;

  EditForumPostScreen({required this.postId, required this.initialText});

  @override
  _EditForumPostScreenState createState() => _EditForumPostScreenState();
}

class _EditForumPostScreenState extends State<EditForumPostScreen> {
  late TextEditingController _controller;
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isUpdating = false;
  String _userRole = '';

  Color get roleColor => _userRole == 'mentor' ? Colors.teal : Colors.blue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final uid = currentUser!.uid;

    final mentorDoc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
    if (mentorDoc.exists) {
      setState(() => _userRole = 'mentor');
      return;
    }

    final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
    if (studentDoc.exists) {
      setState(() => _userRole = 'student');
    }
  }

  Future<void> _updatePost() async {
    final updatedText = _controller.text.trim();
    if (updatedText.isEmpty) return;

    setState(() {
      _isUpdating = true;
    });

    await FirebaseFirestore.instance
        .collection('forums')
        .doc(widget.postId)
        .update({'text': updatedText});

    Navigator.pop(context); // Go back to ForumsScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Forum Post'),
        backgroundColor: roleColor,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update your post:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _controller,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Edit your forum post...',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _updatePost,
                icon: Icon(Icons.save, color: Colors.white),
                label: Text('Update', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: roleColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isUpdating
                    ? null
                    : () async {
                  final shouldCancel = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Cancel Editing'),
                      content: Text('Are you sure you want to cancel? Changes will be lost.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Yes'),
                        ),
                      ],
                    ),
                  );

                  if (shouldCancel == true) {
                    Navigator.pop(context);
                  }
                },
                child: Text('Cancel', style: TextStyle(color: roleColor)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: roleColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if (_isUpdating) ...[
              SizedBox(height: 16),
              Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
