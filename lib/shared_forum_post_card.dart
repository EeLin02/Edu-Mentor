import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:edumentor/Mentors/ForumCommentsScreen.dart';
import 'package:edumentor/Mentors/EditForumScreen.dart';

class ForumPostCard extends StatelessWidget {
  final QueryDocumentSnapshot data;
  final User? currentUser;
  final Color themeColor;
  final bool showDelete;

  final String userName;
  final String userPhoto;
  final String userIdNo;

  ForumPostCard({
    required this.data,
    required this.currentUser,
    this.themeColor = Colors.teal,
    this.showDelete = false,
    required this.userName,
    required this.userPhoto,
    required this.userIdNo,
  });

  void _toggleLike(String postId, List likes) async {
    final userId = currentUser!.uid;
    final postRef = FirebaseFirestore.instance.collection('forums')
        .doc(postId);

    if (likes.contains(userId)) {
      await postRef.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await postRef.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  void _deletePost(BuildContext context, String docId) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('forums').doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 22,
                  backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                  child: userPhoto.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 10),

                // Name + ID + Text (left-aligned)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$userName ($userIdNo)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showDelete)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deletePost(context, data.id);
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
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['text'],
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                data['timestamp'] != null
                    ? DateFormat('EEEE, MMM d, yyyy at h:mm a').format(data['timestamp'].toDate())
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
                        color: hasLiked ? themeColor : null,
                      ),
                      SizedBox(width: 4),
                      Text('${likes.length} Likes', style: TextStyle(color: themeColor)),
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
          ],
        ),
      ),
    );
  }
}


