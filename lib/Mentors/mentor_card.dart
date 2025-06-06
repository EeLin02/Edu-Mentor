import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MentorCard extends StatelessWidget {
  final String mentorId;

  const MentorCard({required this.mentorId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Mentor Card')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('mentors').doc(mentorId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Mentor data not found'));
          }

          var mentorData = snapshot.data!.data() as Map<String, dynamic>;
          String imageUrl = mentorData['fileUrl'] ?? '';

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black26),
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 3 / 4, // Adjust as needed
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  )
                      : Center(
                    child: Icon(
                      Icons.person,
                      size: 100,
                      color: Colors.grey[200],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
