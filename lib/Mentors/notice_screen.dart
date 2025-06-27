import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'notice_comment_screen.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';


class NoticeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notices')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final notices = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final data = notices[index].data() as Map<String, dynamic>;
              final noticeId = notices[index].id;
              final currentUser = FirebaseAuth.instance.currentUser;
              final likes = Map<String, dynamic>.from(data['likes'] ?? {});
              final isLiked = currentUser != null && likes.containsKey(currentUser.uid);

              return Card(
                margin: EdgeInsets.all(10),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        data['title'] ?? 'No Title',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      // Description
                      Text(data['description'] ?? 'No Description'),
                      SizedBox(height: 8),
                      // Images
                      if (data['fileUrls'] != null && data['fileUrls'] is List)
                        Column(
                          children: List.generate(
                            (data['fileUrls'] as List).length,
                                (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Container(
                                width: double.infinity,
                                height: 200,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GestureDetector(
                                    onTap: () {
                                      final fileUrl = data['fileUrls'][i];
                                      if (fileUrl.toLowerCase().contains('.pdf')) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PdfViewerScreen(pdfUrl: fileUrl),
                                          ),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FullscreenImageView(imageUrl: fileUrl),
                                          ),
                                        );
                                      }
                                    },
                                    child: data['fileUrls'][i].toLowerCase().contains('.pdf')
                                        ? Container(
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                                            SizedBox(height: 10),
                                            Text('PDF Document', style: TextStyle(fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    )
                                        : CachedNetworkImage(
                                      imageUrl: data['fileUrls'][i],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => Icon(Icons.error),
                                    ),
                                  ),


                                ),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 8),
                      // Timestamp
                      Text(
                        (data['timestamp'] != null)
                            ? (data['timestamp'].toDate().toString())
                            : 'No Timestamp',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Divider(),
// Like and Comment Buttons row remains the same here
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                              color: isLiked ? Colors.blue : Colors.grey,
                            ),
                            onPressed: () async {
                              if (currentUser == null) return;
                              final noticeRef = FirebaseFirestore.instance.collection('notices').doc(noticeId);
                              await noticeRef.update({
                                'likes.${currentUser.uid}': isLiked ? FieldValue.delete() : true,
                              });
                            },
                          ),
                          Text('${likes.length} Likes'),
                          SizedBox(width: 20),
                          IconButton(
                            icon: Icon(Icons.comment_outlined),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NoticeCommentScreen(noticeId: noticeId),
                                ),
                              );
                            },
                          ),
                          Text('Comment'),
                        ],
                      ),
                      SizedBox(height: 8),
// Latest comments under the buttons
                      LatestCommentsWidget(noticeId: noticeId),
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

//--------------image fullscreen view------------
class FullscreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullscreenImageView({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => CircularProgressIndicator(),
          errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
        ),
      ),
    );
  }
}

//------------view latest comments--------------
// Add this widget to display latest comments for a notice
class LatestCommentsWidget extends StatefulWidget {
  final String noticeId;

  const LatestCommentsWidget({Key? key, required this.noticeId}) : super(key: key);

  @override
  State<LatestCommentsWidget> createState() => _LatestCommentsWidgetState();
}

class _LatestCommentsWidgetState extends State<LatestCommentsWidget> {
  // Cache mentor names to avoid repeated fetches
  final Map<String, String> _mentorNames = {};

  // Async function to get user name by UID with caching
  Future<String> _getUserName(String uid) async {
    if (_mentorNames.containsKey(uid)) {
      return _mentorNames[uid]!;
    }

    try {
      // Check mentors
      final mentorDoc = await FirebaseFirestore.instance.collection('mentors').doc(uid).get();
      if (mentorDoc.exists && mentorDoc.data()?['name'] != null) {
        final name = mentorDoc['name'] as String;
        _mentorNames[uid] = name;
        return name;
      }

      // Check students
      final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
      if (studentDoc.exists && studentDoc.data()?['name'] != null) {
        final name = studentDoc['name'] as String;
        _mentorNames[uid] = name;
        return name;
      }

      // Check admins
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      if (adminDoc.exists && adminDoc.data()?['name'] != null) {
        final name = adminDoc['name'] as String;
        _mentorNames[uid] = name;
        return name;
      }

      // Not found
      _mentorNames[uid] = 'Unknown';
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .doc(widget.noticeId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error loading comments');
        if (snapshot.connectionState == ConnectionState.waiting) return CircularProgressIndicator();

        final comments = snapshot.data!.docs;

        if (comments.isEmpty) {
          return Text('No comments yet', style: TextStyle(color: Colors.grey));
        }

        // Build the comment list using FutureBuilder per comment to get mentor names
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: comments.map((doc) {
            final data = doc.data()! as Map<String, dynamic>;
            final uid = data['uid'] as String? ?? '';
            final commentText = data['comment'] ?? '';
            final timestamp = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
            final timeStr = timestamp != null
                ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                : '';
            final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

            // Use FutureBuilder to fetch and display mentor name asynchronously
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: FutureBuilder<String>(
                future: _getUserName(uid),
                builder: (context, nameSnapshot) {
                  final username = nameSnapshot.data ?? 'Loading...';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$username: ',
                                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                              ),
                              TextSpan(
                                text: commentText,
                                style: TextStyle(color: textColor),
                              ),
                              TextSpan(
                                text: '  $timeStr',
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

//--------------pdf fullscreen view------------

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;

  const PdfViewerScreen({required this.pdfUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF Preview')),
      body: SfPdfViewer.network(pdfUrl),
    );
  }
}
