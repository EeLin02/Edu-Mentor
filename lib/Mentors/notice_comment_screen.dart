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
  Map<String, bool> _showAllReplies = {};

  Future<String> _getUserName(String uid) async {
    if (_mentorNames.containsKey(uid)) {
      return _mentorNames[uid]!;
    } else {
      try {
        // Check mentors
        var mentorDoc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
        if (mentorDoc.exists && mentorDoc.data() != null && mentorDoc.data()!.containsKey('name')) {
          String name = mentorDoc['name'];
          _mentorNames[uid] = name;
          return name;
        }

        // Check students
        var studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
        if (studentDoc.exists && studentDoc.data() != null && studentDoc.data()!.containsKey('name')) {
          String name = studentDoc['name'];
          _mentorNames[uid] = name;
          return name;
        }

        // Check admins
        var adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
        if (adminDoc.exists && adminDoc.data() != null && adminDoc.data()!.containsKey('name')) {
          String name = adminDoc['name'];
          _mentorNames[uid] = name;
          return name;
        }

        // If not found in any collection
        _mentorNames[uid] = 'Unknown';
        return 'Unknown';
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

  void _toggleReplyLike(String commentId, String replyId, List<dynamic> likes) async {
    final userId = currentUser?.uid;
    if (userId == null) return;

    final replyRef = FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    if (likes.contains(userId)) {
      // Remove like
      await replyRef.update({
        'likes': FieldValue.arrayRemove([userId])
      });
    } else {
      // Add like
      await replyRef.update({
        'likes': FieldValue.arrayUnion([userId])
      });
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

            // Determine how many to show:
            bool showAll = _showAllReplies[commentId] ?? false;
            int replyCount = replies.length;
            int displayCount = showAll ? replyCount : (replyCount > 1 ? 1 : replyCount);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: displayCount,
                  itemBuilder: (context, index) {
                    final data = replies[index].data() as Map<String, dynamic>;
                    final uid = data['uid'] ?? '';
                    final text = data['text'] ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final likes = (data['likes'] ?? []) as List<dynamic>;
                    return FutureBuilder<String>(
                      future: _getUserName(uid),
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
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : Colors.blueGrey[900],
                                              ),
                                            ),
                                                SizedBox(height: 4),
                                                Text(text, style: TextStyle(fontSize: 14)),
                                                SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Text(
                                                      timestamp != null ? _formatTimestamp(timestamp.toDate()) : '',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                                    ),
                                                    SizedBox(width: 10),
                                                    IconButton(
                                                      icon: Icon(
                                                        likes.contains(currentUser?.uid) ? Icons.favorite : Icons.favorite_border,
                                                        color: likes.contains(currentUser?.uid) ? Colors.red : Colors.grey,
                                                        size: 18,
                                                      ),
                                                      onPressed: () {
                                                        _toggleReplyLike(commentId, replies[index].id, likes);
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints: BoxConstraints(),
                                                    ),
                                                    Text('${likes.length}', style: TextStyle(fontSize: 12)),
                                                  ],
                                                ),

                                              ],
                                            ),
                                          ),
                                          if (currentUser?.uid == uid)
                                            PopupMenuButton<String>(
                                              onSelected: (value) async {
                                                if (value == 'delete') {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text('Delete Reply'),
                                                      content: Text('Are you sure you want to delete this reply?'),
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
                                                    await FirebaseFirestore.instance
                                                        .collection('notices')
                                                        .doc(widget.noticeId)
                                                        .collection('comments')
                                                        .doc(commentId)
                                                        .collection('replies')
                                                        .doc(replies[index].id)
                                                        .delete();
                                                  }
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                                              ],

                                            ),
                                        ],
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
                ),

                // Show more / hide button if replies > 3
                if (replyCount > 1)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllReplies[commentId] = !showAll;
                      });
                    },
                    child: Text(showAll ? 'Hide replies' : 'Show more replies'),
                  ),
              ],
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
                SizedBox(width: 8),  // small spacing between buttons
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: () {
                    setState(() {
                      controller.clear();  // clear the input
                      _showReplyField[commentId] = false;  // hide the reply box
                    });
                  },
                  child: Text('Cancel'),
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
                        future: _getUserName(uid),
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
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : Colors.blueGrey[900],
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              timestamp != null ? _formatTimestamp(timestamp.toDate()) : '',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.grey[400]  // lighter grey on dark backgrounds
                                                    : Colors.grey[600], // darker grey on light backgrounds
                                              ),
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

                                                // First delete replies
                                                final repliesSnapshot = await commentRef.collection('replies').get();
                                                for (var doc in repliesSnapshot.docs) {
                                                  await doc.reference.delete();
                                                }

                                                // Then delete the comment
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
                                                  Text('Delete'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    text,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          likedByUser ? Icons.favorite : Icons.favorite_border,
                                          color: likedByUser ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () => _toggleLike(commentId, likes),
                                      ),
                                      Text('${likes.length}'),
                                      SizedBox(width: 16),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _showReplyField[commentId] = !(_showReplyField[commentId] ?? false);
                                          });
                                        },
                                        child: Text('Reply'),
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
            Divider(height: 1),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Wrap IconButton in a decorated container to get button style
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _postComment,
                      splashRadius: 24,
                      tooltip: 'Post',
                    ),
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

