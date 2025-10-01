import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';

import 'settings_screen.dart';
import 'Mentors/subject_class_details_screen.dart';
import 'Mentors/edit_mentor_profile_screen.dart';
import 'Mentors/mentor_card.dart';
import 'Mentors/forums_screen.dart';
import 'Mentors/notice_screen.dart';

class MentorDashboard extends StatefulWidget {
  @override
  _MentorDashboardState createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  Map<String, List<Map<String, dynamic>>> programmesData = {};
  Set<String> favoriteIds = {}; // store mentor’s favorites
  String? mentorId;
  bool isLoading = true;
  bool _isDarkMode = false;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeMentor();
    _loadTheme();
  }

  Future<Map<String, dynamic>?> _fetchMentorProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('mentors').doc(user.uid).get();
    return doc.data();
  }

  final List<Widget> _screens = [
    MentorDashboard(),
    MentorForumScreen(),
    NoticeScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _initializeMentor() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          mentorId = user.uid;
        });
        await _fetchProgrammesAndSections(user.uid); // ✅ pass mentorId
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> _fetchProgrammesAndSections(String mentorId) async {
    favoriteIds = {};
    try {
      // --- Step 1: Load favorites ---
      final favSnap = await FirebaseFirestore.instance
          .collection("mentorFavorites")
          .doc(mentorId)
          .get();

      if (favSnap.exists && favSnap.data()?["favorites"] != null) {
        favoriteIds = Set<String>.from(favSnap.data()?["favorites"]);
      } else {
        favoriteIds = {}; // ✅ 确保为空时不是 null
      }

      // --- Step 2: Load subjectMentors ---
      final subjectMentorSnapshot = await FirebaseFirestore.instance
          .collection("subjectMentors")
          .where("mentorId", isEqualTo: mentorId)
          .get();

      print("📥 Found ${subjectMentorSnapshot.docs.length} subjectMentor docs for mentorId=$mentorId");

      if (subjectMentorSnapshot.docs.isEmpty) {
        setState(() {
          programmesData.clear();
          isLoading = false;
        });
        return;
      }

      // --- Step 3: Load customizations ---
      final customizationsSnap = await FirebaseFirestore.instance
          .collection("mentorCustomizations")
          .where("mentorId", isEqualTo: mentorId)
          .get();

      final Map<String, Map<String, dynamic>> customizations = {};
      for (var doc in customizationsSnap.docs) {
        final data = doc.data();
        final sectionId = data['sectionId'];
        if (sectionId != null) {
          customizations[sectionId.toString()] = data;
        }
      }

      // --- Step 4: Build all courses (no filtering yet) ---
      Map<String, List<Map<String, dynamic>>> tempProgrammesData = {};

      for (var doc in subjectMentorSnapshot.docs) {
        final data = doc.data();

        final schoolId    = data['schoolId']?.toString();
        final programmeId = data['programmeId']?.toString();
        final subjectId   = data['subjectId']?.toString();
        final sectionId   = data['sectionId']?.toString();

        if ([schoolId, programmeId, subjectId, sectionId].contains(null)) {
          print("⚠️ Skipping subjectMentor ${doc.id}, missing ids → $data");
          continue;
        }

        // --- Fetch programme ---
        final programmeSnap = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId!)
            .collection("programmes")
            .doc(programmeId!)
            .get();
        if (!programmeSnap.exists) continue;
        final programmeName = programmeSnap.data()?["name"] ?? "Unnamed Programme";

        // --- Fetch subject ---
        final subjectSnap = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId!)
            .get();
        if (!subjectSnap.exists) continue;
        final subjectName = subjectSnap.data()?["name"] ?? "Unnamed Subject";
        final subjectCode = subjectSnap.data()?["code"] ?? "";

        // --- Fetch section ---
        final sectionSnap = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId)
            .collection("sections")
            .doc(sectionId!)
            .get();
        if (!sectionSnap.exists) continue;
        final sectionName = sectionSnap.data()?["name"] ?? "Unnamed Section";

        // --- Apply customization ---
        final customization = customizations[sectionId];
        final storedColor = customization?['color'];

        Color cardColor = Colors.teal.shade400;
        if (storedColor != null) {
          try {
            if (storedColor is String && storedColor.startsWith('#')) {
              cardColor = Color(int.parse(storedColor.replaceFirst('#', '0xff')));
            } else {
              cardColor = Color(int.parse(storedColor.toString()));
            }
          } catch (e) {
            print("⚠️ Failed to parse color: $storedColor → $e");
          }
        }

        final item = {
          'programmeId': programmeId,
          'subjectId': subjectId,
          'sectionId': sectionId,
          'subjectName': subjectName,
          'subjectCode': subjectCode,
          'sectionName': sectionName,
          'color': cardColor,
          'schoolId': schoolId,
        };

        tempProgrammesData.putIfAbsent(programmeName, () => []);
        tempProgrammesData[programmeName]!.add(item);
      }

      print("⭐ favorites from Firestore: $favoriteIds (length=${favoriteIds.length})");
      print("📚 total courses loaded: ${tempProgrammesData.length}");

      // --- Step 5: Apply favorites filter ---
      Map<String, List<Map<String, dynamic>>> filteredData = {};
      if (favoriteIds.isEmpty) {
        // ✅ Show all courses if no favorites selected
        filteredData = tempProgrammesData;
      } else {
        // ✅ Only keep starred ones
        tempProgrammesData.forEach((programmeName, items) {
          final favItems = items.where((item) {
            final key = "${item['subjectId']}_${item['sectionId']}";
            return favoriteIds.contains(key);
          }).toList();
          if (favItems.isNotEmpty) {
            filteredData[programmeName] = favItems;
          }
        });
      }

      // --- Step 6: Update state ---
      setState(() {
        programmesData = filteredData;
        isLoading = false;
      });

      print("🎉 Dashboard updated → ${programmesData.length} programmes");
    } catch (e, st) {
      print("🔥 Error fetching mentor data: $e");
      print(st);
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> _loadTheme() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('userSettings').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        _isDarkMode = doc.data()?['darkMode'] ?? false;
      });
    }
  }

  void _showCustomizationDialog(Map<String, dynamic> item) {
    Color? selectedMainColor = item['color'] ?? Colors.teal[400];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Customize Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              MaterialColorPicker(
                selectedColor: selectedMainColor,
                allowShades: true,
                onColorChange: (color) {
                  selectedMainColor = color;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  item['color'] = selectedMainColor;
                });

                await FirebaseFirestore.instance
                    .collection('mentorCustomizations')
                    .doc('${mentorId}_${item['sectionId']}')
                    .set({
                  'mentorId': mentorId,
                  'sectionId': item['sectionId'],
                  'programmeId': item['programmeId'],
                  'color': selectedMainColor?.value.toString(),
                  'subjectName': item['subjectName'],
                  'sectionName': item['sectionName'],
                });

                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Color? _parseColor(dynamic colorValue) {
    if (colorValue is Color) return colorValue;
    if (colorValue is String) {
      try {
        return Color(int.parse(colorValue.replaceFirst('#', '0xff')));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = _isDarkMode;

    final iconColor = isDark ? Colors.tealAccent : Colors.teal;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      drawer: Drawer(
        backgroundColor: theme.canvasColor,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('mentors')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text("No mentor data found."));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Mentor';
            final email = data['email'] ?? '';
            final profileUrl = data['profileUrl'] ?? '';

            ImageProvider<Object> avatarImage;
            if (profileUrl.isNotEmpty) {
              avatarImage = NetworkImage(profileUrl);
            } else {
              avatarImage = const AssetImage("assets/images/mentor_icon.png");
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Colors.teal),
                  accountName: Text(name),
                  accountEmail: Text(email),
                  currentAccountPicture: CircleAvatar(
                    radius: 35,
                    backgroundImage: avatarImage,
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.person, color: iconColor),
                  title: Text('Profile', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditMentorProfileScreen(
                          mentorName: name,
                          email: email,
                          profileUrl: profileUrl,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.card_membership, color: iconColor),
                  title: Text('Mentor Card', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MentorCard(
                          mentorId: FirebaseAuth.instance.currentUser!.uid,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: iconColor),
                  title: Text("Settings", style: TextStyle(color: textColor)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                    await _loadTheme();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
              ],
            );
          },
        ),
      ),
      appBar: AppBar(
        title: Text('Mentor Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : _selectedIndex == 0
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header row: Courses + All Courses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Courses",
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MentorAllCoursesScreen(
                          mentorId: mentorId ?? '',
                          //initialCourses: programmesData,
                          initialFavorites: favoriteIds,
                        ),
                      ),
                    );
                    if (updated == true) {
                      await _fetchProgrammesAndSections(mentorId!);
                    }
                  },

                  child: Text(
                    "All Courses",
                    style: TextStyle(
                      fontSize: 19,
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ✅ Courses list
            Expanded(
              child: ListView.builder(
                itemCount: programmesData.length,
                itemBuilder: (context, index) {
                  String programmeName = programmesData.keys.elementAt(index);
                  List<dynamic> items = programmesData[programmeName]!;

                  return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent, // hide default line
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                collapsedShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal[100],
                                  child: Icon(Icons.school, color: Colors.teal[700]),
                                ),
                                title: Text(
                                  programmeName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "${items.length} courses",
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                                children: items.map((item) {
                                  Color cardColor = _parseColor(item['color']) ?? Colors.teal[400]!;
                                  Color textColor =
                                  cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                                  Color subtitleColor =
                                  cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cardColor.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      title: Text(
                                        item['subjectName'] ?? 'Unnamed Subject',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "${item['subjectCode'] ?? ''} • ${item['sectionName'] ?? ''}",
                                        style: TextStyle(color: subtitleColor, fontSize: 14),
                                      ),
                                      trailing: PopupMenuButton(
                                        icon: Icon(Icons.more_vert, color: textColor),
                                        onSelected: (value) {
                                          if (value == 'customize') {
                                            _showCustomizationDialog(item);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'customize',
                                            child: Text('Customize'),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SubjectSectionDetailsScreen(
                                              schoolId: item['schoolId'],
                                              programmeId: item['programmeId'],
                                              subjectName: item['subjectName'],
                                              sectionName: item['sectionName'],
                                              subjectId: item['subjectId'],
                                              sectionId: item['sectionId'],
                                              mentorId: mentorId ?? '',
                                              color: cardColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                          ),
                      ),
                  );
                },
              ),
            ),
          ],
        ),
      )
          : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Forums'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Event Notices'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}




class MentorAllCoursesScreen extends StatefulWidget {
  final String mentorId;
  final Map<String, List<Map<String, dynamic>>>? initialCourses;
  final Set<String>? initialFavorites;

  const MentorAllCoursesScreen({
    super.key,
    required this.mentorId,
    this.initialCourses,
    this.initialFavorites,
  });

  @override
  State<MentorAllCoursesScreen> createState() => _MentorAllCoursesScreenState();
}

class _MentorAllCoursesScreenState extends State<MentorAllCoursesScreen> {
  String searchQuery = '';
  String? selectedProgramme; // for dropdown filter
  Set<String> favoriteIds = {};
  bool favoritesChanged = false;
  bool isLoading = true;

  Map<String, List<Map<String, dynamic>>> allCourses = {};
  List<String> programmeList = []; //  store programme names

  @override
  void initState() {
    super.initState();

    // If the dashboard has already uploaded data, display it directly first
    if (widget.initialCourses != null) {
      //allCourses = widget.initialCourses!;
      programmeList = allCourses.keys.toList();
      favoriteIds = widget.initialFavorites ?? {};
      //isLoading = false; // 🔥 no need to refresh
    }

    // Refresh the background again to ensure it is the latest
    _loadFavorites();
    _fetchAllCourses();
  }

  Future<void> _loadFavorites() async {
    final snap = await FirebaseFirestore.instance
        .collection('mentorFavorites')
        .doc(widget.mentorId)
        .get();
    if (snap.exists) {
      final data = snap.data();
      setState(() {
        favoriteIds = Set<String>.from(data?['favorites'] ?? []);
      });
    }
  }

  Future<void> _fetchAllCourses() async {
    try {
      // --- Load customizations (same as dashboard) ---
      final customizationsSnap = await FirebaseFirestore.instance
          .collection("mentorCustomizations")
          .where("mentorId", isEqualTo: widget.mentorId)
          .get();

      final Map<String, Map<String, dynamic>> customizations = {};
      for (var doc in customizationsSnap.docs) {
        final data = doc.data();
        final sectionId = data['sectionId'];
        if (sectionId != null) {
          customizations[sectionId.toString()] = data;
        }
      }
      // --- Load subjectMentors ---
      final subjectMentorSnapshot = await FirebaseFirestore.instance
          .collection("subjectMentors")
          .where("mentorId", isEqualTo: widget.mentorId)
          .get();

      Map<String, List<Map<String, dynamic>>> tempData = {};

      for (var doc in subjectMentorSnapshot.docs) {
        final data = doc.data();
        final schoolId = data['schoolId']?.toString();
        final programmeId = data['programmeId']?.toString();
        final subjectId = data['subjectId']?.toString();
        final sectionId = data['sectionId']?.toString();

        if ([schoolId, programmeId, subjectId, sectionId].contains(null))
          continue;

        // take programme
        final progSnap = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId!)
            .collection("programmes")
            .doc(programmeId!)
            .get();
        if (!progSnap.exists) continue;
        final progName = progSnap.data()?["name"] ?? "Unnamed Programme";

        // take subject
        final subjSnap = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId!)
            .get();
        if (!subjSnap.exists) continue;
        final subjName = subjSnap.data()?["name"] ?? "Unnamed Subject";
        final subjCode = subjSnap.data()?["code"] ?? "";


        // take section
        final secSnap = await FirebaseFirestore.instance
            .collection("schools")
            .doc(schoolId)
            .collection("programmes")
            .doc(programmeId)
            .collection("subjects")
            .doc(subjectId)
            .collection("sections")
            .doc(sectionId!)
            .get();
        if (!secSnap.exists) continue;
        final secName = secSnap.data()?["name"] ?? "Unnamed Section";

        // --- Apply customization ---
        final customization = customizations[sectionId];
        final storedColor = customization?['color'];

        Color cardColor = Colors.teal.shade400;
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
        final item = {
          'programmeId': programmeId,
          'subjectId': subjectId,
          'sectionId': sectionId,
          'subjectName': subjName,
          'subjectCode': subjCode,
          'sectionName': secName,
          'color': cardColor, // default
          'schoolId': schoolId,
        };

        tempData.putIfAbsent(progName, () => []);
        tempData[progName]!.add(item);
      }

      setState(() {
        allCourses = tempData;
        programmeList = tempData.keys.toList(); //  build programme dropdown
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading all courses: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite(String subjectId, String sectionId) async {
    final favKey = "${subjectId}_${sectionId}";
    final docRef = FirebaseFirestore.instance
        .collection("mentorFavorites")
        .doc(widget.mentorId);

    final snap = await docRef.get();
    if (snap.exists) {
      final currentFavs = List<String>.from(snap.data()?['favorites'] ?? []);
      if (currentFavs.contains(favKey)) {
        await docRef.update({
          'favorites': FieldValue.arrayRemove([favKey]),
        });
        setState(() {
          favoriteIds.remove(favKey);
          favoritesChanged = true;
        });
      } else {
        await docRef.update({
          'favorites': FieldValue.arrayUnion([favKey]),
        });
        setState(() {
          favoriteIds.add(favKey);
          favoritesChanged = true;
        });
      }
    } else {
      await docRef.set({
        'favorites': [favKey],
      });
      setState(() {
        favoriteIds.add(favKey);
        favoritesChanged = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, favoritesChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("All Courses"),
          actions: [
            // 🔎 search
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () async {
                final query = await showSearch<String>(
                  context: context,
                  delegate: _CourseSearchDelegate(
                    allCourses: allCourses,
                    favoriteIds: favoriteIds,
                  ),
                );
                if (query != null) {
                  setState(() => searchQuery = query);
                }
              },
            ),
          ],
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, favoritesChanged);
            },
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // 🔽 Programme filter dropdown
            if (programmeList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: DropdownButton<String>(
                  value: selectedProgramme,
                  hint: Text("Filter by Programme"),
                  isExpanded: true,
                  items: programmeList
                      .map((p) =>
                      DropdownMenuItem(
                        value: p,
                        child: Text(p),
                      ))
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedProgramme = val);
                  },
                ),
              ),

            // ✅ List
            Expanded(
              child: ListView.builder(
                itemCount: allCourses.length,
                itemBuilder: (context, index) {
                  final progName = allCourses.keys.elementAt(index);

                  // 🔥 Apply programme filter
                  if (selectedProgramme != null &&
                      progName != selectedProgramme) {
                    return SizedBox.shrink();
                  }

                  final items = allCourses[progName]!;
                  final filtered = items.where((e) {
                    final subject =
                    (e['subjectName'] ?? '').toLowerCase();
                    final section =
                    (e['sectionName'] ?? '').toLowerCase();
                    final prog = progName.toLowerCase();
                    return subject
                        .contains(searchQuery.toLowerCase()) ||
                        section
                            .contains(searchQuery.toLowerCase()) ||
                        prog.contains(searchQuery.toLowerCase());
                  }).toList();

                  if (filtered.isEmpty) return SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          progName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                        ),
                      ),
                      ...filtered.map((item) {
                        final favKey =
                            "${item['subjectId']}_${item['sectionId']}";
                        final isFav = favoriteIds.contains(favKey);

                        return Card(
                          color: item['color'],
                          child: Builder(
                            builder: (context) {
                              final Color cardColor = item['color'] ?? Colors.teal.shade400;
                              final Color textColor = cardColor.computeLuminance() > 0.5
                                  ? Colors.black87
                                  : Colors.white;
                              final Color subtitleColor = cardColor.computeLuminance() > 0.5
                                  ? Colors.black54
                                  : Colors.white70;

                              return ListTile(
                                title: Text(
                                  item['subjectName'] ?? 'Unnamed Subject',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "${item['subjectCode'] ?? ''} • ${item['sectionName'] ?? ''}",
                                  style: TextStyle(color: subtitleColor),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: isFav ? Colors.yellow[700] : Colors.black87,
                                  ),
                                  onPressed: () =>
                                      _toggleFavorite(item['subjectId'], item['sectionId']),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SubjectSectionDetailsScreen(
                                        subjectName: item['subjectName'],
                                        sectionName: item['sectionName'],
                                        programmeId: item['programmeId'],
                                        schoolId: item['schoolId'],
                                        subjectId: item['subjectId'],
                                        sectionId: item['sectionId'],
                                        mentorId: widget.mentorId,
                                        color: cardColor,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ],
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

class _CourseSearchDelegate extends SearchDelegate<String> {
  final Map<String, List<Map<String, dynamic>>> allCourses;
  final Set<String> favoriteIds;

  _CourseSearchDelegate({
    required this.allCourses,
    required this.favoriteIds,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, query); // return current query
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildFilteredList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildFilteredList();
  }

  Widget _buildFilteredList() {
    final normalizedQuery = query.trim().toLowerCase();
    final results = <Map<String, dynamic>>[];

    allCourses.forEach((progName, items) {
      for (var item in items) {
        final subject = (item['subjectName'] ?? '').toLowerCase();
        final code = (item['subjectCode'] ?? '').toLowerCase();
        final section = (item['sectionName'] ?? '').toLowerCase();

        if (normalizedQuery.isEmpty ||
            subject.contains(normalizedQuery) ||
            code.contains(normalizedQuery) ||
            section.contains(normalizedQuery)) {
          results.add({
            ...item,
            'programmeName': progName,
          });
        }
      }
    });

    if (results.isEmpty) {
      return const Center(child: Text("No results found"));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final favKey = "${item['subjectId']}_${item['sectionId']}";
        final isFav = favoriteIds.contains(favKey);

        return ListTile(
          title: Text(item['subjectName'] ?? 'Unnamed Subject'),
          subtitle: Text(
            "${item['subjectCode'] ?? ''} • ${item['sectionName'] ?? ''} • ${item['programmeName'] ?? ''}",
          ),
          trailing: Icon(
            isFav ? Icons.star : Icons.star_border,
            color: isFav ? Colors.yellow[700] : Colors.grey,
          ),
          onTap: () {
            close(context, query);
          },
        );
      },
    );
  }
}

