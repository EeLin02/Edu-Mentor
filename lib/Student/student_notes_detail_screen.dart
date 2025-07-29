import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'note_editor.dart';

class StudentNotesDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color? color;

  const StudentNotesDetailScreen({
    super.key,
    required this.data,
    this.color,
  });

  @override
  State<StudentNotesDetailScreen> createState() => _StudentNotesDetailScreen();
}

class _StudentNotesDetailScreen extends State<StudentNotesDetailScreen> {
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
    final postedTimestamp = widget.data['timestamp'];
    final externalLinks = widget.data['externalLinks'] as List? ?? [];
    final Color appBarColor = widget.color ?? Colors.blue;
    final bool isLight = appBarColor.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['title'] ?? 'Resource'),
        backgroundColor: appBarColor,
        foregroundColor: textColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModernResourceCard(
              title: widget.data['title'] ?? 'No Title',
              description: widget.data['description'] ?? 'No Description',
              mentorDetailsFuture: _mentorDetailsFuture,
              files: widget.data['files'] as List? ?? [],
              externalLinks: widget.data['externalLinks'] as List? ?? [],
              postedTimestamp: widget.data['timestamp'],
              subjectName: widget.data['subjectName'],
              className: widget.data['className'],
            ),

            NoteEditor(
              resourceId: widget.data['resourceId'],
              color: widget.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernResourceCard extends StatelessWidget {
  final String title;
  final String description;
  final Future<List<Map<String, dynamic>>> mentorDetailsFuture;
  final List<dynamic> files;
  final List<dynamic> externalLinks;
  final dynamic postedTimestamp;
  final String? subjectName;
  final String? className;

  const _ModernResourceCard({
    required this.title,
    required this.description,
    required this.mentorDetailsFuture,
    required this.files,
    required this.postedTimestamp,
    required this.externalLinks,
    this.subjectName,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // 🔧 FIXED

    return Card(
      margin: const EdgeInsets.all(0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            if (subjectName != null) Text('Subject: $subjectName'),
            if (className != null) Text('Class: $className'),
            if (postedTimestamp != null)
              Text('Posted on: ${DateTime.fromMillisecondsSinceEpoch(postedTimestamp.seconds * 1000)}'),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: mentorDetailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError || snapshot.data!.isEmpty) {
                  return const Text('Mentor: Unknown');
                }
                final mentor = snapshot.data!.first;
                return Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(mentor['profileUrl']),
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                    Text('Mentor: ${mentor['name']}'),
                  ],
                );
              },
            ),
            if (externalLinks.isNotEmpty) ...[
              const Divider(thickness: 1.2, height: 30),
              Text('Links', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: externalLinks.map<Widget>((link) {
                  return ActionChip(
                    label: Text(
                      link.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.deepPurple),
                    ),
                    backgroundColor: Colors.grey.shade100,
                    onPressed: () async {
                      final uri = Uri.parse(link.toString());
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open link')),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ],
            if (files.isNotEmpty) ...[
              const Divider(thickness: 1.2, height: 30),
              Text('Attached Files', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...files.map((fileUrl) {
                final fileName = Uri.decodeFull(fileUrl.toString().split('/').last.split('?').first);

                Icon getIcon(String fileName) {
                  if (fileName.endsWith('.pdf')) return const Icon(Icons.picture_as_pdf, color: Colors.red);
                  if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
                    return const Icon(Icons.description, color: Colors.blue);
                  }
                  if (fileName.endsWith('.jpg') || fileName.endsWith('.png')) {
                    return const Icon(Icons.image, color: Colors.green);
                  }
                  return const Icon(Icons.attach_file, color: Colors.grey);
                }

                return ListTile(
                  leading: getIcon(fileName),
                  title: Text(fileName),
                  trailing: IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () async => _downloadFile(context, fileUrl.toString(), fileName),
                  ),
                  onTap: () {
                    final isPdf = fileName.toLowerCase().endsWith('.pdf');
                    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
                        fileName.toLowerCase().endsWith('.jpeg') ||
                        fileName.toLowerCase().endsWith('.png');

                    if (isPdf || isImage) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FilePreviewScreen(fileUrl: fileUrl.toString()),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preview not supported for this file type.')),
                      );
                    }
                  },
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context, String url, String filename) async {
    final status = await _checkPermission();

    if (!status) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied')),
      );
      return;
    }

    final dir = await getExternalStorageDirectory();
    final filePath = '${dir!.path}/$filename';

    try {
      final response = await Dio().download(url, filePath);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded to $filePath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<bool> _checkPermission() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final status = await Permission.photos.request();
      return status.isGranted;
    } else {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }
}

class FilePreviewScreen extends StatefulWidget {
  final String fileUrl;

  const FilePreviewScreen({super.key, required this.fileUrl});

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