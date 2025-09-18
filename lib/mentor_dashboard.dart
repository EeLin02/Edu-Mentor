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
  Map<String, List<Map<String, dynamic>>> departmentsData = {};
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
    // Your full dashboard UI wrapped in a widget
    MentorDashboard(),  // see next for this widget
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
        await _fetchDepartmentsAndClasses();
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

  Future<void> _fetchDepartmentsAndClasses() async {
    if (mentorId == null) return;

    try {
      final customizationsSnapshot = await FirebaseFirestore.instance
          .collection('mentorCustomizations')
          .where('mentorId', isEqualTo: mentorId)
          .get();

      Map<String, Map<String, dynamic>> customizations = {};
      for (var doc in customizationsSnapshot.docs) {
        String classId = doc['classId'];
        customizations[classId] = {
          'nickname': doc['nickname'],
          'color': Color(int.parse(doc['color'])),
        };
      }

      final subjectMentorSnapshot = await FirebaseFirestore.instance
          .collection('subjectMentors')
          .where('mentorId', isEqualTo: mentorId)
          .get();

      Map<String, List<Map<String, dynamic>>> tempDepartmentsData = {};

      for (var doc in subjectMentorSnapshot.docs) {
        String departmentId = doc['departmentId'];
        String subjectId = doc['subjectId'];
        List<dynamic> classIds = doc['classIds'];

        final departmentDoc = await FirebaseFirestore.instance
            .collection('departments')
            .doc(departmentId)
            .get();
        if (!departmentDoc.exists) continue;
        String departmentName = departmentDoc.data()?['name'] ?? 'Unknown Department';

        if (!tempDepartmentsData.containsKey(departmentName)) {
          tempDepartmentsData[departmentName] = [];
        }

        final subjectDoc = await FirebaseFirestore.instance
            .collection('departments')
            .doc(departmentId)
            .collection('subjects')
            .doc(subjectId)
            .get();
        if (!subjectDoc.exists) continue;
        String subjectName = subjectDoc.data()?['name'] ?? 'Unknown Subject';

        for (var classId in classIds) {
          final classDoc = await FirebaseFirestore.instance
              .collection('departments')
              .doc(departmentId)
              .collection('subjects')
              .doc(subjectId)
              .collection('classes')
              .doc(classId)
              .get();

          if (!classDoc.exists) continue;
          String className = classDoc.data()?['name'] ?? 'Unknown Class';

          Color defaultColor = Colors.teal[400]!;
          String nickname = '';

          if (customizations.containsKey(classId)) {
            nickname = customizations[classId]!['nickname'] ?? '';
            defaultColor = customizations[classId]!['color'] ?? Colors.teal[400]!;
          }

          tempDepartmentsData[departmentName]!.add({
            'subjectId': subjectId,
            'subjectName': subjectName,
            'className': className,
            'classId': classId,
            'departmentId': departmentId,
            'nickname': nickname,
            'color': defaultColor,
          });
        }
      }

      setState(() {
        departmentsData = tempDepartmentsData;
        isLoading = false;
      });
    } catch (e) {
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
    TextEditingController nicknameController = TextEditingController(text: item['nickname']);
    Color? selectedMainColor = item['color'] ?? Colors.teal[400];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Customize Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nicknameController,
                decoration: InputDecoration(labelText: 'Nickname'),
              ),
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
                  item['nickname'] = nicknameController.text;
                  item['color'] = selectedMainColor;
                });

                await FirebaseFirestore.instance
                    .collection('mentorCustomizations')
                    .doc('${mentorId}_${item['classId']}')
                    .set({
                  'mentorId': mentorId,
                  'classId': item['classId'],
                  'departmentId': item['departmentId'],
                  'nickname': nicknameController.text,
                  'color': selectedMainColor?.value.toString(),
                  'subjectName': item['subjectName'],
                  'className': item['className'],
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
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _fetchMentorProfile(),
          builder: (context, snapshot) {
            final name = snapshot.data?['name'] ?? 'Mentor';
            final email = snapshot.data?['email'] ?? '';
            final profileUrl = snapshot.data?['profileUrl'] ?? '';

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
                          mentorId: FirebaseAuth.instance.currentUser!.uid, // or your stored mentorId
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

        iconTheme: const IconThemeData(color: Colors.white), //menu icon white color
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : _selectedIndex == 0
          ? ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: departmentsData.length,
        separatorBuilder: (_, __) => Divider(height: 32, color: Colors.grey[300]),
        itemBuilder: (context, index) {
          String departmentName = departmentsData.keys.elementAt(index);
          List<dynamic> items = departmentsData[departmentName]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                departmentName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[700],
                ),
              ),
              SizedBox(height: 10),
              ...items.map((item) {
                Color cardColor = _parseColor(item['color']) ?? Colors.teal[400]!;

                Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                Color subtitleColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withOpacity(0.4),
                        blurRadius: 6,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Text(
                      item['nickname'].isNotEmpty ? item['nickname'] : item['subjectName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      item['className'],
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                      ),
                    ),
                    trailing: PopupMenuButton(
                      icon: Icon(Icons.more_vert, color: textColor),
                      onSelected: (value) {
                        if (value == 'customize') {
                          _showCustomizationDialog(item);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'customize',
                          child: Text('Customize'),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubjectClassDetailsScreen(
                            subjectName: item['subjectName'],
                            className: item['className'],
                            subjectId: item['subjectId'],   // Make sure you include this in your item
                            classId: item['classId'],
                            mentorId: mentorId ?? '',
                            color: cardColor,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          );
        },
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
