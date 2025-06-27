import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';



class PreviewAnnouncementScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color color;


  const PreviewAnnouncementScreen({
    Key? key,
    required this.data,
    required this.color,

  }) : super(key: key);

  @override
  State<PreviewAnnouncementScreen> createState() =>
      _PreviewAnnouncementScreenState();
}

class _PreviewAnnouncementScreenState extends State<PreviewAnnouncementScreen> {
  late Future<List<Map<String, dynamic>>> _mentorDetailsFuture;

  @override
  void initState() {
    super.initState();
    _mentorDetailsFuture = _fetchMentorDetails();
  }

  Future<List<Map<String, dynamic>>> _fetchMentorDetails() async {
    final firestore = FirebaseFirestore.instance;
    final mentorsId = widget.data['mentorsId'] as String?;

    if (mentorsId == null || mentorsId.isEmpty) return [];

    final mentorDoc = await firestore.collection('mentors').doc(mentorsId).get();

    if (!mentorDoc.exists) return [];

    final mentorData = mentorDoc.data();
    if (mentorData == null) return [];

    return [
      {
        'name': mentorData['name'] ?? 'Unknown Mentor',
        'profileUrl': mentorData['profileUrl'] ?? '',
      }
    ];
  }

  @override
  Widget build(BuildContext context) {

    final postedTimestamp = widget.data['timestamp']; // Retrieve the posted timestamp
    final externalLinks = widget.data['externalLinks'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['title'] ?? 'Announcement'),
        backgroundColor: widget.color,
        foregroundColor: ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
            ? Colors.white
            : Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _ModernAnnouncementCard(
          title: widget.data['title'] ?? 'No Title',
          description: widget.data['description'] ?? 'No Description',
          mentorDetailsFuture: _mentorDetailsFuture,
          files: widget.data['files'] as List? ?? [],
          externalLinks: externalLinks,
          postedTimestamp: postedTimestamp,
        ),
      ),
    );
  }
}

class _ModernAnnouncementCard extends StatelessWidget {
  final String title;
  final String description;
  final Future<List<Map<String, dynamic>>> mentorDetailsFuture;
  final List<dynamic> files;
  final List<dynamic> externalLinks;
  final dynamic postedTimestamp; // Dynamic type to handle different formats of timestamps

  const _ModernAnnouncementCard({
    Key? key,
    required this.title,
    required this.description,
    required this.mentorDetailsFuture,
    required this.files,
    required this.postedTimestamp,
    this.externalLinks = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMentorSection(theme),
            const SizedBox(height: 16),
            _buildPostedTimestamp(theme),
            _buildTitleAndSubtitle(theme),

            if (externalLinks.isNotEmpty) ...[
              const Divider(thickness: 1.2, height: 30),
              _buildExternalLinksSection(context, theme),
            ],
            if (files.isNotEmpty) ...[
              const Divider(thickness: 1.2, height: 30),
              _buildFilesSection(context, theme), // Pass context explicitly
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildMentorSection(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: mentorDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            'Loading mentors...',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
          );
        } else if (snapshot.hasError) {
          return Text(
            'Error loading mentors',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return Column(
            children: snapshot.data!.map((mentor) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: mentor['profileUrl'].isNotEmpty
                        ? NetworkImage(mentor['profileUrl'])
                        : null,
                    child: mentor['profileUrl'].isEmpty
                        ? Icon(Icons.person, size: 30, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    mentor['name'],
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              );
            }).toList(),
          );
        } else {
          return Text(
            'No mentors assigned',
            style: theme.textTheme.bodyLarge,
          );
        }
      },
    );
  }

  Widget _buildPostedTimestamp(ThemeData theme) {
    if (postedTimestamp == null) return const SizedBox.shrink();

    final timestamp = postedTimestamp is Timestamp
        ? postedTimestamp.toDate()
        : DateTime.tryParse(postedTimestamp.toString());

    final formattedTimestamp =
    timestamp != null ? '${timestamp.toLocal()}'.split(' ')[0] : 'Unknown';

    return Text(
      'Posted: $formattedTimestamp',
      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
    );
  }

  Widget _buildTitleAndSubtitle(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  Widget _buildExternalLinksSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Links',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: externalLinks.map<Widget>((link) {
            return ActionChip(
              label: Text(
                link.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.teal),
              ),
              backgroundColor: Colors.white,
              onPressed: () async {
                final url = Uri.parse(link.toString());
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication, // 🔥 KEY CHANGE
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open link')),
                  );
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFilesSection(BuildContext context, ThemeData theme) {
    Icon _getFileIcon(String fileName) {
      final ext = fileName.toLowerCase();
      if (ext.endsWith('.pdf'))
        return Icon(Icons.picture_as_pdf, color: Colors.red);
      if (ext.endsWith('.doc') || ext.endsWith('.docx'))
        return Icon(Icons.description, color: Colors.blueAccent);
      if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png'))
        return Icon(Icons.image, color: Colors.green);
      return Icon(Icons.attach_file, color: Colors.teal); // Default
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attached Files',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),
        ...files.map((fileUrl) {
          final decodedUrl = Uri.decodeFull(fileUrl.toString());
          final fileName = decodedUrl
              .split('/')
              .last
              .split('?')
              .first;

          return ListTile(
            leading: _getFileIcon(fileName),
            title: Text(fileName),
              onTap: () {
                final isPdf = fileName.toLowerCase().endsWith('.pdf');
                final isImage = fileName.toLowerCase().endsWith('.jpg') ||
                    fileName.toLowerCase().endsWith('.jpeg') ||
                    fileName.toLowerCase().endsWith('.png');

                if (isPdf || isImage) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FilePreviewScreen(fileUrl: fileUrl.toString()),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('File preview not supported for this type.')),
                  );
                }
              }

          );
        }).toList(),
      ],
    );
  }
}


class FilePreviewScreen extends StatefulWidget {
  final String fileUrl;

  const FilePreviewScreen({Key? key, required this.fileUrl}) : super(key: key);

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  late String fileName;

  @override
  void initState() {
    super.initState();
    fileName = _extractFileName(widget.fileUrl);
  }

  bool _isPdf(String name) => name.toLowerCase().endsWith('.pdf');

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  String _extractFileName(String url) {
    final decodedUrl = Uri.decodeFull(url);
    return decodedUrl
        .split('/')
        .last
        .split('?')
        .first;
  }

  Future<String> _downloadFile(String url, String name) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$name';

    final response = await Dio().download(url, path);
    if (response.statusCode == 200) {
      return path;
    } else {
      throw Exception('Failed to download file');
    }
  }


  Future<String> _downloadFileToDownloads(String url, String name) async {
    Directory? downloadsDirectory;

    if (Platform.isAndroid) {
      downloadsDirectory = Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      downloadsDirectory = await getApplicationDocumentsDirectory();
    } else {
      throw Exception('Unsupported platform');
    }

    final filePath = '${downloadsDirectory.path}/$name';

    final response = await Dio().download(url, filePath);
    if (response.statusCode == 200) {
      return filePath;
    } else {
      throw Exception('Failed to download file');
    }
  }

  Future<void> _downloadAndSaveToDownloads(BuildContext context, String url,
      String fileName) async {
    final deviceInfo = DeviceInfoPlugin();
    PermissionStatus status;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        status = await Permission.manageExternalStorage.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      // iOS permission handling (usually not required for saving to documents)
      status = await Permission.storage.request();
    }

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission denied')),
      );
      return;
    }

    try {
      final savedPath = await _downloadFileToDownloads(url, fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved to $savedPath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final fileName = _extractFileName(widget.fileUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text('File Preview'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.download,color: Colors.white),
            onPressed: () {
              _downloadAndSaveToDownloads(context, widget.fileUrl, fileName);
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _downloadFile(widget.fileUrl, fileName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.teal));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final filePath = snapshot.data!;
            if (_isPdf(fileName)) {
              return PDFView(filePath: filePath);
            } else if (_isImage(fileName)) {
              return Image.file(File(filePath));
            } else {
              return Center(
                  child: Text('Preview not supported for this file type.'));
            }
          }
          return SizedBox.shrink();
        },
      ),
    );
  }
}