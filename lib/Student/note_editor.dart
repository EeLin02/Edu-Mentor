import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NoteEditor extends StatefulWidget {
  final String resourceId;
  final Color? color;

  const NoteEditor({super.key, required this.resourceId, this.color});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _noteController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  String? _noteId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingNote();
  }

  Future<void> _loadExistingNote() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('savedResources')
        .doc(widget.resourceId)
        .collection('notes')
        .where('userId', isEqualTo: currentUser?.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      _noteController.text = doc['content'] ?? '';
      _noteId = doc.id;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;

    try {
      if (_noteId != null) {
        // Update existing note
        await FirebaseFirestore.instance
            .collection('savedResources')
            .doc(widget.resourceId)
            .collection('notes')
            .doc(_noteId)
            .update({
          'content': content,
          'timestamp': Timestamp.now(),
        });
      } else {
        // Create new note
        final docRef = await FirebaseFirestore.instance
            .collection('savedResources')
            .doc(widget.resourceId)
            .collection('notes')
            .add({
          'userId': currentUser?.uid,
          'content': content,
          'timestamp': Timestamp.now(),
        });
        _noteId = docRef.id;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving note: $e')),
      );
    }
  }

  Future<void> _deleteNote() async {
    if (_noteId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('savedResources')
            .doc(widget.resourceId)
            .collection('notes')
            .doc(_noteId)
            .delete();

        setState(() {
          _noteController.clear();
          _noteId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Colors.deepPurple;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: themeColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'My Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: themeColor.withOpacity(0.95),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Write your thoughts here...',
                filled: true,
                fillColor: themeColor.withOpacity(0.08),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeColor, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                  BorderSide(color: themeColor.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_noteId != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteNote,
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Save Note',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: _saveNote,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
