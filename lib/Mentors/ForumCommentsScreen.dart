import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForumCommentsScreen extends StatefulWidget {
  final String postId;
  ForumCommentsScreen({required this.postId});

  @override
  State<ForumCommentsScreen> createState() => _ForumCommentsScreenState();
}

class _ForumCommentsScreenState extends State<ForumCommentsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _commentController = TextEditingController();
  Set<String> expandedComments = {};
  String getUserIdNo(Map<String, dynamic>? userData, bool isMentor) {
    if (userData == null) return '';
    return isMentor
        ? (userData['mentorIdNo'] ?? '')
        : (userData['studentIdNo'] ?? '');
  }


  String? userRole; // 'mentor' or 'student'

  @override
  void initState() {
    super.initState();
    _determineUserRole();
  }

  Future<void> _determineUserRole() async {
    final uid = currentUser!.uid;

    final mentorDoc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
    if (mentorDoc.exists) {
      setState(() => userRole = 'mentors');
      return;
    }

    final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
    if (studentDoc.exists) {
      setState(() => userRole = 'students');
    }
  }



  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Determine user info (mentor or student)
    final uid = currentUser!.uid;
    DocumentSnapshot userDoc;

    // Try mentors first
    userDoc = await FirebaseFirestore.instance.collection('mentors')
        .doc(uid).get();
    if (!userDoc.exists) {
      // If not a mentor, try students
      userDoc = await FirebaseFirestore.instance.collection('students')
          .doc(uid).get();
    }
    final userData = userDoc.data() as Map<String, dynamic>?;

    await FirebaseFirestore.instance
        .collection('forums')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'userId': uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
    });
    _commentController.clear();
  }


  Future<void> _confirmDelete({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.white),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // Red background
            ),
          ),

        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }


  Future<void> _toggleCommentLike(String commentId, List likes) async {
    final userId = currentUser!.uid;
    final commentRef = FirebaseFirestore.instance
        .collection('forums')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    if (likes.contains(userId)) {
      await commentRef.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await commentRef.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }


  void _deleteComment(String commentId) {
    _confirmDelete(
      title: 'Delete Comment',
      content: 'Are you sure you want to delete this comment?',
      onConfirm: () async {
        final commentRef = FirebaseFirestore.instance
            .collection('forums')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId);

        // Delete all replies first
        final repliesSnapshot = await commentRef.collection('replies')
            .get();
        for (final doc in repliesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Then delete the comment itself
        await commentRef.delete();
      },
    );
  }



  Future<void> _addReply(String commentId, String text) async {
    if (text.trim().isEmpty) return;

    final uid = currentUser!.uid;
    DocumentSnapshot userDoc;

    // Try mentors first
    userDoc = await FirebaseFirestore.instance.collection('mentors')
        .doc(uid).get();
    if (!userDoc.exists) {
      // Try students
      userDoc = await FirebaseFirestore.instance.collection('students')
          .doc(uid).get();
    }
    await FirebaseFirestore.instance
        .collection('forums')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
      'userId': uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
    });
  }


  void _deleteReply(String commentId, String replyId) {
    _confirmDelete(
      title: 'Delete Reply',
      content: 'Are you sure you want to delete this reply?',
      onConfirm: () async {
        await FirebaseFirestore.instance
            .collection('forums')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .doc(replyId)
            .delete();
      },
    );
  }


  Future<void> _toggleReplyLike(
      String commentId, String replyId, List likes) async {
    final userId = currentUser!.uid;
    final replyRef = FirebaseFirestore.instance
        .collection('forums')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    if (likes.contains(userId)) {
      await replyRef.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await replyRef.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  Widget _buildReplies(String commentId) {
    final isExpanded = expandedComments.contains(commentId);
    if (!isExpanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            setState(() {
              expandedComments.add(commentId);
            });
          },
          child: Text('Show Replies'),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('forums')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();
        final replies = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: replies.length,
              itemBuilder: (context, index) {
                final reply = replies[index];
                final likes = List<String>.from(reply['likes'] ?? []);
                final hasLiked = likes.contains(currentUser!.uid);

                // StreamBuilder for reply's user
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('mentors')
                      .doc(reply['userId'])
                      .snapshots(),
                  builder: (context, mentorSnap) {
                    if (!mentorSnap.hasData) return SizedBox();
                    DocumentSnapshot userDoc = mentorSnap.data!;
                    bool isMentor = userDoc.exists;

                    if (!isMentor) {
                      // If not mentor, use student doc
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('students')
                            .doc(reply['userId'])
                            .snapshots(),
                        builder: (context, studentSnap) {
                          if (!studentSnap.hasData) return SizedBox();
                          return _buildReplyTile(reply, likes, hasLiked, studentSnap.data!, false, commentId);
                        },
                      );
                    } else {
                      return _buildReplyTile(reply, likes, hasLiked, userDoc, true, commentId);
                    }
                  },
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    expandedComments.remove(commentId);
                  });
                },
                child: Text('Hide Replies'),
              ),
            ),
          ],
        );
      },
    );
  }

// Helper to reduce repetition
  Widget _buildReplyTile(DocumentSnapshot reply, List<String> likes, bool hasLiked, DocumentSnapshot userDoc, bool isMentor, String commentId) {
    final userData = userDoc.data() as Map<String, dynamic>?;

    final userName = userData?['name'] ?? 'Unknown';
    final userIdNo = getUserIdNo(userData, isMentor);
    final userPhoto = userData?['profileUrl'] ?? '';

    return ListTile(
      contentPadding: EdgeInsets.only(left: 40),
      leading: CircleAvatar(
        backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
        child: userPhoto.isEmpty ? Icon(Icons.person) : null,
      ),
      title: Text('$userName ($userIdNo)'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reply['text']),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                  color: hasLiked ? Colors.blue : null,
                ),
                onPressed: () => _toggleReplyLike(
                    reply.reference.parent.parent!.id,
                    reply.id,
                    likes),
              ),
              Text('${likes.length}'),
              if (reply['userId'] == currentUser!.uid)
                TextButton(
                  onPressed: () => _deleteReply(commentId, reply.id),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: isMentor ? Colors.teal : Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }





  Widget _buildCommentTile(DocumentSnapshot comment) {
    final data = comment.data() as Map<String, dynamic>;
    final likes = List<String>.from(data['likes'] ?? []);
    final hasLiked = likes.contains(currentUser!.uid);

    final TextEditingController _replyController = TextEditingController();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mentors')
          .doc(data['userId'])
          .snapshots(),
      builder: (context, mentorSnap) {
        if (!mentorSnap.hasData) return SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));

        DocumentSnapshot userDoc = mentorSnap.data!;
        bool isMentor = userDoc.exists;

        if (!isMentor) {
          // If not a mentor, listen to student doc
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('students').doc(data['userId']).snapshots(),
            builder: (context, studentSnap) {
              if (!studentSnap.hasData) return SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));

              final studentData = studentSnap.data!;
              return _buildCommentCard(comment, likes, hasLiked, studentData, false);
            },
          );
        } else {
          return _buildCommentCard(comment, likes, hasLiked, userDoc, true);
        }
      },
    );
  }

// Helper to reduce repetition
  Widget _buildCommentCard(DocumentSnapshot comment, List<String> likes, bool hasLiked, DocumentSnapshot userDoc, bool isMentor) {
    final userData = userDoc.data() as Map<String, dynamic>?;

    final userName = userData?['name'] ?? 'Unknown User';
    final userPhoto = userData?['profileUrl'] ?? '';
    final userIdNo = getUserIdNo(userData, isMentor);

    final TextEditingController _replyController = TextEditingController();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                child: userPhoto.isEmpty ? Icon(Icons.person) : null,
              ),
              title: Text('$userName ($userIdNo)'),
              subtitle: Text(comment['text']),
              trailing: comment['userId'] == currentUser!.uid
                  ? TextButton(
                onPressed: () => _deleteComment(comment.id),
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: isMentor ? Colors.teal : Colors.blue,
                    fontSize: 12,
                  ),
                ),
              )
                  : null,
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleCommentLike(comment.id, likes),
                  child: Row(
                    children: [
                      Icon(
                        hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 18,
                        color: hasLiked ? Colors.blue : null,
                      ),
                      SizedBox(width: 4),
                      Text('${likes.length} Likes'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Reply...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () async {
                    await _addReply(comment.id, _replyController.text);
                    _replyController.clear();
                  },
                ),
              ],
            ),
            _buildReplies(comment.id),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forum Comments'),
        backgroundColor: userRole == 'mentors' ? Colors.teal : Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('forums')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();

                final comments = snapshot.data!.docs;
                if (comments.isEmpty) {
                  return Center(child: Text('No comments yet.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentTile(comments[index]);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send,color: userRole == 'mentors' ? Colors.teal : Colors.blue,),
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
