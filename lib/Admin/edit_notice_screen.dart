import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

class EditNoticeScreen extends StatefulWidget {
  final String noticeId;
  final String initialTitle;
  final String initialDescription;
  final List<String> initialFileUrls;
  final List<String> initialFileNames;

  EditNoticeScreen({
    required this.noticeId,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialFileUrls,
    required this.initialFileNames,
  });

  @override
  _EditNoticeScreenState createState() => _EditNoticeScreenState();
}

class _EditNoticeScreenState extends State<EditNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  // New files selected from device
  List<File> _newFiles = [];
  List<String?> _newFileNames = [];
  List<String?> _newFileMimes = [];
  List<VideoPlayerController?> _newVideoControllers = [];

  // Existing files from Firestore (URLs + names)
  late List<String> _existingFileUrls;
  late List<String> _existingFileNames;

  // Track which existing files are removed by user
  List<bool> _existingFileRemoved = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(text: widget.initialDescription);

    _existingFileUrls = List<String>.from(widget.initialFileUrls);
    _existingFileNames = List<String>.from(widget.initialFileNames);
    _existingFileRemoved = List<bool>.filled(_existingFileUrls.length, false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _newVideoControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files.map((file) => File(file.path!)).toList();
      final mimes = files.map((file) => lookupMimeType(file.path)).toList();

      final controllers = await Future.wait(files.map((file) async {
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
        _newFiles.addAll(files);
        _newFileNames.addAll(result.files.map((f) => f.name));
        _newFileMimes.addAll(mimes);
        _newVideoControllers.addAll(controllers);
      });
    }
  }

  void _removeNewFile(int index) {
    setState(() {
      _newVideoControllers[index]?.dispose();
      _newVideoControllers.removeAt(index);
      _newFiles.removeAt(index);
      _newFileNames.removeAt(index);
      _newFileMimes.removeAt(index);
    });
  }

  void _removeExistingFile(int index) {
    setState(() {
      _existingFileRemoved[index] = true;
    });
  }


  Widget _buildExistingFilePreview(int index) {
    if (_existingFileRemoved[index]) {
      // If removed, show a placeholder or nothing
      return SizedBox();
    }

    final url = _existingFileUrls[index];
    final name = _existingFileNames[index];
    final mime = lookupMimeType(name);

    Widget preview;
    if (mime == null) {
      preview = Center(child: Text('N/A'));
    } else if (mime.startsWith('image/')) {
      preview = Image.network(url, fit: BoxFit.cover);
    } else if (mime.startsWith('video/')) {
      // For simplicity, just show a video icon with a play button, not full video player
      preview = Stack(
        children: [
          Container(
            color: Colors.black12,
            child: Center(
              child: Icon(Icons.videocam, size: 40, color: Colors.deepPurple),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Icon(Icons.play_circle_fill, color: Colors.deepPurple),
          ),
        ],
      );
    } else if (mime == 'application/pdf') {
      preview = Center(
          child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red));
    } else {
      preview = Center(child: Text('File'));
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepPurple),
          ),
          clipBehavior: Clip.hardEdge,
          child: preview,
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: () => _removeExistingFile(index),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewFilePreview(int index) {
    final file = _newFiles[index];
    final mime = _newFileMimes[index];
    final controller = _newVideoControllers[index];

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
      previewContent = Center(
          child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red));
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
            onTap: () => _removeNewFile(index),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePreviewGrid() {
    // Combine existing + new files, plus one "add" button tile
    final totalFilesCount =
        _existingFileUrls.whereIndexed((i, _) => !_existingFileRemoved[i]).length +
            _newFiles.length;
    final gridItemCount = totalFilesCount + 1;

    // We will build list of previews showing existing first, then new files

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: gridItemCount,
      itemBuilder: (context, index) {
        if (index == gridItemCount - 1) {
          // Last tile is add button
          return GestureDetector(
            onTap: _pickFiles,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepPurple),
                borderRadius: BorderRadius.circular(8),
                color: Colors.deepPurple.withOpacity(0.1),
              ),
              child: Center(
                  child: Icon(Icons.add, size: 40, color: Colors.deepPurple)),
            ),
          );
        }

        // Indexing logic:
        // Show existing files not removed first
        final existingNotRemovedIndexes = List<int>.generate(
            _existingFileUrls.length, (i) => i)
          ..removeWhere((i) => _existingFileRemoved[i]);
        if (index < existingNotRemovedIndexes.length) {
          final existingIndex = existingNotRemovedIndexes[index];
          return _buildExistingFilePreview(existingIndex);
        } else {
          // Then new files
          final newIndex = index - existingNotRemovedIndexes.length;
          return _buildNewFilePreview(newIndex);
        }
      },
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Upload new files to Firebase Storage
      final newFileUrls = await Future.wait(_newFiles.map((file) async {
        final fileName = _newFileNames[_newFiles.indexOf(file)] ?? 'file';
        final fileExt = fileName.split('.').last;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('notices/${DateTime.now().millisecondsSinceEpoch}.$fileExt');
        await storageRef.putFile(file);
        return await storageRef.getDownloadURL();
      }));

      // Prepare updated file lists: keep existing files that are not removed + newly uploaded URLs/names
      final updatedFileUrls = <String>[];
      final updatedFileNames = <String>[];

      for (int i = 0; i < _existingFileUrls.length; i++) {
        if (!_existingFileRemoved[i]) {
          updatedFileUrls.add(_existingFileUrls[i]);
          updatedFileNames.add(_existingFileNames[i]);
        }
      }
      updatedFileUrls.addAll(newFileUrls);
      updatedFileNames.addAll(_newFileNames.cast<String>());

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('notices')
          .doc(widget.noticeId)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'fileUrls': updatedFileUrls,
        'fileNames': updatedFileNames,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notice updated successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update notice: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Notice'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Enter title' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Enter description' : null,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final shouldDiscard = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Discard Changes?'),
                          content: Text('Are you sure you want to discard your changes?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false), // Cancel
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true), // Confirm discard
                              child: Text('Discard'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                            ),
                          ],
                        ),
                      );

                      if (shouldDiscard == true) {
                        Navigator.pop(context); // Close the screen
                      }
                    },
                    child: Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    child: Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// Helper extension for whereIndexed (since Dart doesn't have this natively)
extension IterableIndexed<E> on Iterable<E> {
  Iterable<E> whereIndexed(bool Function(int index, E element) test) sync* {
    int index = 0;
    for (final element in this) {
      if (test(index, element)) yield element;
      index++;
    }
  }
}
