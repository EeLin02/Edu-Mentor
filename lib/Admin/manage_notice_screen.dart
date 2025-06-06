import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

import 'edit_notice_screen.dart';  // Import the new edit screen

class ManageNoticesScreen extends StatefulWidget {
  @override
  _ManageNoticesScreenState createState() => _ManageNoticesScreenState();
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

              return Card(
                margin: EdgeInsets.all(8.0),
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
