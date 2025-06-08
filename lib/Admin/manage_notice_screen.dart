import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_notice_screen.dart';  // Import the new edit screen
import 'comments_view.dart';

class ManageNoticesScreen extends StatefulWidget {
  @override
  _ManageNoticesScreenState createState() => _ManageNoticesScreenState();
}

void _showLikesDialog(BuildContext context, String noticeId, List<String> likedUserIds) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Likes'),
        content: SizedBox(
          width: double.maxFinite,
          child: likedUserIds.isEmpty
              ? Text('No likes yet')
              : ListView.builder(
            shrinkWrap: true,
            itemCount: likedUserIds.length,
            itemBuilder: (context, index) {
              final userId = likedUserIds[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('students').doc(userId).get(),
                builder: (context, studentSnapshot) {
                  if (studentSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(title: Text('Loading...'));
                  }

                  if (studentSnapshot.hasData && studentSnapshot.data!.exists) {
                    final userData = studentSnapshot.data!.data() as Map<String, dynamic>?;

                    final userName = userData?['name'] ?? 'Unknown student';
                    final profileUrl = userData?['profileUrl'];

                    return ListTile(
                      leading: profileUrl != null
                          ? CircleAvatar(backgroundImage: NetworkImage(profileUrl))
                          : CircleAvatar(child: Icon(Icons.person)),
                      title: Text(userName),
                    );
                  } else {
                    // If not found in students, check mentors
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('mentors').doc(userId).get(),
                      builder: (context, mentorSnapshot) {
                        if (mentorSnapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(title: Text('Loading...'));
                        }

                        if (mentorSnapshot.hasData && mentorSnapshot.data!.exists) {
                          final userData = mentorSnapshot.data!.data() as Map<String, dynamic>?;

                          final userName = userData?['name'] ?? 'Unknown mentor';
                          final profileUrl = userData?['profileUrl'];

                          return ListTile(
                            leading: profileUrl != null
                                ? CircleAvatar(backgroundImage: NetworkImage(profileUrl))
                                : CircleAvatar(child: Icon(Icons.person)),
                            title: Text(userName),
                          );
                        } else {
                          // Not found in either collection
                          return ListTile(
                            leading: CircleAvatar(child: Icon(Icons.person_off)),
                            title: Text('User not found'),
                          );
                        }
                      },
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      );
    },
  );
}


void _showCommentsDialog(BuildContext context, String noticeId) {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Not Signed In'),
        content: Text('Please sign in to view comments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CommentsPage(noticeId: noticeId),
    ),
  );
}


/// Helper to fetch user document from either mentors or students collection.
Future<DocumentSnapshot> _fetchUserDoc(String uid) async {
  final mentorDoc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
  if (mentorDoc.exists) return mentorDoc;

  final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
  return studentDoc;
}


class _ManageNoticesScreenState extends State<ManageNoticesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Notices'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No notices found.'));
          }

          final notices = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final notice = notices[index];
              final title = notice['title'];
              final description = notice['description'];
              final fileUrls = List<String>.from(notice['fileUrls'] ?? []);
              final fileNames = List<String>.from(notice['fileNames'] ?? []);
              final likeMap = notice['likes'] as Map<String, dynamic>? ?? {};
              final likeCount = likeMap.length;
              final likedUserIds = likeMap.keys.toList();

              return Card(
                margin: EdgeInsets.all(8.0),
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and More Options in one row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.deepPurple),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditNoticeScreen(
                                      noticeId: notice.id,
                                      initialTitle: title,
                                      initialDescription: description,
                                      initialFileUrls: fileUrls,
                                      initialFileNames: fileNames,
                                    ),
                                  ),
                                );
                              } else if (value == 'delete') {
                                await FirebaseFirestore.instance
                                    .collection('notices')
                                    .doc(notice.id)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Notice deleted')),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.deepPurple),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
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
                      SizedBox(height: 8),
                      Text(description),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(fileUrls.length, (fileIndex) {
                          final fileUrl = fileUrls[fileIndex];
                          final fileName = fileNames[fileIndex];
                          final fileType = fileName.split('.').last.toLowerCase();

                          if (['jpg', 'jpeg', 'png'].contains(fileType)) {
                            return Image.network(
                              fileUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            );
                          } else if (['mp4', 'mov'].contains(fileType)) {
                            return VideoPreview(url: fileUrl);
                          } else if (fileType == 'pdf') {
                            return Icon(Icons.picture_as_pdf, size: 40, color: Colors.red);
                          } else {
                            return Icon(Icons.insert_drive_file, size: 40, color: Colors.blue);
                          }
                        }),
                      ),
                      SizedBox(height: 8),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('notices')
                            .doc(notice.id)
                            .collection('comments')
                            .get(),
                        builder: (context, commentSnapshot) {
                          int commentCount = commentSnapshot.data?.docs.length ?? 0;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final currentUser = FirebaseAuth.instance.currentUser;
                                  if (currentUser == null) return;

                                  final noticeRef = FirebaseFirestore.instance.collection('notices').doc(notice.id);

                                  final currentLikes = Map<String, dynamic>.from(notice['likes'] ?? {});
                                  final userId = currentUser.uid;

                                  setState(() {
                                    if (currentLikes.containsKey(userId)) {
                                      currentLikes.remove(userId);
                                    } else {
                                      currentLikes[userId] = true;
                                    }
                                  });

                                  await noticeRef.update({'likes': currentLikes});
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      likedUserIds.contains(FirebaseAuth.instance.currentUser?.uid)
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      size: 20,
                                      color: Colors.deepPurple,
                                    ),
                                    SizedBox(width: 4),
                                    Text('$likeCount'),
                                  ],
                                ),
                              ),

                              SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => _showCommentsDialog(context, notice.id),
                                child: Row(
                                  children: [
                                    Icon(Icons.comment, size: 20, color: Colors.deepPurple),
                                    SizedBox(width: 4),
                                    Text('$commentCount'),
                                  ],
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
    );
  }
}

class VideoPreview extends StatefulWidget {
  final String url;

  VideoPreview({required this.url});

  @override
  _VideoPreviewState createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
      })
      ..setLooping(true)
      ..play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    )
        : Center(child: CircularProgressIndicator());
  }
}
