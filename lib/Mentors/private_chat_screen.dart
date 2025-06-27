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
  final String studentId;
  final String studentName;
  final String mentorId;

  const PrivateChatScreen({
    Key? key,
    required this.studentId,
    required this.studentName,
    required this.mentorId,
  }) : super(key: key);

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _emojiShowing = false;
  final FocusNode _focusNode = FocusNode();
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _statusStream;
  List<QueryDocumentSnapshot> _allMessages = [];
  List<QueryDocumentSnapshot> _filteredMessages = [];
  bool _isSearching = false;
  String searchQuery = '';
  bool _isOnline = false;


  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _emojiShowing = false;
        });
      }
    });
    _statusStream = FirebaseFirestore.instance
        .collection('students')
        .doc(widget.studentId)
        .snapshots();

  }

  String get chatId {
    final ids = [widget.mentorId, widget.studentId]..sort();
    return ids.join('_');
  }

  CollectionReference get messageCollection => FirebaseFirestore.instance
      .collection('privateChats')
      .doc(chatId)
      .collection('messages');

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await messageCollection.add({
      'text': text,
      'senderId': widget.mentorId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  void _deleteMessage(String messageId) {
    messageCollection.doc(messageId).delete();
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('hh:mm a').format(timestamp.toDate());
  }


  Widget _buildFileMessage(Map<String, dynamic> msg) {
    final fileUrl = msg['fileUrl'];
    final fileName = msg['fileName'] ?? 'Attachment';
    final fileType = msg['fileType'] ?? '';

    if (fileType.startsWith('image/')) {
      // Show image preview
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
    } else if (fileType == 'application/pdf') {
      // PDF preview
      return GestureDetector(
        onTap: () => _openFile(fileUrl),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Fallback for other files
      return GestureDetector(
        onTap: () => _openFile(fileUrl),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.blue,
                ),
              ),
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

  void _handleMenuAction(String value) {
    switch (value) {
      case 'status':
        _showOnlineStatus();
        break;
      case 'search':
        _showSearchDialog();
        break;
      case 'clear':
        _confirmClearChat();
        break;
      case 'toggleOnline':
        _showToggleOnlineDialog();  // <-- add this line
        break;
    }
  }

  void _showOnlineStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Online Status"),
        content: const Text("Student is currently online."), // Replace with real logic if needed
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  void _showToggleOnlineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool tempOnline = _isOnline; // local state

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Online Status'),
              content: Row(
                children: [
                  const Text("Online"),
                  const Spacer(),
                  Switch(
                    value: tempOnline,
                    onChanged: (val) {
                      setState(() => tempOnline = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isOnline = tempOnline;
                    });
                    _updateOnlineStatus(tempOnline);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Search Chat"),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(hintText: "Enter keyword"),
          onSubmitted: (value) {
            Navigator.pop(context);
            _searchMessages(value);
          },
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isSearching = false;
                });
              },
              child: const Text("Reset")),
        ],

      ),
    );
  }

  void _searchMessages(String query) {
    setState(() {
      _isSearching = true;
      searchQuery = query;
      _filteredMessages = _allMessages.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final text = data['text']?.toString().toLowerCase() ?? '';
        return text.contains(query.toLowerCase());
      }).toList();
    });

    if (_filteredMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No results found")),
      );
    }
  }


  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat History"),
        content: const Text("Are you sure you want to delete all messages?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final batch = FirebaseFirestore.instance.batch();
              final snapshot = await messageCollection.get();
              for (var doc in snapshot.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              setState(() {
                _isSearching = false;
                _filteredMessages.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chat history cleared")),
              );
            },
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _updateOnlineStatus(bool isOnline) {
    final mentorId = FirebaseAuth.instance.currentUser!.uid;

    FirebaseFirestore.instance
        .collection('mentors')
        .doc(mentorId)
        .update({'isOnline': isOnline});
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffECE5DD),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: AppBar(
          backgroundColor: const Color(0xff075E54),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
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
                        Text(widget.studentName, style: const TextStyle(fontSize: 16, color: Colors.white)),
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
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'status',
                  child: Text('View Online Status'),
                ),
                const PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18),
                      SizedBox(width: 8),
                      Text("Search Chat"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear Chat History'),
                ),
                const PopupMenuItem(
                  value: 'toggleOnline',
                  child: Text('Set Online Status'),
                ),
              ],

            ),
          ],
        ),
      ),


      body: Column(
        children: [
          if (_isSearching)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.shade700),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing results for: "$searchQuery"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isSearching = false;
                      _filteredMessages.clear();
                      searchQuery = '';
                    }),
                    child: const Chip(
                      label: Text("Clear"),
                      backgroundColor: Colors.redAccent,
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messageCollection
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                _allMessages = messages;
                final displayMessages = _isSearching ? _filteredMessages : _allMessages;

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final doc = displayMessages[index];
                    final msg = doc.data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == widget.mentorId;

                    return GestureDetector(
                      onLongPress: isMe
                          ? () => _showDeleteDialog(doc.id)
                          : null,
                      child: Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          constraints: BoxConstraints(
                              maxWidth:
                              MediaQuery.of(context).size.width * 0.7),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xffDCF8C6)
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft:
                              const Radius.circular(12),
                              topRight:
                              const Radius.circular(12),
                              bottomLeft: Radius.circular(isMe ? 12 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (msg['fileUrl'] != null)
                                _buildFileMessage(msg),
                              if (msg['text'] != null && msg['text'].toString().isNotEmpty)
                                Text(
                                  msg['text'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                msg['timestamp'] != null
                                    ? _formatTimestamp(msg['timestamp'] as Timestamp)
                                    : 'Sending...',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
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


  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      final fileName = path.basename(pickedFile.path);

      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_uploads/$chatId/$fileName');

        final uploadTask = await ref.putFile(pickedFile);
        final downloadUrl = await ref.getDownloadURL();

        final mimeType = lookupMimeType(pickedFile.path) ?? 'application/octet-stream';


        await messageCollection.add({
          'fileUrl': downloadUrl,
          'fileName': fileName,
          'fileType': mimeType,
          'senderId': widget.mentorId,
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
                  FocusScope.of(context).unfocus(); // Hide keyboard
                  setState(() => _emojiShowing = !_emojiShowing);
                },
              ),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Type a message",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28 *
                      (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                  columns: 7,
                  backgroundColor: const Color(0xFFF2F2F2),
                ),
                categoryViewConfig: const CategoryViewConfig(
                  indicatorColor: Color(0xff075E54),
                ),
                bottomActionBarConfig: const BottomActionBarConfig(),
                skinToneConfig: const SkinToneConfig(),
                searchViewConfig: const SearchViewConfig(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: const Text("Do you want to delete this message?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
