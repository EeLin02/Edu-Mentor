import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';

import 'settings_screen.dart';
import 'Student/student_subject_sections_details_screen.dart';
import 'Student/edit_student_profile_screen.dart';
import 'Student/student_card.dart';
import 'Student/student_notice_screen.dart';
import 'Student/student_forum_screen.dart';
import 'Student/student_notification_screen.dart';
import 'Student/student_enroll.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String studentName = '';
  String studentId = '';
  List<Map<String, dynamic>> enrolledSections = [];
  bool isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('students').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          studentName = data['name'] ?? 'Student';
          studentId = user.uid;
        });
        await _fetchEnrolledSections(user.uid);
      }
    }
  }

  Future<void> _fetchEnrolledSections(String studentId) async {
    if (studentId.isEmpty) return; // ✅ safeguard

    try {
      setState(() => isLoading = true);

      // 1. Load favorites (just for marking, not filtering)
      final favSnap = await _firestore
          .collection('studentFavorites')
          .doc(studentId)
          .get();

      final favIds = Set<String>.from(favSnap.data()?['favorites'] ?? []);

      // 2. Load all enrollments for this student
      final enrollmentSnap = await _firestore
          .collection('subjectEnrollments')
          .where('studentId', isEqualTo: studentId)
          .get();

      List<Map<String, dynamic>> tempList = [];

      for (var doc in enrollmentSnap.docs) {
        final data = doc.data();
        print("Enrollment data: $data");

        final schoolId = data['schoolId'];
        final programmeId = data['programmeId'];
        final subjectId = data['subjectId'];
        final sectionId = data['sectionId'];

        if (schoolId == null || programmeId == null || subjectId == null || sectionId == null) {
          print("⚠️ Skipping enrollment, missing IDs: $data");
          continue;
        }

        // Fetch subject
        final subjectDoc = await _firestore
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId)
            .get();

        if (!subjectDoc.exists) {
          print("⚠️ Skipping, subject not found: $subjectId");
          continue;
        }

        // Fetch section
        final sectionDoc = await _firestore
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId)
            .collection("sections")
            .doc(sectionId)
            .get();

        if (!sectionDoc.exists) {
          print("⚠️ Skipping, section not found: $sectionId");
          continue;
        }

        // Default color
        Color cardColor = Colors.blue;

        // Load customization
        final customizationDoc = await _firestore
            .collection('studentCustomizations')
            .doc('${studentId}_$sectionId')
            .get();

        if (customizationDoc.exists) {
          final colorData = customizationDoc.data()?['color'];
          cardColor = _parseColor(colorData);
        }

        final favKey = "${subjectId}_$sectionId";

        tempList.add({
          'subjectName': subjectDoc.data()?['name'] ?? 'Unknown Subject',
          'sectionName': sectionDoc.data()?['name'] ?? 'Unknown Section',
          'subjectId': subjectId,
          'sectionId': sectionId,
          'schoolId': schoolId,
          'programmeId': programmeId,
          'color': cardColor,
          'isFavorite': favIds.contains(favKey), // ✅ mark favorite
        });
      }

      setState(() {
        if (favIds.isEmpty) {
          // ⭐ shows all if no star
          enrolledSections = tempList;
        } else {
          // ⭐ just shows up star
          enrolledSections = tempList.where((e) => e['isFavorite']).toList();
        }
        isLoading = false;
      });

    } catch (e, st) {
      print("❌ Error loading enrolled sections: $e");
      print(st);
      setState(() {
        isLoading = false;
      });
    }
  }




  Future<void> _setCardColor(String sectionId, Color color) async {
    try {
      await _firestore
          .collection('studentCustomizations')
          .doc('${studentId}_$sectionId')
          .set({
        "studentId": studentId,
        "sectionId": sectionId,
        "color": color.value,
      });
      await _fetchEnrolledSections(studentId);
    } catch (e) {
      print("Error saving student color: $e");
    }
  }

  void _showColorPicker(String sectionId) {
    Color? selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Pick a card color"),
          content: MaterialColorPicker(
            selectedColor: selectedColor,
            onColorChange: (color) {
              selectedColor = color;
            },
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () {
                if (selectedColor != null) {
                  _setCardColor(sectionId, selectedColor!);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }

  void _logout() async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Color _parseColor(dynamic value) {
    try {
      if (value is int) return Color(value);
      if (value is String) return Color(int.parse(value));
    } catch (_) {}
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      _buildDashboardBody(),
      StudentForumScreen(),
      StudentNotificationScreen(),
      NoticeScreen(),
    ];

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Forums'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Notices'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDrawer() {
    if (studentId.isEmpty) {
      return const Drawer(child: Center(child: CircularProgressIndicator()));
    }
    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('students').doc(studentId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("No student data found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Student';
          final email = data['email'] ?? '';
          final profileUrl = data['profileUrl'] ?? '';

          ImageProvider<Object> avatarImage;
          if (profileUrl.isNotEmpty) {
            avatarImage = NetworkImage(profileUrl);
          } else {
            avatarImage = const AssetImage("assets/images/student_icon.png");
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                accountName: Text(name),
                accountEmail: Text(email),
                currentAccountPicture: CircleAvatar(
                  radius: 35,
                  backgroundImage: avatarImage,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: const Text('Profile'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentProfileScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.blue),
                title: const Text('Student Card'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentCardScreen(studentId: studentId)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.book, color: Colors.blue),
                title: const Text('Enroll in Subjects'),
                onTap: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StudentEnrollScreen(studentId: studentId)),
                  );

                  if (updated == true) {
                    // reload enrollments after coming back
                    await _fetchEnrolledSections(studentId);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.blue),
                title: const Text('Settings'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen()),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout'),
                onTap: _logout,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardBody() {
    return enrolledSections.isEmpty
        ? const Center(child: Text("No enrolled sections found."))
        : Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Courses",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllCoursesScreen(
                        studentId: studentId,
                        enrolledSections: enrolledSections,
                      ),
                    ),
                  );
                  // ✅ If AllCoursesScreen popped with true, reload dashboard data
                  if (updated == true) {
                    _fetchEnrolledSections(studentId);
                  }
                },
                child: const Text(
                  "All Courses",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: enrolledSections.length,
              itemBuilder: (context, index) {
                final item = enrolledSections[index];
                final cardColor = item['color'] ?? Colors.blue;

                final textColor = cardColor.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white;
                final subtitleColor = cardColor.computeLuminance() > 0.5
                    ? Colors.black54
                    : Colors.white70;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    title: Text(
                      item['subjectName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      item['sectionName'],
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.color_lens, color: Colors.white),
                      onPressed: () =>
                          _showColorPicker(item['sectionId']),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentSubjectSectionsDetailsScreen(
                            subjectId: item['subjectId'],
                            sectionId: item['sectionId'],
                            schoolId: item['schoolId'],
                            programmeId: item['programmeId'],
                            studentId: studentId,
                            color: cardColor,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AllCoursesScreen extends StatefulWidget {
  final String studentId;
  final List<Map<String, dynamic>> enrolledSections;

  const AllCoursesScreen({
    super.key,
    required this.studentId,
    required this.enrolledSections,
  });

  @override
  State<AllCoursesScreen> createState() => _AllCoursesScreenState();
}

class _AllCoursesScreenState extends State<AllCoursesScreen> {
  String searchQuery = '';
  Set<String> favoriteSectionIds = {};
  bool favoritesChanged = false; //  track changes


  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final snap = await FirebaseFirestore.instance
        .collection('studentFavorites')
        .doc(widget.studentId)
        .get();

    if (snap.exists) {
      final data = snap.data();
      setState(() {
        favoriteSectionIds =
        Set<String>.from(data?['favorites'] ?? []);
      });
    }
  }

  Future<void> _toggleFavorite(String subjectId, String sectionId) async {
    final favKey = "${subjectId}_$sectionId";

    setState(() {
      if (favoriteSectionIds.contains(favKey)) {
        favoriteSectionIds.remove(favKey);
      } else {
        favoriteSectionIds.add(favKey);
      }
      favoritesChanged = true;
    });

    await FirebaseFirestore.instance
        .collection('studentFavorites')
        .doc(widget.studentId)
        .set({
      'favorites': favoriteSectionIds.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, favoritesChanged); // ✅ Pass the result on return
        return false; // Prevent default pop to avoid triggering twice
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("All Courses"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, favoritesChanged); // ✅ Pass result when back button is clicked

            },
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search courses...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() => searchQuery = val);
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subjectEnrollments')
                    .where('studentId', isEqualTo: widget.studentId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No courses enrolled yet."));
                  }

                  final enrollments = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();

                  final filtered = enrollments.where((e) {
                    final name = (e['subjectName'] ?? '').toString().toLowerCase();
                    return name.contains(searchQuery.toLowerCase());
                  }).toList();

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final favKey = "${item['subjectId']}_${item['sectionId']}";
                      final isFav = favoriteSectionIds.contains(favKey);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(item['subjectName'] ?? 'Unknown Subject'),
                          subtitle: Text(item['sectionName'] ?? 'Unknown Section'),
                          trailing: IconButton(
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: isFav ? Colors.yellow[700] : Colors.grey,
                            ),
                            onPressed: () => _toggleFavorite(item['subjectId'], item['sectionId']),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentSubjectSectionsDetailsScreen(
                                  subjectId: item['subjectId'],
                                  sectionId: item['sectionId'],
                                  schoolId: item['schoolId'],
                                  programmeId: item['programmeId'],
                                  studentId: widget.studentId,
                                  color: Colors.blue,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

