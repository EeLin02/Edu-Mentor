import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme_notifier.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _loadUserSettings();
    }
  }

  Future<void> _loadUserSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('userSettings')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _notificationsEnabled = data['notificationsEnabled'] ?? true;
      });

      // Apply theme
      final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
      themeNotifier.toggleTheme(data['darkMode'] ?? false);
    }
  }

  Future<void> _updateUserSetting(String key, dynamic value) async {
    await FirebaseFirestore.instance
        .collection('userSettings')
        .doc(user!.uid)
        .set({key: value}, SetOptions(merge: true));
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: Text("Enable Notifications"),
              subtitle: Text("Toggle app notifications on/off"),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _updateUserSetting('notificationsEnabled', value);
              },
            ),
            SwitchListTile(
              title: Text("Dark Mode"),
              subtitle: Text("Switch between light and dark themes"),
              value: themeNotifier.isDarkMode,
              onChanged: (value) {
                themeNotifier.toggleTheme(value);
                _updateUserSetting('darkMode', value);
              },
            ),
            Divider(height: 40, thickness: 1),
            ListTile(
              title: Text("About"),
              subtitle: Text("Learn more about this app"),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: "Edu Mentor",
                  applicationVersion: "1.0.0",
                  applicationLegalese: "© 2025 Edu Mentor Inc.",
                );
              },
            ),
            ListTile(
              title: Text("Privacy Policy"),
              onTap: () {
                _showLegalDialog("Privacy Policy", """
This is the privacy policy of the Edu Mentor app. We value your privacy and do not share your personal information with third parties.
""");
              },
            ),
            ListTile(
              title: Text("Terms of Use"),
              onTap: () {
                _showLegalDialog("Terms of Use", """
By using this app, you agree to the terms and conditions set forth by Edu Mentor. Use the app responsibly.
""");
              },
            ),
          ],
        ),
      ),
    );
  }
}
