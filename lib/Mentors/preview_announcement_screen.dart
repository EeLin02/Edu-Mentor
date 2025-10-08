import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../file_preview_screen.dart'; // import file preview

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

    final mentorDoc = await firestore.collection('mentors').doc(mentorsId)
        .get();

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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['title'] ?? 'Announcement'),
        backgroundColor: widget.color,
        foregroundColor:
        ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
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
  final dynamic postedTimestamp;

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
              _buildFilesSection(context, theme),
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
          return Text('Loading mentors...',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey));
        } else if (snapshot.hasError) {
          return Text('Error loading mentors',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red));
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
                        ? const Icon(Icons.person, size: 30, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(mentor['name'], style: theme.textTheme.titleMedium),
                ],
              );
            }).toList(),
          );
        } else {
          return Text('No mentors assigned',
              style: theme.textTheme.bodyLarge);
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

    return Text('Posted: $formattedTimestamp',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey));
  }

  Widget _buildTitleAndSubtitle(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.teal[700],
            )),
        const SizedBox(height: 8),
        Text(description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
      ],
    );
  }

  Widget _buildExternalLinksSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Links',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: externalLinks.map<Widget>((link) {
            return ActionChip(
              label: Text(
                link.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.teal),
              ),
              backgroundColor: Colors.white,
              onPressed: () async {
                final url = Uri.parse(link.toString());
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
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
    );
  }

  Widget _buildFilesSection(BuildContext context, ThemeData theme) {
    Icon _getFileIcon(String fileName) {
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.pdf')) return const Icon(Icons.picture_as_pdf, color: Colors.red);
      if (lower.endsWith('.doc') || lower.endsWith('.docx')) return const Icon(Icons.description, color: Colors.blue);
      if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return const Icon(Icons.slideshow, color: Colors.orange);
      if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return const Icon(Icons.table_chart, color: Colors.green);
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) return const Icon(Icons.image, color: Colors.teal);
      if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return const Icon(Icons.videocam, color: Colors.purple);
      return const Icon(Icons.attach_file, color: Colors.grey);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attached Files',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            )),
        const SizedBox(height: 8),
        ...files.map((fileUrl) {
          final decodedUrl = Uri.decodeFull(fileUrl.toString());
          final fileName = decodedUrl.split('/').last.split('?').first;

          return ListTile(
            leading: _getFileIcon(fileName),
            title: Text(fileName),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FilePreviewScreen(
                    fileUrl: fileUrl.toString(),
                    fileName: fileName, // pass file name
                  ),
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }
}
