import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'createForumPostScreen.dart';
import 'forumCommentsScreen.dart';
import 'EditForumScreen.dart';


class ForumsScreen extends StatefulWidget {
  @override
  _ForumsScreenState createState() => _ForumsScreenState();
}

class _ForumsScreenState extends State<ForumsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;



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





  void _deletePost(String docId) async {
    await FirebaseFirestore.instance.collection('forums').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forums',style: TextStyle(color: Colors.teal),),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('forums')
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
                            } else if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditForumPostScreen(
                                    postId: data.id,
                                    initialText: data['text'],
                                  ),
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('forums')
                            .doc(data.id)
                            .collection('comments')
                            .orderBy('timestamp', descending: true)
                            .limit(1)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Text('Loading comment...', style: TextStyle(color: Colors.grey));
                          }

                          if (snapshot.data!.docs.isEmpty) {
                            return Text('No comments yet', style: TextStyle(color: Colors.grey));
                          }

                          final latestComment = snapshot.data!.docs.first;
                          return Row(
                            children: [
                              Icon(Icons.comment, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${latestComment['userName']}: ${latestComment['text']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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
