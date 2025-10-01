import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chewie/chewie.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';

class FilePreviewScreen extends StatelessWidget {
  final String fileUrl;
  final String fileName;

  const FilePreviewScreen({
    Key? key,
    required this.fileUrl,
    required this.fileName,
  }) : super(key: key);

  /// ✅ Open external links safely
  Future<void> _openLink(BuildContext context, String url) async {
    String rawLink = url.trim();
    if (!rawLink.startsWith('http://') && !rawLink.startsWith('https://')) {
      rawLink = 'https://$rawLink';
    }

    final uri = Uri.tryParse(rawLink);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid link: $rawLink')),
      );
      return;
    }

    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $rawLink')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
    }
  }

  /// ✅ Download file with permission handling
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

  /// ✅ Check permissions depending on Android version
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

  @override
  Widget build(BuildContext context) {
    final fileType = fileName.split('.').last.toLowerCase();

    Widget previewWidget;

    if (['jpg', 'jpeg', 'png'].contains(fileType)) {
      previewWidget = InteractiveViewer(
        child: Image.network(fileUrl, fit: BoxFit.contain),
      );
    } else if (['mp4', 'mov'].contains(fileType)) {
      previewWidget = ChewieVideoPlayer(videoUrl: fileUrl);
    } else if (fileType == 'pdf') {
      previewWidget = PdfViewWidget(fileUrl: fileUrl);
    } else if (['doc', 'docx'].contains(fileType)) {
      previewWidget = _buildOfficePlaceholder(
        context,
        fileType: 'Word Document',
        icon: Icons.description,
        color: Colors.blue,
      );
    } else if (['xls', 'xlsx'].contains(fileType)) {
      previewWidget = _buildOfficePlaceholder(
        context,
        fileType: 'Excel Sheet',
        icon: Icons.table_chart,
        color: Colors.green,
      );
    } else if (['ppt', 'pptx'].contains(fileType)) {
      previewWidget = _buildOfficePlaceholder(
        context,
        fileType: 'PowerPoint Presentation',
        icon: Icons.slideshow,
        color: Colors.orange,
      );
    } else {
      previewWidget = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 80, color: Colors.blue),
            const SizedBox(height: 12),
            Text('Preview not supported for .$fileType'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _openLink(context, fileUrl),
              child: const Text('Open Externally'),
            )
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Preview"), // ✅ show real filename, not just "Preview"
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadFile(context, fileUrl, fileName),
          ),
        ],
      ),
      body: Center(child: previewWidget),
    );
  }

  Widget _buildOfficePlaceholder(BuildContext context,
      {required String fileType, required IconData icon, required Color color}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 12),
          Text(fileType, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _openLink(context, fileUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Office App'),
          ),
        ],
      ),
    );
  }
}

//
// ✅ Chewie Video Player
//
class ChewieVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const ChewieVideoPlayer({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<ChewieVideoPlayer> createState() => _ChewieVideoPlayerState();
}

class _ChewieVideoPlayerState extends State<ChewieVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController,
            autoPlay: true,
            looping: false,
          );
        });
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController != null && _videoController.value.isInitialized) {
      return Chewie(controller: _chewieController!);
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}

//
// ✅ PDF Preview
//
class PdfViewWidget extends StatefulWidget {
  final String fileUrl;
  const PdfViewWidget({Key? key, required this.fileUrl}) : super(key: key);

  @override
  State<PdfViewWidget> createState() => _PdfViewWidgetState();
}

class _PdfViewWidgetState extends State<PdfViewWidget> {
  PdfController? _pdfController;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.fileUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        setState(() {
          _pdfController = PdfController(
            document: PdfDocument.openData(bytes),
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading PDF: $e");
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pdfController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfView(controller: _pdfController!);
  }
}
