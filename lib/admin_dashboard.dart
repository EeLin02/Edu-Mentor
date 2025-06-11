import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Admin/create_account_screen.dart';
import 'Admin/edit_admin_profile_screen.dart';
import 'Admin/system_structure_screen.dart';
import 'Admin/notice_board_screen.dart';
import 'Admin/manage_accounts_screen.dart';
import 'Admin/manage_notice_screen.dart';
import 'settings_screen.dart';
import 'login.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String adminName = "";
  String email = "";
  String profileUrl = "";
  bool _isCheckingAdmin = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _checkAdminPrivileges();
    _loadTheme();
  }

  Future<void> _checkAdminPrivileges() async {
    final user = _auth.currentUser;
    if (user == null) {
      _redirectToLogin();
      return;
    }

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims ?? {};

      if (claims['admin'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Access denied: Admin privileges required.')),
          );
          await _auth.signOut();
          _redirectToLogin();
        }
      } else {
        await _loadAdminData(user);
        if (mounted) {
          setState(() {
            _isCheckingAdmin = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying admin privileges: $e')),
        );
        await _auth.signOut();
        _redirectToLogin();
      }
    }
  }

  Future<void> _loadAdminData(User user) async {
    try {
      final doc = await _firestore.collection('admins').doc(user.uid).get();
      setState(() {
        adminName = doc.data()?['name'] ?? 'Admin';
        email = user.email ?? '';
        profileUrl = doc.data()?['profileUrl'] ?? '';
      });
    } catch (e) {
      setState(() {
        adminName = 'Admin';
        email = user.email ?? '';
        profileUrl = '';
      });
    }
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    _redirectToLogin();
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


  @override
  Widget build(BuildContext context) {
    if (_isCheckingAdmin) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = _isDarkMode;

    final iconColor = isDark ? Colors.purpleAccent : Colors.deepPurple;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      drawer: Drawer(
        backgroundColor: theme.canvasColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.deepPurple.shade700, Colors.deepPurple.shade400]
                      : [Colors.deepPurple, Colors.purpleAccent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminEditProfileScreen(
                            name: adminName,
                            email: email,
                          ),
                        ),
                      );
                      await _checkAdminPrivileges();
                    },
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: profileUrl.isNotEmpty
                          ? NetworkImage(profileUrl)
                          : AssetImage("assets/images/admin_avatar.png")
                      as ImageProvider,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    adminName,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    email,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
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
            Divider(color: isDark ? Colors.white54 : Colors.grey),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text("Logout", style: TextStyle(color: textColor)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text("Edu Mentor Admin Dashboard"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),  // <-- set white color here
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      body: Column(
        children: [
          _buildHeader(textColor),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildMenuTile(Icons.person_add, "Create Account",
                    "Register students and mentors", () => _navigate(CreateAccountScreen()), iconColor, textColor, subtitleColor),
                _buildMenuTile(Icons.people, "Manage Accounts",
                    "View, edit, and delete users", () => _navigate(ManageAccountsScreen()), iconColor, textColor, subtitleColor),
                _buildMenuTile(Icons.school, "System Structure",
                    "Manage departments, classes & subjects", () => _navigate(SystemStructureScreen()), iconColor, textColor, subtitleColor),
                _buildMenuTile(Icons.announcement, "Notice Board",
                    "Publish announcements & updates", () => _navigate(NoticeBoardScreen()), iconColor, textColor, subtitleColor),
                _buildMenuTile(Icons.announcement_outlined, "Manage Notices",
                    "View, edit, or delete posted notices", () => _navigate(ManageNoticesScreen()), iconColor, textColor, subtitleColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildHeader(Color textColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purpleAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: profileUrl.isNotEmpty
                ? NetworkImage(profileUrl)
                : AssetImage("assets/images/admin_avatar.png") as ImageProvider,
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome Back, ${adminName.isNotEmpty ? adminName : 'Admin'}!",
                style: TextStyle(
                    fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                "Manage your institution effectively",
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
      IconData icon, String title, String subtitle, VoidCallback onTap,
      Color iconColor, Color textColor, Color subtitleColor) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 30),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: subtitleColor),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: iconColor),
        onTap: onTap,
      ),
    );
  }
}
