import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

class NoticeBoardScreen extends StatefulWidget {
  @override
  _NoticeBoardScreenState createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<File> _selectedFiles = [];
  List<String?> _fileNames = [];
  List<String?> _fileMimes = [];
  List<VideoPlayerController?> _videoControllers = [];

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final newFiles = result.files.map((file) => File(file.path!)).toList();
      final newMimes = newFiles.map((file) => lookupMimeType(file.path)).toList();

      final newControllers = await Future.wait(newFiles.map((file) async {
        final mime = lookupMimeType(file.path);
        if (mime != null && mime.startsWith('video/')) {
          final controller = VideoPlayerController.file(file);
          await controller.initialize();
          controller.setLooping(true);
          controller.play();
          return controller;
        }
        return null;
      }));

      setState(() {
        _selectedFiles.addAll(newFiles);
        _fileNames.addAll(result.files.map((file) => file.name));
        _fileMimes.addAll(newMimes);
        _videoControllers.addAll(newControllers);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _videoControllers[index]?.dispose();
      _videoControllers.removeAt(index);
      _selectedFiles.removeAt(index);
      _fileNames.removeAt(index);
      _fileMimes.removeAt(index);
    });
  }

  Future<void> _postNotice() async {
    if (!_formKey.currentState!.validate()) return;

    final fileUrls = await Future.wait(_selectedFiles.map((file) async {
      final fileName = _fileNames[_selectedFiles.indexOf(file)] ?? 'file';
      final fileExt = fileName.split('.').last;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('notices/${DateTime.now().millisecondsSinceEpoch}.$fileExt');
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    }));

    await FirebaseFirestore.instance.collection('notices').add({
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'fileUrls': fileUrls,
      'fileNames': _fileNames,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notice posted successfully')),
    );

    _resetForm();
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _videoControllers.forEach((controller) => controller?.dispose());
    setState(() {
      _selectedFiles.clear();
      _fileNames.clear();
      _fileMimes.clear();
      _videoControllers.clear();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoControllers.forEach((controller) => controller?.dispose());
    super.dispose();
  }

  Widget _buildFilePreviewGrid() {
    final itemCount = _selectedFiles.length + 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _selectedFiles.length) {
          return GestureDetector(
            onTap: _pickFiles,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepPurple),
                borderRadius: BorderRadius.circular(8),
                color: Colors.deepPurple.withOpacity(0.1),
              ),
              child: Center(child: Icon(Icons.add, size: 40, color: Colors.deepPurple)),
            ),
          );
        }

        final file = _selectedFiles[index];
        final mime = _fileMimes[index];
        final controller = _videoControllers[index];

        Widget previewContent;
        if (mime == null) {
          previewContent = Center(child: Text('N/A'));
        } else if (mime.startsWith('image/')) {
          previewContent = Image.file(file, fit: BoxFit.cover);
        } else if (mime.startsWith('video/')) {
          if (controller != null && controller.value.isInitialized) {
            previewContent = AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            );
          } else {
            previewContent = Center(child: CircularProgressIndicator());
          }
        } else if (mime == 'application/pdf') {
          previewContent = Center(child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red));
        } else {
          previewContent = Center(child: Text('File'));
        }

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple),
              ),
              clipBehavior: Clip.hardEdge,
              child: previewContent,
            ),
            Positioned(
              right: 2,
              top: 2,
              child: InkWell(
                onTap: () => _removeFile(index),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notice Board'), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Enter title' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Enter description' : null,
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                icon: Icon(Icons.attach_file, color: Colors.deepPurple),
                label: Text('Attach Files'),
                onPressed: _pickFiles,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              ),
              SizedBox(height: 12),
              _buildFilePreviewGrid(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _postNotice,
                child: Text('Post Notice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
