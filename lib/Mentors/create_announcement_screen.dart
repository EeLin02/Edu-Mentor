import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final String subjectName;
  final String className;
  final String? announcementId;
  final String? title;
  final String? description;
  final List<dynamic>? files; // URLs
  final List<String>? externalLinks;
  final Color? color;


  const CreateAnnouncementScreen({
    Key? key,
    required this.subjectName,
    required this.className,
    this.announcementId,
    this.title,
    this.description,
    this.files,
    this.externalLinks,
    this.color,
  }) : super(key: key);

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  List<PlatformFile> _selectedFiles = [];
  List<String> _existingFileUrls = [];
  List<String> _externalLinks = [];
  final TextEditingController _linkInputController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.title != null) _titleController.text = widget.title!;
    if (widget.description != null) _descriptionController.text = widget.description!;
    if (widget.files != null) _existingFileUrls = List<String>.from(widget.files!);
    if (widget.externalLinks != null) _externalLinks = List<String>.from(widget.externalLinks!);

    _linkController.addListener(() {
      setState(() {});// Allows suffixIcon (clear button) to update dynamically
    });

  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
        'jpg', 'jpeg', 'png', 'mp4', 'mov', 'txt'
      ],
    );
    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedFiles.add(PlatformFile(
          name: path.basename(pickedFile.path),
          path: pickedFile.path,
          size: File(pickedFile.path).lengthSync(),
        ));
      });
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedFiles.add(PlatformFile(
          name: path.basename(pickedFile.path),
          path: pickedFile.path,
          size: File(pickedFile.path).lengthSync(),
        ));
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _removeExistingFile(int index) async {
    String fileUrl = _existingFileUrls[index];

    setState(() {
      _existingFileUrls.removeAt(index);
    });

    // Optionally delete the file from Firebase Storage
    try {
      final ref = FirebaseStorage.instance.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting file from storage: $e")),
      );
    }

    // Update Firestore document if editing
    if (widget.announcementId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(widget.announcementId)
            .update({'files': _existingFileUrls});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File removed successfully")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating announcement: $e")),
        );
      }
    }
  }


  Future<void> _uploadAndPostAnnouncement() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? 'unknown_user';

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final externalLink = _linkController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Title and description are required.")),
      );
      return;
    }

    setState(() => _isUploading = true);

    List<String> newFileUrls = [];

    for (var file in _selectedFiles) {
      final fileName = path.basename(file.path!);
      final ref = FirebaseStorage.instance
          .ref('announcements/${widget.subjectName}_${widget.className}/$fileName');
      final uploadTask = await ref.putFile(File(file.path!));
      final url = await uploadTask.ref.getDownloadURL();
      newFileUrls.add(url);
    }

    final fileUrls = [..._existingFileUrls, ...newFileUrls];

    final data = {
      'subjectName': widget.subjectName,
      'className': widget.className,
      'title': title,
      'description': description,
      'files': fileUrls,
      'externalLinks': _externalLinks,
      'timestamp': FieldValue.serverTimestamp(),
      'mentorsId': uid,
    };

    if (widget.announcementId != null) {
      // Update existing
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(widget.announcementId)
          .update(data);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Announcement updated")));

      setState(() {
        _isUploading = false;
      });

      // DO NOT pop the screen here to keep user in edit mode
    } else {
      // Create new
      await FirebaseFirestore.instance.collection('announcements').add(data);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Announcement posted")));

      setState(() {
        _isUploading = false;
      });

      Navigator.pop(context); // You can keep this for new announcements
    }

  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.indigo;
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;
    final theme = Theme.of(context);


    return Scaffold(
      appBar: AppBar(
        title: Text(widget.announcementId != null ? 'Edit Announcement' : 'New Announcement'),
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Create Announcement", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text("External Links", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkInputController,
                  decoration: InputDecoration(
                    labelText: 'Add External Link (e.g., Google Docs/Drive)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.link),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        final newLink = _linkInputController.text.trim();
                        if (newLink.isNotEmpty && !_externalLinks.contains(newLink)) {
                          setState(() {
                            _externalLinks.add(newLink);
                            _linkInputController.clear();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _externalLinks
                      .map((link) => Chip(
                    label: Text(link, overflow: TextOverflow.ellipsis),
                    avatar: Icon(Icons.link, color: Colors.blue),
                    onDeleted: () {
                      setState(() {
                        _externalLinks.remove(link);
                      });

                      if (widget.announcementId != null) {
                        FirebaseFirestore.instance
                            .collection('announcements')
                            .doc(widget.announcementId)
                            .update({'externalLinks': _externalLinks});
                      }
                    },
                    deleteIconColor: Colors.red,
                  ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text("Attach Files", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: Icon(Icons.attach_file, color: Colors.teal),
                        label: Text("Files", style: TextStyle(color: Colors.teal)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.teal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: Icon(Icons.photo_library, color: Colors.green),
                        label: Text("Image", style: TextStyle(color: Colors.green)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickVideoFromGallery,
                        icon: Icon(Icons.video_library, color: Colors.red),
                        label: Text("Video", style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_existingFileUrls.isNotEmpty) ...[
                  Text("Existing Files", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingFileUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final fileUrl = _existingFileUrls[index];
                        final fileName = path.basename(Uri.parse(fileUrl).path);
                        return Chip(
                          label: Text(
                            fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          avatar: Icon(Icons.insert_drive_file, color: Colors.teal),
                          onDeleted: () => _removeExistingFile(index),
                          deleteIconColor: Colors.redAccent,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_selectedFiles.isNotEmpty) ...[
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        return Chip(
                          label: Text(
                            file.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          avatar: Icon(Icons.insert_drive_file, color: Colors.teal),
                          onDeleted: () => _removeFile(index),
                          deleteIconColor: Colors.redAccent,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadAndPostAnnouncement,
                    icon: _isUploading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Icon(Icons.send),
                    label: Text(
                      _isUploading
                          ? (widget.announcementId != null ? "Updating..." : "Posting...")
                          : (widget.announcementId != null ? "Update Announcement" : "Post Announcement"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: textColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
