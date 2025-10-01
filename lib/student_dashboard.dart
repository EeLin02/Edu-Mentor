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
          'subjectCode': subjectDoc.data()?['code'] ?? '',
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
        // Always show all enrolled sections
        enrolledSections = tempList.map((e) {
          final favKey = "${e['subjectId']}_${e['sectionId']}";
          return {
            ...e,
            'isFavorite': favIds.contains(favKey), // mark favorite only
          };
        }).toList();

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

      // Update local data directly
      setState(() {
        final index = enrolledSections.indexWhere((e) => e['sectionId'] == sectionId);
        if (index != -1) {
          enrolledSections[index]['color'] = color;
        }
      });

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
    if (studentId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("subjectEnrollments")
          .where("studentId", isEqualTo: studentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No enrolled sections found."));
        }

        // 🔹 Step 1: wrap extra fetches into Future.wait
        final fetchData = Future.wait(snapshot.data!.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final subjectId = data['subjectId'];
          final sectionId = data['sectionId'];
          final schoolId = data['schoolId'];
          final programmeId = data['programmeId'];

          // fetch subject
          final subjectDoc = await _firestore
              .collection("schools")
              .doc(schoolId)
              .collection("programmes")
              .doc(programmeId)
              .collection("subjects")
              .doc(subjectId)
              .get();

          // fetch section
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

          // 🔹 fetch customization
          final customizationDoc = await _firestore
              .collection('studentCustomizations')
              .doc('${studentId}_$sectionId')
              .get();
          Color cardColor = Colors.blue;
          if (customizationDoc.exists) {
            final colorData = customizationDoc.data()?['color'];
            cardColor = _parseColor(colorData);
          }

          return {
            "subjectId": subjectId,
            "subjectName": subjectDoc.data()?["name"] ?? "Unknown Subject",
            "subjectCode": subjectDoc.data()?["code"] ?? "",
            "sectionId": sectionId,
            "sectionName": sectionDoc.data()?["name"] ?? "Unknown Section",
            "schoolId": schoolId,
            "programmeId": programmeId,
            "color": cardColor,
          };
        }).toList());

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchData,
          builder: (context, enrolledSnapshot) {
            if (!enrolledSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final sections = enrolledSnapshot.data!;

            // 🔹 Step 2: Load favorites in parallel
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection("studentFavorites")
                  .doc(studentId)
                  .get(),
              builder: (context, favSnap) {
                if (!favSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final favData = favSnap.data?.data() as Map<String, dynamic>?;
                final favIds = Set<String>.from(favData?['favorites'] ?? []);


                // Merge favorites into sections
                final mergedSections = sections.map((e) {
                  final favKey = "${e['subjectId']}_${e['sectionId']}";
                  return {
                    ...e,
                    "isFavorite": favIds.contains(favKey),
                  };
                }).toList();

                final starred =
                mergedSections.where((e) => e['isFavorite'] == true).toList();
                final displayList =
                starred.isNotEmpty ? starred : mergedSections;

                return Padding(
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
                                    enrolledSections: mergedSections,
                                  ),
                                ),
                              );
                              if (updated == true) {
                                setState(() {}); // refresh
                              }
                            },
                            child: const Text(
                              "All Courses",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: ListView.builder(
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final item = displayList[index];
                            final cardColor = item['color'] as Color;
                            final textColor =
                            cardColor.computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white;
                            final subtitleColor =
                            cardColor.computeLuminance() > 0.5
                                ? Colors.black54
                                : Colors.white70;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                title: Text(
                                  item['subjectName'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(
                                  "${item['subjectCode']} . ${item['sectionName']}",
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 15,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.color_lens, color: Colors.white),
                                  onPressed: () => _showColorPicker(item['sectionId']),
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
              },
            );
          },
        );
      },
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
  bool favoritesChanged = false;
  List<Map<String, dynamic>> allCourses = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadAllCourses();
  }

  Future<void> _loadFavorites() async {
    final snap = await FirebaseFirestore.instance
        .collection('studentFavorites')
        .doc(widget.studentId)
        .get();

    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>?;
      setState(() {
        favoriteSectionIds = Set<String>.from(data?['favorites'] ?? []);
      });
    }
  }

  Future<void> _loadAllCourses() async {
    try {
      // --- Load customizations (same as dashboard) ---
      final customizationsSnap = await FirebaseFirestore.instance
          .collection("studentCustomizations")
          .where("studentId", isEqualTo: widget.studentId)
          .get();

      final Map<String, Map<String, dynamic>> customizations = {};
      for (var doc in customizationsSnap.docs) {
        final data = doc.data();
        final sectionId = data['sectionId'];
        if (sectionId != null) {
          customizations[sectionId.toString()] = data;
        }
      }
      // --- Load subjectEnrollments ---
      final enrollmentSnap = await FirebaseFirestore.instance
          .collection('subjectEnrollments')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      List<Map<String, dynamic>> tempList = [];

      for (var doc in enrollmentSnap.docs) {
        final data = doc.data();

        final schoolId = data['schoolId'];
        final programmeId = data['programmeId'];
        final subjectId = data['subjectId'];
        final sectionId = data['sectionId'];

        if ([schoolId, programmeId, subjectId, sectionId].contains(null)) {
          continue;
        }

        // get subject
        final subjectDoc = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId)
            .get();

        if (!subjectDoc.exists) continue;

        // get section
        final sectionDoc = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId)
            .collection("sections")
            .doc(sectionId)
            .get();

        if (!sectionDoc.exists) continue;

        // --- Apply customization ---
        final customization = customizations[sectionId];
        final storedColor = customization?['color'];

        Color cardColor = Colors.blue.shade400;
        if (storedColor != null) {
          try {
            if (storedColor is String && storedColor.startsWith('#')) {
              cardColor =
                  Color(int.parse(storedColor.replaceFirst('#', '0xff')));
            } else {
              cardColor = Color(int.parse(storedColor.toString()));
            }
          } catch (e) {
            print("⚠️ Failed to parse color: $storedColor → $e");
          }
        }

        tempList.add({
          'subjectId': subjectId,
          'sectionId': sectionId,
          'schoolId': schoolId,
          'programmeId': programmeId,
          'subjectName': subjectDoc.data()?['name'] ?? 'Unknown Subject',
          'subjectCode': subjectDoc.data()?['code'] ?? '',
          'sectionName': sectionDoc.data()?['name'] ?? 'Unknown Section',
          'color': cardColor, // default
        });


      }

      setState(() {
        allCourses = tempList;
        loading = false;
      });
    } catch (e) {
      print("❌ Error loading all courses: $e");
      setState(() => loading = false);
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
    // Always show all courses in AllCoursesScreen
    final filtered = allCourses.where((e) {
      final name = (e['subjectName'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();


    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, favoritesChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("All Courses"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, favoritesChanged);
            },
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
              child: filtered.isEmpty
                  ? const Center(child: Text("No courses found."))
                  : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final favKey =
                      "${item['subjectId']}_${item['sectionId']}";
                  final isFav =
                  favoriteSectionIds.contains(favKey);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: item['color'], // ✅ card background
                    elevation: 4,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),

                      // 🔹 Dynamic text colors like dashboard
                      title: Text(
                        item['subjectName'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: (item['color'] as Color).computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        "${item['subjectCode']} . ${item['sectionName']}",
                        style: TextStyle(
                          fontSize: 15,
                          color: (item['color'] as Color).computeLuminance() > 0.5
                              ? Colors.black54
                              : Colors.white70,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          favoriteSectionIds.contains("${item['subjectId']}_${item['sectionId']}")
                              ? Icons.star
                              : Icons.star_border,
                          color: favoriteSectionIds.contains("${item['subjectId']}_${item['sectionId']}")
                              ? Colors.yellow[700]
                              : ((item['color'] as Color).computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white70),
                        ),
                        onPressed: () =>
                            _toggleFavorite(item['subjectId'], item['sectionId']),
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
                              color: item['color'], // keep passing color
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
      ),
    );
  }
}


