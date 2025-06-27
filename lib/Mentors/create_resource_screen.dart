import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class CreateResourceScreen extends StatefulWidget {
  final String subjectName;
  final String className;
  final String? resourceId;
  final String? title;
  final String? category;
  final List<String>? links;
  final Color? color;
  final String? description;

  const CreateResourceScreen({
    Key? key,
    required this.subjectName,
    required this.className,
    this.resourceId,
    this.title,
    this.category,
    this.links,
    this.color,
    this.description,
  }) : super(key: key);

  @override
  State<CreateResourceScreen> createState() => _CreateResourceScreenState();
}

class _CreateResourceScreenState extends State<CreateResourceScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _linkInputController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();


  List<String> _externalLinks = [];
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  List<String> _uploadedFileUrls = [];



  String? _selectedCategory;
  List<String> _allCategories = [];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.title ?? '';
    _externalLinks = widget.links ?? [];
    _selectedCategory = widget.category;
    _descriptionController.text = widget.description ?? '';

    _loadCategories();
    _fetchCategories(); // optional: ensure _allCategories is loaded
    if (widget.resourceId != null) {
      _loadResourceData(); // Load resource info for editing
    }
  }

  Future<void> _loadResourceData() async {
    final doc = await FirebaseFirestore.instance
        .collection('resources')
        .doc(widget.resourceId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';

        final links = List<String>.from(data['links'] ?? []);
        // Assuming uploaded file URLs contain 'firebaseapp.com' or something unique, you can adjust this logic:
        _uploadedFileUrls = links.where((link) => link.startsWith('http')).toList();

        // If you want to separate external links (like website URLs) you could refine this further
        _externalLinks = [];  // clear and fill with external links if needed, or
        // For now, to keep simple, treat all as uploaded files or external links as is:
        // For example, treat links that don't start with http as external (or any other logic)
        // _externalLinks = links.where((link) => !link.startsWith('http')).toList();

        _selectedCategory = data['category'];
      });
    }
  }



  Future<void> _fetchCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('resource_categories')
        .doc('${widget.className}_${widget.subjectName}')
        .get();

    if (snapshot.exists) {
      final data = snapshot.data();
      final List<String> categories = List<String>.from(data?['categories'] ?? []);
      setState(() {
        _allCategories = categories;
      });
    }
  }



  void _loadCategories() async {
    final doc = await FirebaseFirestore.instance
        .collection('resource_categories')
        .doc('${widget.className}_${widget.subjectName}')
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['categories'] is List) {
        setState(() {
          _allCategories = List<String>.from(data['categories']);
        });
      }
    }
  }

  void _editCategory(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Category"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "New category name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text("Save"),
          )
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final docRef = FirebaseFirestore.instance
          .collection('resource_categories')
          .doc('${widget.className}_${widget.subjectName}');

      await docRef.update({
        'categories': FieldValue.arrayRemove([oldName])
      });
      await docRef.update({
        'categories': FieldValue.arrayUnion([newName])
      });

      setState(() {
        _allCategories.remove(oldName);
        _allCategories.add(newName);
        if (_selectedCategory == oldName) _selectedCategory = newName;
      });
    }
  }

  void _deleteCategory(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete Category"),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete"),
          )
        ],
      ),
    );

    if (confirm == true) {
      final docRef = FirebaseFirestore.instance
          .collection('resource_categories')
          .doc('${widget.className}_${widget.subjectName}');

      await docRef.update({
        'categories': FieldValue.arrayRemove([name])
      });

      setState(() {
        _allCategories.remove(name);
        if (_selectedCategory == name) _selectedCategory = null;
      });
    }
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

  Future<void> _uploadAndSaveResource() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? 'unknown_user';
    final title = _titleController.text.trim();
    final category = _selectedCategory?.trim() ?? 'Uncategorized';

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Title is required.")),
      );
      return;
    }

    setState(() => _isUploading = true);
    List<String> fileUrls = [];

    try {
      for (var file in _selectedFiles) {
        final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path!)}';
        final ref = FirebaseStorage.instance.ref(
          'resources/${widget.subjectName}_${widget.className}/$uniqueFileName',
        );
        final uploadTask = await ref.putFile(File(file.path!));
        final url = await uploadTask.ref.getDownloadURL();
        fileUrls.add(url);
      }

      final data = {
        'subjectName': widget.subjectName,
        'className': widget.className,
        'title': title,
        'description': _descriptionController.text.trim(),
        'category': category,
        'links': [..._uploadedFileUrls, ...fileUrls, ..._externalLinks],  // merge all links
        'timestamp': FieldValue.serverTimestamp(),
        'mentorsId': uid,
      };

      if (widget.resourceId != null) {
        await FirebaseFirestore.instance
            .collection('resources')
            .doc(widget.resourceId)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Resource updated.")),
        );
      } else {
        await FirebaseFirestore.instance.collection('resources').add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Resource created.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading resource: $e")),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }


  void _handleAddCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: Text("New Category"),
            content: TextField(
              controller: _newCategoryController,
              decoration: InputDecoration(hintText: "Enter category name"),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _newCategoryController.text.trim());
                  _newCategoryController.clear();
                },
                child: Text("Add"),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      final categoryRef = FirebaseFirestore.instance
          .collection('resource_categories')
          .doc('${widget.className}_${widget.subjectName}');

      await categoryRef.set({
        'categories': FieldValue.arrayUnion([result])
      }, SetOptions(merge: true));

      setState(() {
        _allCategories.add(result);
        _selectedCategory = result;
      });
    }
  }

  void _showCategoryOptions(String category) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editCategory(category);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteCategory(category);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel),
              title: Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }


  void _addExternalLink() {
    final link = _linkInputController.text.trim();
    if (link.isNotEmpty && !_externalLinks.contains(link)) {
      setState(() {
        _externalLinks.add(link);
        _linkInputController.clear();
      });
    }
  }


  Widget _buildCard({required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.indigo;
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.resourceId != null ? 'Edit Resource' : 'New Resource'),
        backgroundColor: color,
        foregroundColor: textColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCard(
              children: [
                _buildLabel('Title'),
                _buildTextField(_titleController, 'Enter title', Icons.title),
                const SizedBox(height: 16),
                _buildLabel('Description'),
                _buildTextField(_descriptionController, 'Enter description',
                    Icons.description, maxLines: 3),
              ],
            ),

            _buildCard(
              children: [
                _buildLabel('Categories'),
                Wrap(
                  spacing: 8,
                  children: _allCategories.map((cat) {
                    return InputChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      selectedColor: Colors.indigo.shade100,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      deleteIcon: Icon(Icons.edit),
                      onDeleted: () => _showCategoryOptions(cat),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _handleAddCategory,
                    icon: Icon(Icons.add),
                    label: Text("Add Category"),
                  ),
                )
              ],
            ),


            _buildCard(
              children: [
                _buildLabel('External Links'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _linkInputController,
                        decoration: InputDecoration(
                          labelText: 'Add link',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(borderRadius: BorderRadius
                              .circular(12)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: _addExternalLink,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _externalLinks.map((link) =>
                      Chip(
                        label: Text(link, overflow: TextOverflow.ellipsis),
                        deleteIcon: Icon(Icons.close),
                        onDeleted: () =>
                            setState(() =>
                                _externalLinks.remove(link)),
                      )).toList(),
                ),
              ],
            ),

            _buildCard(
              children: [
                _buildLabel('Attachments'),
                const SizedBox(height: 8),

                // Upload Buttons Row
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

                const SizedBox(height: 12),

                // Selected Files Display with Delete Support
                if (_selectedFiles.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedFiles.map((f) => Chip(
                      label: Text(f.name, overflow: TextOverflow.ellipsis),
                      deleteIcon: Icon(Icons.close),
                      onDeleted: () {
                        setState(() => _selectedFiles.remove(f));
                      },
                    )).toList(),
                  ),

                if (_uploadedFileUrls.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _uploadedFileUrls.map((url) => Chip(
                      label: Text(
                        url.split('/').last, // show file name from URL (or parse better if you want)
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: Icon(Icons.close),
                      onDeleted: () {
                        setState(() {
                          _uploadedFileUrls.remove(url);
                        });
                      },
                    )).toList(),
                  ),

              ],
            ),


            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadAndSaveResource,
                icon: _isUploading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : Icon(Icons.save),
                label: Text(_isUploading  ? (widget.resourceId != null ? "Updating..." : "Posting...")
                    : (widget.resourceId != null ? "Update Resources" : "Add Resource"),),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: color,
                  foregroundColor: textColor,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
