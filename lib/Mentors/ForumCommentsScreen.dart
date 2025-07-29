import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ForumCommentsScreen extends StatefulWidget {
  final String postId;

  const ForumCommentsScreen({required this.postId});

  @override
  _ForumCommentsScreenState createState() => _ForumCommentsScreenState();
}

class _ForumCommentsScreenState extends State<ForumCommentsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _commentController = TextEditingController();

  void _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    final mentorDoc = await FirebaseFirestore.instance
        .collection('mentors')
        .doc(currentUser!.uid)
        .get();

    await FirebaseFirestore.instance
        .collection('forums')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'userId': currentUser!.uid,
      'userName': mentorDoc['name'],
      'userPhoto': mentorDoc['fileUrl'],
      'text': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('forums')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(child: Text('No comments yet.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    final commentTime = data['timestamp'] != null
                        ? DateFormat('MMM d, yyyy • h:mm a').format(data['timestamp'].toDate())
                        : 'Just now';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(data['userPhoto']),
                      ),
                      title: Text(data['userName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['text']),
                          SizedBox(height: 4),
                          Text(commentTime, style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.teal),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
