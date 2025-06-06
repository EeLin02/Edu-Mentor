import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoticeCommentScreen extends StatefulWidget {
  final String noticeId;
  NoticeCommentScreen({required this.noticeId});

  @override
  _NoticeCommentScreenState createState() => _NoticeCommentScreenState();
}

class _NoticeCommentScreenState extends State<NoticeCommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  Map<String, String> _mentorNames = {};
  Map<String, bool> _showReplyField = {};
  Map<String, TextEditingController> _replyControllers = {};

  Future<String> _getMentorName(String uid) async {
    if (_mentorNames.containsKey(uid)) {
      return _mentorNames[uid]!;
    } else {
      try {
        var doc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
        String name = doc.exists && doc.data() != null && doc.data()!.containsKey('name')
            ? doc['name']
            : 'Unknown';
        _mentorNames[uid] = name;
        return name;
      } catch (e) {
        return 'Unknown';
      }
    }
  }

  void _postComment() async {
    if (_commentController.text.trim().isEmpty || currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .add({
      'uid': currentUser!.uid,
      'text': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
    });

    _commentController.clear();
  }

  void _postReply(String commentId, String replyText) async {
    if (replyText.trim().isEmpty || currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
      'uid': currentUser!.uid,
      'text': replyText.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    _replyControllers[commentId]?.clear();

    setState(() {
      _showReplyField[commentId] = false;
    });
  }

  Future<void> _toggleLike(String commentId, List<dynamic> likes) async {
    if (currentUser == null) return;

    final userId = currentUser!.uid;
    final liked = likes.contains(userId);

    final docRef = FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .doc(commentId);

    if (liked) {
      await docRef.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await docRef.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  Widget _buildReplySection(String commentId) {
    final controller = _replyControllers[commentId] ??= TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notices')
              .doc(widget.noticeId)
              .collection('comments')
              .doc(commentId)
              .collection('replies')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return SizedBox();

            final replies = snapshot.data!.docs;

            return ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: replies.length,
              itemBuilder: (context, index) {
                final data = replies[index].data() as Map<String, dynamic>;
                final uid = data['uid'] ?? '';
                final text = data['text'] ?? '';
                final timestamp = data['timestamp'] as Timestamp?;
                return FutureBuilder<String>(
                  future: _getMentorName(uid),
                  builder: (context, nameSnapshot) {
                    String name = nameSnapshot.data ?? 'Loading...';
                    return Padding(
                      padding: const EdgeInsets.only(left: 56, top: 6, bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blueGrey.shade400,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey[900])),
                                  SizedBox(height: 4),
                                  Text(text, style: TextStyle(fontSize: 14)),
                                  SizedBox(height: 6),
                                  Text(
                                    timestamp != null
                                        ? _formatTimestamp(timestamp.toDate())
                                        : '',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        if (_showReplyField[commentId] == true)
          Padding(
            padding: const EdgeInsets.only(left: 56, top: 8, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: () {
                    _postReply(commentId, controller.text);
                  },
                  child: Text('Reply'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notices')
                    .doc(widget.noticeId)
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading comments'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data!.docs;

                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final data = comments[index].data() as Map<String, dynamic>;
                      final uid = data['uid'] ?? '';
                      final commentId = comments[index].id;
                      final text = data['text'] ?? '';
                      final timestamp = data['timestamp'] as Timestamp?;
                      final likes = (data['likes'] ?? []) as List<dynamic>;

                      return FutureBuilder<String>(
                        future: _getMentorName(uid),
                        builder: (context, nameSnapshot) {
                          String name = nameSnapshot.data ?? 'Loading...';
                          final likedByUser = likes.contains(currentUser?.uid);
                          final isAuthor = currentUser?.uid == uid;

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 6,
                            shadowColor: Colors.blueAccent.withOpacity(0.2),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.blue.shade600,
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: Colors.blueGrey[900])),
                                            SizedBox(height: 4),
                                            Text(
                                              timestamp != null
                                                  ? _formatTimestamp(timestamp.toDate())
                                                  : '',
                                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Menu Button for delete (only visible if user is author)
                                      if (isAuthor)
                                        PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'delete') {
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text('Delete Comment'),
                                                  content: Text('Are you sure you want to delete this comment?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirmed == true) {
                                                // Delete comment and its replies
                                                final commentRef = FirebaseFirestore.instance
                                                    .collection('notices')
                                                    .doc(widget.noticeId)
                                                    .collection('comments')
                                                    .doc(commentId);

                                                // Delete all replies first (Firestore does not support cascading delete)
                                                final repliesSnapshot = await commentRef.collection('replies').get();
                                                for (var replyDoc in repliesSnapshot.docs) {
                                                  await replyDoc.reference.delete();
                                                }

                                                // Delete the comment document
                                                await commentRef.delete();
                                              }
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 14),
                                  Text(text, style: TextStyle(fontSize: 16)),
                                  SizedBox(height: 14),
                                  Row(
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _toggleLike(commentId, likes),
                                        child: Row(
                                          children: [
                                            Icon(
                                              likedByUser ? Icons.favorite : Icons.favorite_border,
                                              color: likedByUser ? Colors.red : Colors.grey[600],
                                              size: 22,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              '${likes.length}',
                                              style: TextStyle(
                                                  color: likedByUser ? Colors.red : Colors.grey[700]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 24),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _showReplyField[commentId] =
                                            !(_showReplyField[commentId] ?? false);
                                          });
                                        },
                                        child: Text(
                                          _showReplyField[commentId] == true ? 'Cancel' : 'Reply',
                                          style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildReplySection(commentId),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // Sticky comment input at bottom
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(14),
                      backgroundColor: Colors.blue.shade700,
                    ),
                    onPressed: _postComment,
                    child: Icon(Icons.send, color: Colors.white),
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
