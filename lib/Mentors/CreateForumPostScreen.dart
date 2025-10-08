import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateForumPostScreen extends StatefulWidget {
  @override
  _CreateForumPostScreenState createState() => _CreateForumPostScreenState();
}

class _CreateForumPostScreenState extends State<CreateForumPostScreen> {
  final TextEditingController _controller = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  bool _isPosting = false;
  bool _isMentor = true; // Default to mentor
  Color _themeColor = Colors.teal; // Default color

  @override
  void initState() {
    super.initState();
    _determineUserRole();
  }

  Future<void> _determineUserRole() async {
    final uid = currentUser!.uid;

    final mentorDoc =
    await FirebaseFirestore.instance.collection('mentors').doc(uid).get();

    if (mentorDoc.exists) {
      setState(() {
        _isMentor = true;
        _themeColor = Colors.teal;
      });
    } else {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(uid)
          .get();

      if (studentDoc.exists) {
        setState(() {
          _isMentor = false;
          _themeColor = Colors.blue;
        });
      }
    }
  }

  Future<void> _submitPost() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    final uid = currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection(_isMentor ? 'mentors' : 'students')
        .doc(uid)
        .get();

    // Create Forum Post
    await FirebaseFirestore.instance.collection('forums').add({
      'userId': uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context); // Go back to ForumsScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Forum Post'),
        backgroundColor: _themeColor,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share your thoughts or ask a question:',
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
                    hintText: 'Type your forum post here...',
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
                onPressed: _isPosting ? null : _submitPost,
                icon: Icon(Icons.send, color: Colors.white),
                label: Text('Post', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _themeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            if (_isPosting) ...[
              SizedBox(height: 16),
              Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
