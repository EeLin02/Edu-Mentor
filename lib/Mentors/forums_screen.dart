import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'createForumPostScreen.dart';
import 'forumCommentsScreen.dart';


class ForumsScreen extends StatefulWidget {
  @override
  _ForumsScreenState createState() => _ForumsScreenState();
}

class _ForumsScreenState extends State<ForumsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  void _showNewPostDialog() {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Forum Post'),
        content: TextField(
          controller: _controller,
          maxLines: 5,
          decoration: InputDecoration(hintText: 'Write your question here...'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Post'),
            onPressed: () async {
              final text = _controller.text.trim();
              if (text.isNotEmpty) {
                final mentorDoc = await FirebaseFirestore.instance
                    .collection('mentors')
                    .doc(currentUser!.uid)
                    .get();

                await FirebaseFirestore.instance.collection('forums').add({
                  'userId': currentUser!.uid,
                  'userName': mentorDoc['name'],
                  'userPhoto': mentorDoc['fileUrl'],
                  'text': text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'likes': [],
                });
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _toggleLike(String postId, List likes) async {
    final userId = currentUser!.uid;
    final postRef = FirebaseFirestore.instance.collection('forums').doc(postId);

    if (likes.contains(userId)) {
      // Unlike
      await postRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      // Like
      await postRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });
    }
  }

  void _showCommentDialog(String postId) {
    final TextEditingController _commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Comment'),
        content: TextField(
          controller: _commentController,
          decoration: InputDecoration(hintText: 'Write a comment...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _commentController.text.trim();
              if (text.isNotEmpty) {
                final userDoc = await FirebaseFirestore.instance
                    .collection('mentors')
                    .doc(currentUser!.uid)
                    .get();

                await FirebaseFirestore.instance
                    .collection('forums')
                    .doc(postId)
                    .collection('comments')
                    .add({
                  'userId': currentUser!.uid,
                  'userName': userDoc['name'],
                  'text': text,
                  'timestamp': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(context);
            },
            child: Text('Comment'),
          ),
        ],
      ),
    );
  }


  void _deletePost(String docId) async {
    await FirebaseFirestore.instance.collection('forums').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forums'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('forums')
            .where('userId', isEqualTo: currentUser!.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text('No forum posts yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final isOwner = data['userId'] == currentUser!.uid;

              final likes = (data.data() as Map<String, dynamic>).containsKey('likes')
                  ? List<String>.from(data['likes'])
                  : <String>[];
              final hasLiked = likes.contains(currentUser!.uid);


              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(data['userPhoto']),
                        ),
                        title: Text(data['userName']),
                        subtitle: Text(
                          data['text'],
                          style: TextStyle(fontSize: 15),
                        ),
                        trailing: isOwner
                            ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deletePost(data.id);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        )
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          data['timestamp'] != null
                              ? DateFormat('EEEE, MMM d, yyyy at h:mm a')
                              .format(data['timestamp'].toDate())
                              : 'Just now',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      Divider(),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleLike(data.id, likes),
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
                          SizedBox(width: 24),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForumCommentsScreen(postId: data.id),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Icon(Icons.comment_outlined, size: 18),
                                SizedBox(width: 4),
                                Text('Comment'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text('No comments yet', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateForumPostScreen()),
          );
        },
        backgroundColor: Colors.teal,
        child: Icon(Icons.add,color: Colors.white),
      ),

    );
  }
}
