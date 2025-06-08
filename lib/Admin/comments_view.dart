import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommentsPage extends StatefulWidget {
  final String noticeId;

  const CommentsPage({super.key, required this.noticeId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();

  Future<DocumentSnapshot?> _fetchUserDoc(String uid) async {
    final mentorDoc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
    if (mentorDoc.exists) return mentorDoc;

    final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
    if (studentDoc.exists) return studentDoc;

    final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    if (adminDoc.exists) return adminDoc;

    return null;
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .add({
      'uid': uid,
      'text': text,
      'timestamp': Timestamp.now(),
      'likes': [],
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80), // padding for input bar
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notices')
              .doc(widget.noticeId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading comments: ${snapshot.error}'));
            }
            final comments = snapshot.data?.docs ?? [];

            if (comments.isEmpty) {
              return const Center(child: Text('No comments yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final commentDoc = comments[index];
                final data = commentDoc.data() as Map<String, dynamic>;

                return FutureBuilder<DocumentSnapshot?>(
                  future: _fetchUserDoc(data['uid'] ?? ''),
                  builder: (context, userSnapshot) {
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

                    final userName = userData?['name'] ?? 'Unknown user';
                    final profileUrl = userData?['profileUrl'];

                    return CommentCard(
                      commentId: commentDoc.id,
                      noticeId: widget.noticeId,
                      userName: userName,
                      profileUrl: profileUrl,
                      text: data['text'] ?? '',
                      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
                      likesList: List<String>.from(data['likes'] ?? []),
                      commentUid: data['uid'] ?? '',
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    fillColor: Colors.grey[100],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.deepPurpleAccent,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _addComment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommentCard extends StatefulWidget {
  final String commentId;
  final String noticeId;
  final String userName;
  final String? profileUrl;
  final String text;
  final DateTime? timestamp;
  final List<String> likesList;
  final String commentUid;

  const CommentCard({
    super.key,
    required this.commentId,
    required this.noticeId,
    required this.userName,
    required this.profileUrl,
    required this.text,
    required this.timestamp,
    required this.likesList,
    required this.commentUid,
  });

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool showReplies = false;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  final replyController = TextEditingController();

  Future<DocumentSnapshot?> _fetchUserDoc(String uid) async {
    final mentorDoc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
    if (mentorDoc.exists) return mentorDoc;

    final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
    if (studentDoc.exists) return studentDoc;

    return null;
  }

  void _deleteComment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment"),
        content: const Text("Are you sure you want to delete this comment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('notices')
          .doc(widget.noticeId)
          .collection('comments')
          .doc(widget.commentId)
          .delete();
    }
  }

  void _deleteReply(String replyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Reply"),
        content: const Text("Are you sure you want to delete this reply?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('notices')
          .doc(widget.noticeId)
          .collection('comments')
          .doc(widget.commentId)
          .collection('replies')
          .doc(replyId)
          .delete();
    }
  }

  void _addReply() async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String name = 'Unknown';

    // Helper function to try fetching user name from a collection
    Future<String?> getNameFromCollection(String collection) async {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('name')) {
          return data['name'] as String;
        }
      }
      return null;
    }

    // Try students, mentors, admins
    name = await getNameFromCollection('students') ??
        await getNameFromCollection('mentors') ??
        await getNameFromCollection('admins') ??
        'Unknown';

    await FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('replies')
        .add({
      'uid': uid,
      'name': name,
      'text': text,
      'timestamp': Timestamp.now(),
      'likes': [],
    });

    replyController.clear();
    setState(() {});
  }

  Future<void> _toggleCommentLike() async {
    final uid = currentUid;
    if (uid == null) return;

    final commentRef = FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .doc(widget.commentId);

    final docSnapshot = await commentRef.get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data()!;
    final List<dynamic> likes = data['likes'] ?? [];

    if (likes.contains(uid)) {
      // Unlike
      likes.remove(uid);
    } else {
      // Like
      likes.add(uid);
    }

    await commentRef.update({'likes': likes});
  }

  Future<void> _toggleReplyLike(String replyId, List<dynamic> likes) async {
    final uid = currentUid;
    if (uid == null) return;

    final replyRef = FirebaseFirestore.instance
        .collection('notices')
        .doc(widget.noticeId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('replies')
        .doc(replyId);

    final List<dynamic> newLikes = List<dynamic>.from(likes);

    if (newLikes.contains(uid)) {
      newLikes.remove(uid);
    } else {
      newLikes.add(uid);
    }

    await replyRef.update({'likes': newLikes});
  }

  @override
  void dispose() {
    replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCommentOwner = currentUid == widget.commentUid;
    final currentUserLiked = widget.likesList.contains(currentUid);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.profileUrl != null ? NetworkImage(widget.profileUrl!) : null,
                  child: widget.profileUrl == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    currentUserLiked ? Icons.favorite : Icons.favorite_border,
                    color: currentUserLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleCommentLike,
                ),
                if (isCommentOwner)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteComment,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.text),
            if (widget.timestamp != null)
              Text(
                '${widget.timestamp!.toLocal()}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            Text(
              'Likes: ${widget.likesList.length}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const Divider(),

            // Toggle Replies Button
            TextButton(
              onPressed: () {
                setState(() {
                  showReplies = !showReplies;
                });
              },
              child: Text(showReplies ? "Hide Replies" : "Show Replies"),
            ),

            // Replies Section (real-time)
            if (showReplies)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notices')
                    .doc(widget.noticeId)
                    .collection('comments')
                    .doc(widget.commentId)
                    .collection('replies')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No replies yet.'),
                    );
                  }

                  final replies = snapshot.data!.docs;

                  return Column(
                    children: replies.map((doc) {
                      final replyData = doc.data() as Map<String, dynamic>;
                      final replyText = replyData['text'] ?? '';
                      final replyTimestamp = (replyData['timestamp'] as Timestamp?)?.toDate();
                      final replyUid = replyData['uid'] ?? '';
                      final replyName = replyData['name'] ?? 'User';
                      final replyLikes = List<String>.from(replyData['likes'] ?? []);
                      final replyLikesCount = replyLikes.length;
                      final isReplyOwner = replyUid == currentUid;
                      final currentUserLikedReply = replyLikes.contains(currentUid);

                      return FutureBuilder<DocumentSnapshot?>(
                        future: _fetchUserDoc(replyUid),
                        builder: (context, userSnapshot) {
                          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                          final profileUrl = userData?['profileUrl'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                              child: profileUrl == null ? const Icon(Icons.person) : null,
                            ),
                            title: Text(
                              replyData['name'] ??
                                  (userData != null && userData['name'] != null
                                      ? userData['name']
                                      : 'Unknown'),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(replyText),
                                if (replyTimestamp != null)
                                  Text(
                                    '${replyTimestamp.toLocal()}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                Row(
                                  children: [
                                    Text(
                                      'Likes: $replyLikesCount',
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        currentUserLikedReply ? Icons.favorite : Icons.favorite_border,
                                        color: currentUserLikedReply ? Colors.red : Colors.grey,
                                      ),
                                      onPressed: () => _toggleReplyLike(doc.id, replyLikes),
                                    ),
                                    if (isReplyOwner)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteReply(doc.id),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),

            // Reply input
            if (showReplies) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      decoration: const InputDecoration(
                        hintText: "Write a reply...",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _addReply,
                  )
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
