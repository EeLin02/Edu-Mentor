import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ThemeNotifier() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadThemeFromFirebase(user.uid);
      }
    });
  }

  Future<void> _loadThemeFromFirebase(String uid) async {
    final doc = await _firestore.collection('userSettings').doc(uid).get();
    _isDarkMode = doc.data()?['darkMode'] ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('userSettings').doc(user.uid).set({
        'darkMode': value,
      }, SetOptions(merge: true));

      _isDarkMode = value;
      notifyListeners();
    }
  }
}

