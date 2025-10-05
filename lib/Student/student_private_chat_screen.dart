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
  final ScrollController _scrollController = ScrollController();
  final messageKeys = <String, GlobalKey>{}; // add at state level


  bool _emojiShowing = false;
  List<QueryDocumentSnapshot> _allMessages = [];
  bool _isSearching = false;
  bool _isMuted = false; // mute toggle
  bool _autoScroll = true;


  String searchQuery = '';
  late final String studentId;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _statusStream;

  @override
  void initState() {
    super.initState();
    _loadMuteStatus();
    studentId = FirebaseAuth.instance.currentUser!.uid;
    _createChatIfNotExists();
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


  Future<void> _createChatIfNotExists() async {
    final chatRef =
    FirebaseFirestore.instance.collection('privateChats').doc(chatId);

    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatRef.set({
        'mentorId': widget.mentorId,
        'studentId': studentId,
        'createdAt': FieldValue.serverTimestamp(),
        'mutedBy': [],
      });
    }
  }

  Future<void> _loadMuteStatus() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final muteRef = FirebaseFirestore.instance
        .collection('students')
        .doc(uid)
        .collection('mutedChats')
        .doc(chatId);
    final doc = await muteRef.get();
    setState(() {
      _isMuted = doc.exists;
    });
  }


  Future<void> deleteForMe(String messageId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await messageCollection.doc(messageId).update({
      "deletedBy": FieldValue.arrayUnion([uid])
    });
  }

  Future<void> deleteForEveryone(String messageId, String senderId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid != senderId) {
      throw Exception("Only sender can delete for everyone");
    }
    await messageCollection.doc(messageId).update({
      "deletedForEveryone": true,
    });
  }

  Future<void> _clearChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat History"),
        content: const Text("This will clear the chat history only on your side. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear",    style: const TextStyle(color: Colors.white), // make text white
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final snapshot = await messageCollection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        "deletedBy": FieldValue.arrayUnion([uid])
      });
    }
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Chat history cleared (only for you)")),
    );
  }

  void _showDeleteDialog(String messageId, String senderId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isSender = uid == senderId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: const Text("Do you want to delete this message?"),
        actions: [
          TextButton(
            onPressed: () async {
              await deleteForMe(messageId);
              Navigator.pop(context);
            },
            child: const Text("Delete for me"),
          ),
          if (isSender)
            TextButton(
              onPressed: () async {
                await deleteForEveryone(messageId, senderId);
                Navigator.pop(context);
              },
              child: const Text("Delete for everyone"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMuteNotifications() async {
    final chatRef =
    FirebaseFirestore.instance.collection('privateChats').doc(chatId);

    final doc = await chatRef.get();
    if (!doc.exists) return;

    final mutedBy = List<String>.from(doc['mutedBy'] ?? []);
    if (mutedBy.contains(studentId)) {
      await chatRef.update({
        'mutedBy': FieldValue.arrayRemove([studentId]),
      });
      debugPrint("Chat unmuted");
    } else {
      await chatRef.update({
        'mutedBy': FieldValue.arrayUnion([studentId]),
      });
      debugPrint("Chat muted");
    }
  }



  void _scrollToMessage(String messageId) {
    final key = messageKeys[messageId];
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1, // adjust where it appears on screen
        );
      }
    });
  }

  void _handleMenuAction(String value) async {
    switch (value) {
      case 'clear':
        await _clearChatHistory();
        break;

      case 'search':
        final selectedMessageId = await showSearch<String?>(
          context: context,
          delegate: ChatSearchDelegate(_allMessages, _scrollController),
        );

        if (selectedMessageId != null) {
          _scrollToMessage(selectedMessageId);
        }

        break;


      case 'toggleMute':
        await _toggleMuteNotifications();
        break;


      case 'toggleOnline':
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final userDoc = FirebaseFirestore.instance.collection('students').doc(uid);

        final snap = await userDoc.get();
        final currentStatus = snap.data()?['isOnline'] ?? false;
        await userDoc.update({'isOnline': !currentStatus});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!currentStatus ? "You are Online" : "You are Offline")),
        );
        break;

      case 'status':
        final otherUserId = widget.mentorId; // mentor
        final snap = await FirebaseFirestore.instance.collection('mentors').doc(otherUserId).get();
        final isOnline = snap.data()?['isOnline'] ?? false;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Mentor Status"),
            content: Text(isOnline ? "Mentor is Online" : "Mentor is Offline"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          ),
        );
        break;
    }
  }



  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xffECE5DD),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        titleSpacing: 0,
        title: Row(
          children: [

            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('mentors')
                  .doc(widget.mentorId)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final photoUrl = data?['profileUrl'];
                final isOnline = data?['isOnline'] ?? false;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/mentor_icon.png') as ImageProvider,
                    ),
                    const SizedBox(width: 8),
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
            )

          ],
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('privateChats')
                .doc(chatId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink(); // or a default mute icon
              }

              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final mutedBy = List<String>.from(data['mutedBy'] ?? []);
              final isMuted = mutedBy.contains(studentId);

              return IconButton(
                icon: Icon(
                  isMuted ? Icons.notifications_off : Icons.notifications,
                  color: Colors.white,
                ),
                tooltip: isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                onPressed: _toggleMuteNotifications,
              );
            },
          ),


          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
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
              PopupMenuItem(
                value: 'toggleMute',
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('privateChats')
                      .doc(chatId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Text('Mute Notifications'); // default text
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final mutedBy = List<String>.from(data['mutedBy'] ?? []);
                    final isMuted = mutedBy.contains(studentId);

                    return Text(isMuted ? 'Unmute Notifications' : 'Mute Notifications');
                  },
                ),
              ),
            ],
          ),
        ],
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

                // 🔹 Student should only mark mentor’s "sent" messages as seen
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  markMessagesAsSeen();
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && _autoScroll) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });


                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final msg = doc.data()! as Map<String, dynamic>;
                    final isMe = msg['senderId'] == studentId;

                    final deletedBy = (msg['deletedBy'] ?? []) as List;
                    final uid = FirebaseAuth.instance.currentUser!.uid;

                    // Skip messages deleted by current user
                    if (deletedBy.contains(uid)) {
                      return const SizedBox.shrink();
                    }

                    // Handle deleted-for-everyone
                    if (msg['deletedForEveryone'] == true) {
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "This message was deleted",
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                          ),
                        ),
                      );
                    }
                    final key = messageKeys.putIfAbsent(doc.id, () => GlobalKey());

                    return GestureDetector(
                      key: key,  // attach the key here
                      onLongPress: () => _showDeleteDialog(doc.id, msg['senderId']),
                      child: Align(
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
                                    ? DateFormat('hh:mm a').format((msg['timestamp'] as Timestamp).toDate())
                                    : 'Sending...',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              if (isMe)
                                Text(
                                  msg['status'] ?? 'sent',
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


  Future<void> markMessagesAsSeen() async {
    final studentId = FirebaseAuth.instance.currentUser!.uid;

    final chatId = [studentId, widget.mentorId]..sort();
    final chatDocId = chatId.join('_');

    final snapshot = await FirebaseFirestore.instance
        .collection('privateChats')
        .doc(chatDocId)   // now it's a String ✅
        .collection('messages')
        .where('senderId', isEqualTo: widget.mentorId)
        .where('status', isEqualTo: 'sent')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'seen'});
    }
    await batch.commit();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await messageCollection.add({
      'text': text,
      'senderId': studentId,
      'senderRole': "student",
      'mentorId': widget.mentorId,
      'studentId': studentId,
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'slaNotified': false,
    });

    _messageController.clear();

    // auto scroll after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
          'senderRole': "student",
          'mentorId': widget.mentorId,
          'studentId': studentId,
          'status': 'sent',          // 🔹 add this
          'timestamp': FieldValue.serverTimestamp(),
          'slaNotified': false,
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

class ChatSearchDelegate extends SearchDelegate<String?> {
  final List<QueryDocumentSnapshot> messages;
  final ScrollController scrollController;
  int _currentMatchIndex = 0;

  ChatSearchDelegate(this.messages, this.scrollController);

  // 🔹 Required: clear (X) button
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        )
    ];
  }

  // 🔹 Required: back button
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  // Highlight text helper
  Widget buildHighlightText(String text, String query) {
    if (query.isEmpty) return Text(text);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0, index;

    while ((index = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: spans,
      ),
    );
  }

  void _scrollToMatch(List<QueryDocumentSnapshot> results) {
    if (results.isEmpty) return;

    final matchDoc = results[_currentMatchIndex];
    final key = (scrollController.position.context.storageContext as Element)
        .findAncestorStateOfType<_PrivateChatScreenState>()!
        .messageKeys[matchDoc.id];

    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }


  @override
  Widget buildResults(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final results = messages.where((msg) {
      final data = msg.data() as Map<String, dynamic>;
      final text = data['text'] ?? '';
      final deletedBy = List.from(data['deletedBy'] ?? []);

      // Only show if current user has NOT cleared it and matches search
      return !deletedBy.contains(uid) &&
          text.toString().toLowerCase().contains(query.toLowerCase());
    }).toList();


    if (results.isEmpty) {
      return const Center(child: Text("No matching messages found"));
    }

    return Column(
      children: [
        // 🔹 Banner with navigation
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
                  'Results for "$query" '
                      '(${_currentMatchIndex + 1}/${results.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: () {
                  if (results.isNotEmpty) {
                    _currentMatchIndex =
                        (_currentMatchIndex - 1 + results.length) % results.length;
                    _scrollToMatch(results);
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: () {
                  if (results.isNotEmpty) {
                    _currentMatchIndex =
                        (_currentMatchIndex + 1) % results.length;
                    _scrollToMatch(results);
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
            ],
          ),
        ),

        // 🔹 Results list
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) {
              final doc = results[i];
              final data = doc.data() as Map<String, dynamic>;
              final text = data['text'] ?? '';

              return Container(
                color: i == _currentMatchIndex ? Colors.grey.shade300 : null,
                child: ListTile(
                  title: buildHighlightText(text, query),
                  subtitle: Text(
                    data['timestamp'] != null
                        ? DateFormat('MMM d, hh:mm a').format((data['timestamp'] as Timestamp).toDate())
                        : '',
                  ),
                  onTap: () {
                    // Close search and return the message id
                    close(context, doc.id);
                  },
                )
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

