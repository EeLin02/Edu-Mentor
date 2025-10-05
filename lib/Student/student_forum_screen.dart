import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumentor/Mentors/CreateForumPostScreen.dart';
import 'package:edumentor/shared_forum_post_card.dart';

class StudentForumScreen extends StatefulWidget {
  @override
  _StudentForumScreenState createState() => _StudentForumScreenState();
}

class _StudentForumScreenState extends State<StudentForumScreen> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Stream<QuerySnapshot> _forumStream({bool onlyMine = false}) {
    final base = FirebaseFirestore.instance
        .collection('forums')
        .orderBy('timestamp', descending: true);

    if (onlyMine) {
      return base.where('userId', isEqualTo: currentUser!.uid).snapshots();
    }

    return base.snapshots();
  }

  Widget _buildForumList(bool onlyMine) {
    return StreamBuilder<QuerySnapshot>(
      stream: _forumStream(onlyMine: onlyMine),
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
            final doc = docs[index];
            final isMyPost = doc['userId'] == currentUser!.uid;

            // Use FutureBuilder to fetch user info
            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance.collection('mentors').doc(doc['userId']).get(),
                FirebaseFirestore.instance.collection('students').doc(doc['userId']).get(),
              ]),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return Center(child: CircularProgressIndicator());

                final mentorDoc = userSnap.data![0];
                final studentDoc = userSnap.data![1];

                String userName = "Unknown";
                String userPhoto = "";
                String userIdNo = "";

                if (mentorDoc.exists) {
                  final data = mentorDoc.data() as Map<String, dynamic>;
                  userName = data['name'] ?? "Unknown";
                  userPhoto = data['profileUrl'] ?? "";
                  userIdNo = data['mentorIdNo'] ?? "";
                } else if (studentDoc.exists) {
                  final data = studentDoc.data() as Map<String, dynamic>;
                  userName = data['name'] ?? "Unknown";
                  userPhoto = data['profileUrl'] ?? "";
                  userIdNo = data['studentIdNo'] ?? "";
                }

                return ForumPostCard(
                  data: doc,
                  currentUser: currentUser,
                  themeColor: Colors.blue,
                  userName: userName,
                  userPhoto: userPhoto,
                  userIdNo: userIdNo,
                  showDelete: isMyPost,
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
        title: Text('Forums', style: TextStyle(color: Colors.blue)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'All Posts'),
            Tab(text: 'My Posts'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildForumList(false), // All posts
          _buildForumList(true),  // My posts only
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateForumPostScreen()),
          );
        },
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
