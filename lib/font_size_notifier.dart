import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FontSizeNotifier extends ChangeNotifier {
  double _fontSize = 16.0;
  double get fontSize => _fontSize;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FontSizeNotifier() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadFontSizeFromFirebase(user.uid);
      }
    });
  }

  Future<void> _loadFontSizeFromFirebase(String uid) async {
    final doc = await _firestore.collection('userSettings').doc(uid).get();
    _fontSize = (doc.data()?['fontSize'] ?? 16.0).toDouble();
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('userSettings').doc(user.uid).set({
        'fontSize': size,
      }, SetOptions(merge: true));

      _fontSize = size;
      notifyListeners();
    }
  }
}

