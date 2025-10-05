import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'createForumPostScreen.dart';
import 'package:edumentor/shared_forum_post_card.dart';

class MentorForumScreen extends StatefulWidget {
  @override
  _MentorForumScreenState createState() => _MentorForumScreenState();
}

class _MentorForumScreenState extends State<MentorForumScreen> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Stream<QuerySnapshot> getForumStream(bool onlyMine) {
    final collection = FirebaseFirestore.instance.collection('forums');
    final query = onlyMine
        ? collection.where('userId', isEqualTo: currentUser!.uid)
        : collection;
    return query.orderBy('timestamp', descending: true).snapshots();
  }

  Widget buildPostList(bool onlyMine) {
    return StreamBuilder<QuerySnapshot>(
      stream: getForumStream(onlyMine),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(onlyMine ? 'You have not posted anything yet.' : 'No forum posts yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index];
            final isMyPost = post['userId'] == currentUser!.uid;
            final userId = post['userId'];

            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance.collection('mentors').doc(userId).get(),
                FirebaseFirestore.instance.collection('students').doc(userId).get(),
              ]),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return Center(child: CircularProgressIndicator());

                final mentorDoc = userSnap.data![0];
                final studentDoc = userSnap.data![1];

                String userName = "Unknown";
                String userPhoto = "";
                String userIdNo = "";
                String role = "unknown";

                if (mentorDoc.exists) {
                  final data = mentorDoc.data() as Map<String, dynamic>;
                  userName = data['name'] ?? "Unknown";
                  userPhoto = data['profileUrl'] ?? "";
                  userIdNo = data['mentorIdNo'] ?? "";
                  role = "mentor";
                } else if (studentDoc.exists) {
                  final data = studentDoc.data() as Map<String, dynamic>;
                  userName = data['name'] ?? "Unknown";
                  userPhoto = data['profileUrl'] ?? "";
                  userIdNo = data['studentIdNo'] ?? "";
                  role = "student";
                }

                return ForumPostCard(
                  data: post,
                  currentUser: currentUser,
                  themeColor: Colors.teal,
                  showDelete: isMyPost,
                  userName: userName,
                  userPhoto: userPhoto,
                  userIdNo: userIdNo,
                );
              },
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mentor Forums', style: TextStyle(color: Colors.teal)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'All Posts'),
            Tab(text: 'My Posts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildPostList(false), // All Posts
          buildPostList(true),  // My Posts
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateForumPostScreen()),
          );
        },
        backgroundColor: Colors.teal,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
