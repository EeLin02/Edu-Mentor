import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  final _messageKeys = <String, GlobalKey>{};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  bool _emojiShowing = false;
  final FocusNode _focusNode = FocusNode();
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _statusStream;
  List<QueryDocumentSnapshot> _allMessages = [];
  List<QueryDocumentSnapshot> _filteredMessages = [];
  List<QueryDocumentSnapshot> _displayMessages = [];
  bool _isSearching = false;
  String searchQuery = '';
  bool _isOnline = false;
  bool _isMuted = false;
  Timestamp? _lastClearedAt;
  int _currentMatchIndex = 0;
  String? _highlightedMessageId;




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

    final uid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance
        .collection('privateChats')
        .doc(chatId)
        .collection('userStates')
        .doc(uid)
        .get()
        .then((doc) {
      setState(() {
        _lastClearedAt = doc.data()?['lastClearedAt'];
      });
    });

    _checkMuteStatus(chatId); //check mute on startup;

    _requestPermission();

  }

  String get chatId {
    final ids = [widget.mentorId, widget.studentId]..sort();
    return ids.join('_');
  }

  CollectionReference get messageCollection => FirebaseFirestore.instance
      .collection('privateChats')
      .doc(chatId)
      .collection('messages');

  Future<bool> _checkMuteStatus(String chatId) async {
    final doc = await FirebaseFirestore.instance
        .collection('privateChats')
        .doc(chatId)
        .get();

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final mutedBy = List<String>.from(data['mutedBy'] ?? []);
    return mutedBy.contains(FirebaseAuth.instance.currentUser!.uid);
  }



  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await messageCollection.add({
      'text': text,
      'senderId': widget.mentorId,
      'senderRole': "mentor",     //  mark role
      'mentorId': widget.mentorId,
      'studentId': widget.studentId,
      'timestamp': FieldValue.serverTimestamp(),
      'slaNotified': false,       // optional
      'status': 'sent',
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


void _requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> markStudentMessagesAsSeen() async {
    final mentorId = FirebaseAuth.instance.currentUser!.uid;

    final chatDocId = ([mentorId, widget.studentId]..sort()).join('_');

    final snapshot = await FirebaseFirestore.instance
        .collection('privateChats')
        .doc(chatDocId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.studentId) // student messages
        .where('status', isEqualTo: 'sent')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'seen'});
    }
    await batch.commit();


  }


  Future<void> deleteForMe(String chatId, String messageId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('privateChats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> deleteForEveryone(String chatId, String messageId, String senderId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid != senderId) {
      throw Exception("Only sender can delete for everyone");
    }

    await FirebaseFirestore.instance
        .collection('privateChats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedForEveryone': true,
    });
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
        _clearChatHistory();
        break;
      case 'toggleOnline':
        _showToggleOnlineDialog();
        break;
      case 'toggleMute':
        _toggleMuteNotifications(chatId);
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
            _searchMessages(value,_displayMessages);
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

  void _searchMessages(String query, List<QueryDocumentSnapshot> displayMessages) {
    setState(() {
      _isSearching = true;
      searchQuery = query;
      _filteredMessages = displayMessages.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final text = data['text']?.toString().toLowerCase() ?? '';
        return text.contains(query.toLowerCase());
      }).toList();
      _currentMatchIndex = 0; // reset when new search

    });

    _scrollToMatch();

    // 🔹 Auto-scroll to first match
    if (_filteredMessages.isNotEmpty) {
      final firstMatch = _filteredMessages.first;
      final matchIndex = _allMessages.indexOf(firstMatch);
      if (matchIndex != -1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            matchIndex * 80.0, // rough height per item
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    }
  }

  void _scrollToMatch() {
    if (_filteredMessages.isNotEmpty &&
        _currentMatchIndex >= 0 &&
        _currentMatchIndex < _filteredMessages.length) {
      final matchDoc = _filteredMessages[_currentMatchIndex];
      final matchId = matchDoc.id;

      setState(() => _highlightedMessageId = matchId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _messageKeys[matchId]?.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 400),
            alignment: 0.2,
            curve: Curves.easeInOut,
          );
        }

        // 4 秒后取消黄色高亮
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _highlightedMessageId == matchId) {
            setState(() => _highlightedMessageId = null);
          }
        });
      });
    }
  }




  Widget _buildHighlightedText(String text, String query, String msgId) {
    if (query.isEmpty) return Text(text);

    final matchesQuery = text.toLowerCase().contains(query.toLowerCase());
    final isHighlighted = msgId == _highlightedMessageId;

    if (!matchesQuery) return Text(text);

    // highlight if it's the active one
    return RichText(
      text: TextSpan(
        children: _highlightOccurrences(text, query, isHighlighted),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }

  List<TextSpan> _highlightOccurrences(String text, String query, bool isHighlighted) {
    final spans = <TextSpan>[];
    final regex = RegExp(RegExp.escape(query), caseSensitive: false);

    int start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: isHighlighted ? Colors.yellow : Colors.grey[300], // 👈 active vs inactive
        ),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }



  Future<void> _toggleMuteNotifications(String chatId) async {
    final docRef = FirebaseFirestore.instance.collection('privateChats').doc(chatId);
    final doc = await docRef.get();

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final mutedBy = List<String>.from(data['mutedBy'] ?? []);

    if (mutedBy.contains(userId)) {
      // Unmute
      await docRef.set({
        'mutedBy': FieldValue.arrayRemove([userId]),
      }, SetOptions(merge: true));
    } else {
      // Mute
      await docRef.set({
        'mutedBy': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true));
    }
  }




  Future<void> _clearChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat History"),
        content: const Text("This will clear the chat history only on your side. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear",style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );

    if (confirm != true) return; // user cancelled

    // Apply deletion marker (soft delete only for this user)
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
          backgroundColor: Colors.teal,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('students')
                      .doc(widget.studentId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final photoUrl = data?['profileUrl'];

                    return CircleAvatar(
                      radius: 18,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/student_icon.png') as ImageProvider,
                    );
                  },
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
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('privateChats')
                  .doc(chatId)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final mutedBy = List<String>.from(data['mutedBy'] ?? []);
                final isMuted = mutedBy.contains(FirebaseAuth.instance.currentUser!.uid);

                return IconButton(
                  icon: Icon(
                    isMuted ? Icons.notifications_off : Icons.notifications,
                    color: Colors.white,
                  ),
                  tooltip: isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                  onPressed: () => _toggleMuteNotifications(chatId),
                );
              },

            ),


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
                PopupMenuItem(
                  value: 'toggleMute',
                  child: Text(_isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
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
                      'Showing results for: "$searchQuery" '
                          '${_filteredMessages.isEmpty ? 0 : _currentMatchIndex + 1}/${_filteredMessages.length}',
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
                      if (_filteredMessages.isNotEmpty) {
                        setState(() {
                          _currentMatchIndex =
                              (_currentMatchIndex - 1 + _filteredMessages.length) %
                                  _filteredMessages.length;
                        });
                        _scrollToMatch();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    onPressed: () {
                      if (_filteredMessages.isNotEmpty) {
                        setState(() {
                          _currentMatchIndex =
                              (_currentMatchIndex + 1) % _filteredMessages.length;
                        });
                        _scrollToMatch();
                      }
                    },
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isSearching = false;
                      _filteredMessages.clear();
                      searchQuery = '';
                    }),
                    child: const Chip(
                      label: Text("Clear",
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.redAccent,
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

                final uid = FirebaseAuth.instance.currentUser!.uid;
                final messages = snapshot.data!.docs;

                _allMessages = messages;

                // 🔹 Mark messages as seen if current user is the student
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  markStudentMessagesAsSeen();
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && !_isSearching) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });



                // 🔹 Apply "delete for me" filter
                var filtered = messages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedBy = List<String>.from(data['deletedBy'] ?? []);
                  return !deletedBy.contains(uid);
                }).toList();

                // 🔹 Apply "clear history for me" filter
                _displayMessages = filtered.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  if (_lastClearedAt != null && ts != null) {
                    return ts.compareTo(_lastClearedAt!) > 0;
                  }
                  return true;
                }).toList();

                _messageKeys.clear(); // reset so stale keys don’t stick


                // 🔹 Now use displayMessages
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: _displayMessages.length,
                      itemBuilder: (context, index) {
                        final doc = _displayMessages[index];
                        final msg = doc.data() as Map<String, dynamic>;
                        final isMe = msg['senderId'] == widget.mentorId;



                        if (msg['deletedForEveryone'] == true) {
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "This message was deleted",
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54,
                                ),
                              ),
                            ),

                          );

                        }

                        final msgId = doc.id;
                        _messageKeys.putIfAbsent(msgId, () => GlobalKey());


                        return KeyedSubtree(
                          key: _messageKeys[msgId],
                          child: Container(
                            color: doc.id == _highlightedMessageId
                                ? Colors.yellow.shade200 // flash when highlighted
                                : null,
                            child: GestureDetector(
                              onLongPress: isMe ? () => _showDeleteDialog(doc.id, msg['senderId']) : null,
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
                                        _isSearching
                                            ? _buildHighlightedText(msg['text'], searchQuery, doc.id)
                                            : Text(
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
                                      if (isMe)
                                        Text(
                                          msg['status'] ?? 'sent',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
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
          'senderRole': "mentor",      // mark role
          'mentorId': widget.mentorId,
          'studentId': widget.studentId,
          'timestamp': FieldValue.serverTimestamp(),
          'slaNotified': false,
          'status': 'sent',   // optional
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
    _scrollController.dispose();
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

  void _showDeleteDialog(String messageId, String senderId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isSender = uid == senderId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: const Text("Do you want to delete this message?"),
        actions: [
          //Delete for me (always available)
          TextButton(
            onPressed: () async {
              await messageCollection.doc(messageId).update({
                "deletedBy": FieldValue.arrayUnion([uid])
              });
              Navigator.pop(context);
            },
            child: const Text("Delete for me"),
          ),
          //  Delete for everyone (only sender can do this)
          if (isSender)
            TextButton(
              onPressed: () async {
                await messageCollection.doc(messageId).update({
                  "deletedForEveryone": true,
                });
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
}
