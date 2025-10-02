import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'notice_comment_screen.dart';
import '../file_preview_screen.dart';

class NoticeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notices',style: TextStyle(color: Colors.teal),)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notices = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final data = notices[index].data() as Map<String, dynamic>;
              final noticeId = notices[index].id;
              final currentUser = FirebaseAuth.instance.currentUser;
              final likes = Map<String, dynamic>.from(data['likes'] ?? {});
              final isLiked =
                  currentUser != null && likes.containsKey(currentUser.uid);

              return Card(
                margin: const EdgeInsets.all(10),
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
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Description
                      Text(data['description'] ?? 'No Description'),
                      const SizedBox(height: 8),

                      // Files Preview
                      if (data['fileUrls'] != null && data['fileUrls'] is List)
                        Column(
                          children: List.generate(
                            (data['fileUrls'] as List).length,
                                (i) {
                              final fileUrl = data['fileUrls'][i];
                              final lowerUrl = fileUrl.toLowerCase().split('?').first; // strip query params

                              return Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 6),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 200,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FilePreviewScreen(
                                              fileUrl: fileUrl,
                                              fileName: Uri.decodeFull(
                                                fileUrl
                                                    .split('/')
                                                    .last
                                                    .split('?')
                                                    .first,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Builder(
                                        builder: (_) {
                                          // PDF
                                          if (lowerUrl.endsWith('.pdf')) {
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                                                    SizedBox(height: 10),
                                                    Text('PDF Document', style: TextStyle(fontSize: 16)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          // VIDEO
                                          else if (lowerUrl.endsWith('.mp4') || lowerUrl.endsWith('.mov')) {
                                            return FutureBuilder<Uint8List?>(
                                              future: VideoThumbnail.thumbnailData(
                                                video: fileUrl,
                                                imageFormat: ImageFormat.PNG,
                                                maxWidth: 400,
                                                quality: 75,
                                              ),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                  return Container(
                                                    color: Colors.black26,
                                                    child: const Center(child: CircularProgressIndicator()),
                                                  );
                                                }
                                                if (snapshot.hasData) {
                                                  return Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      Image.memory(snapshot.data!, fit: BoxFit.cover),
                                                      const Center(
                                                        child: Icon(Icons.play_circle_fill,
                                                            size: 70, color: Colors.white),
                                                      ),
                                                    ],
                                                  );
                                                }
                                                return Container(
                                                  color: Colors.black26,
                                                  child: const Center(
                                                    child: Icon(Icons.videocam, size: 60, color: Colors.grey),
                                                  ),
                                                );
                                              },
                                            );
                                          }

                                          // WORD
                                          else if (lowerUrl.endsWith('.doc') || lowerUrl.endsWith('.docx')) {
                                            return Container(
                                              color: Colors.blue[100],
                                              child: const Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.description, size: 60, color: Colors.blue),
                                                    SizedBox(height: 10),
                                                    Text('Word Document', style: TextStyle(fontSize: 16)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          // EXCEL
                                          else if (lowerUrl.endsWith('.xls') || lowerUrl.endsWith('.xlsx')) {
                                            return Container(
                                              color: Colors.green[100],
                                              child: const Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.table_chart, size: 60, color: Colors.green),
                                                    SizedBox(height: 10),
                                                    Text('Excel Sheet', style: TextStyle(fontSize: 16)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          // POWERPOINT
                                          else if (lowerUrl.endsWith('.ppt') || lowerUrl.endsWith('.pptx')) {
                                            return Container(
                                              color: Colors.orange[100],
                                              child: const Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.slideshow, size: 60, color: Colors.orange),
                                                    SizedBox(height: 10),
                                                    Text('PowerPoint', style: TextStyle(fontSize: 16)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          // IMAGE (jpg, png, etc.)
                                          else if (lowerUrl.endsWith('.jpg') ||
                                              lowerUrl.endsWith('.jpeg') ||
                                              lowerUrl.endsWith('.png') ||
                                              lowerUrl.endsWith('.gif') ||
                                              lowerUrl.endsWith('.webp')) {
                                            return CachedNetworkImage(
                                              imageUrl: fileUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                              const Center(child: CircularProgressIndicator()),
                                              errorWidget: (context, url, error) =>
                                              const Icon(Icons.error, color: Colors.red),
                                            );
                                          }

                                          // OTHER FILES → generic icon
                                          else {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.insert_drive_file,
                                                        size: 60, color: Colors.grey),
                                                    SizedBox(height: 10),
                                                    Text('Unsupported File', style: TextStyle(fontSize: 16)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),

                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Timestamp
                      Text(
                        (data['timestamp'] != null)
                            ? (data['timestamp'].toDate().toString())
                            : 'No Timestamp',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Divider(),

                      // Like and Comment
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isLiked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_alt_outlined,
                              color: isLiked ? Colors.blue : Colors.grey,
                            ),
                            onPressed: () async {
                              if (currentUser == null) return;
                              final noticeRef = FirebaseFirestore.instance
                                  .collection('notices')
                                  .doc(noticeId);
                              await noticeRef.update({
                                'likes.${currentUser.uid}': isLiked
                                    ? FieldValue.delete()
                                    : true,
                              });
                            },
                          ),
                          Text('${likes.length} Likes'),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.comment_outlined),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NoticeCommentScreen(noticeId: noticeId),
                                ),
                              );
                            },
                          ),
                          const Text('Comment'),
                        ],
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

