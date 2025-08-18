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
            return ForumPostCard(
              data: doc,
              currentUser: currentUser,
              themeColor: Colors.blue,
              showDelete:isMyPost, // show delete only on "My Posts"
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
