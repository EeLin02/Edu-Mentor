import 'package:flutter/material.dart';

class ClassChatScreen extends StatelessWidget {
  final String subjectName;
  final String className;

  const ClassChatScreen({
    Key? key,
    required this.subjectName,
    required this.className,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController _chatController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat · $subjectName - $className'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sample message
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("Hello class! Welcome to today's session."),
                  ),
                ),
              ],
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.teal),
                  onPressed: () {
                    // Add message logic
                    final msg = _chatController.text.trim();
                    if (msg.isNotEmpty) {
                      _chatController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Message sent")),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
