import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentCardScreen extends StatefulWidget {
  const StudentCardScreen({super.key});

  @override
  State<StudentCardScreen> createState() => _StudentCardScreenState();
}

class _StudentCardScreenState extends State<StudentCardScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String studentName = '';
  String studentEmail = '';
  String studentId = '';
  String profileUrl = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('students').doc(user.uid).get();
      final data = doc.data();

      if (data != null) {
        setState(() {
          studentName = data['name'] ?? '';
          studentEmail = user.email ?? '';
          studentId = data['studentIdNo'] ?? '';
          profileUrl = data['profileUrl'] ?? '';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Card'),
        backgroundColor: Colors.blue,
        elevation: 4,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: 350,
            height: 500,
            child: Card(
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
              shadowColor: Colors.blue.withOpacity(0.4),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40), // 👈 上下padding拉长比例
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: profileUrl.isNotEmpty
                          ? NetworkImage(profileUrl)
                          : const AssetImage("assets/images/student_icon.png")
                      as ImageProvider,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ID: $studentId',
                      style:
                      const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Email: $studentEmail',
                      style:
                      const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
