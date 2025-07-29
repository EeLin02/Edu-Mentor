import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:mime/mime.dart';


class PrivateChatScreen extends StatefulWidget {
  final String mentorId;
  final String mentorName;

  const PrivateChatScreen({
    super.key,
    required this.mentorId,
    required this.mentorName,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _emojiShowing = false;
  List<QueryDocumentSnapshot> _allMessages = [];
  bool _isSearching = false;
  String searchQuery = '';
  late final String studentId;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _statusStream;

  @override
  void initState() {
    super.initState();
    studentId = FirebaseAuth.instance.currentUser!.uid;
    _statusStream = FirebaseFirestore.instance
        .collection('mentors')
        .doc(widget.mentorId)
        .snapshots();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _emojiShowing = false;
        });
      }
    });
  }

  String get chatId {
    final ids = [widget.mentorId, studentId]..sort();
    return ids.join('_');
  }

  CollectionReference get messageCollection =>
      FirebaseFirestore.instance.collection('privateChats').doc(chatId).collection('messages');

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await messageCollection.add({
      'text': text,
      'senderId': studentId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xff075E54),
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage('assets/avatar.png'),
              radius: 18,
            ),
            const SizedBox(width: 8),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _statusStream,
              builder: (context, snapshot) {
                final isOnline = snapshot.data?.data()?['isOnline'] ?? false;
                return Row(
                  children: [
                    Text(widget.mentorName,
                        style: const TextStyle(fontSize: 16, color: Colors.white)),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 5,
                      backgroundColor: isOnline ? Colors.green : Colors.grey,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messageCollection.orderBy('timestamp', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                _allMessages = messages;

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final msg = doc.data()! as Map<String, dynamic>;
                    final isMe = msg['senderId'] == studentId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xffDCF8C6) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (msg['fileUrl'] != null) _buildFileMessage(msg),
                            if (msg['text'] != null && msg['text'].toString().isNotEmpty)
                              Text(msg['text'], style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              msg['timestamp'] != null
                                  ? DateFormat('hh:mm a').format(
                                  (msg['timestamp'] as Timestamp).toDate())
                                  : 'Sending...',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions, color: Colors.grey),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _emojiShowing = !_emojiShowing);
                },
              ),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Type a message",
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    fillColor: const Color(0xffF0F0F0),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.grey),
                onPressed: _pickAndUploadFile,
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xff075E54)),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
        Offstage(
          offstage: !_emojiShowing,
          child: SizedBox(
            height: 250,
            child: EmojiPicker(
              textEditingController: _messageController,
              config: Config(
                height: 250,
                emojiViewConfig: const EmojiViewConfig(),
                categoryViewConfig: const CategoryViewConfig(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> msg) {
    final fileUrl = msg['fileUrl'];
    final fileName = msg['fileName'] ?? 'Attachment';
    final fileType = msg['fileType'] ?? '';

    if (fileType.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fileUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text("Failed to load image"),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _openFile(fileUrl),
        child: Row(
          children: [
            Icon(fileType == 'application/pdf'
                ? Icons.picture_as_pdf
                : Icons.insert_drive_file, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(fileName,
                  style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.blue)),
            ),
          ],
        ),
      );
    }
  }

  void _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      final fileName = path.basename(pickedFile.path);

      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_uploads/$chatId/$fileName');
        await ref.putFile(pickedFile);
        final downloadUrl = await ref.getDownloadURL();
        final mimeType = lookupMimeType(pickedFile.path) ?? 'application/octet-stream';

        await messageCollection.add({
          'fileUrl': downloadUrl,
          'fileName': fileName,
          'fileType': mimeType,
          'senderId': studentId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("File upload error: $e");
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

