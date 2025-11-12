import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard.dart';
import 'mentor_dashboard.dart';
import 'student_dashboard.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _obscurePassword = true;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    try {
      //  Sign in with Firebase Authentication
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        _showError("User not found");
        return;
      }

      // Force token refresh to ensure latest status
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims ?? {};
      print("Custom Claims: $claims");

      //  Request FCM token
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      final token = await fcm.getToken();

      //  Firestore reference
      final firestore = FirebaseFirestore.instance;

      // STUDENT ROLE
      final studentDoc = await firestore.collection('students').doc(user.uid).get();
      if (studentDoc.exists) {
        final data = studentDoc.data();
        final isDisabled = data?['disabled'] ?? false;

        if (isDisabled == true) {
          _showError("This student account has been disabled. Please contact the administrator.");
          await _auth.signOut();
          return;
        }

        if (token != null) {
          await firestore.collection('students').doc(user.uid).set(
            {'fcmToken': token},
            SetOptions(merge: true),
          );
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StudentDashboard()),
        );
        return;
      }

      // MENTOR ROLE
      final mentorDoc = await firestore.collection('mentors').doc(user.uid).get();
      if (mentorDoc.exists) {
        final data = mentorDoc.data();
        final isDisabled = data?['disabled'] ?? false;

        if (isDisabled == true) {
          _showError("This mentor account has been disabled. Please contact the administrator.");
          await _auth.signOut();
          return;
        }

        if (token != null) {
          await firestore.collection('mentors').doc(user.uid).set(
            {'fcmToken': token},
            SetOptions(merge: true),
          );
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MentorDashboard()),
        );
        return;
      }

      // ADMIN ROLE
      final adminDoc = await firestore.collection('admins').doc(user.uid).get();
      if (adminDoc.exists) {
        if (token != null) {
          await firestore.collection('admins').doc(user.uid).set(
            {'fcmToken': token},
            SetOptions(merge: true),
          );
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AdminDashboard()),
        );
        return;
      }

      // No valid role
      _showError("No valid role assigned for this account.");
      await _auth.signOut();

    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          errorMessage = "Email not found in the system.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password. Please try again.";
          break;
        case 'invalid-email':
          errorMessage = "The email address format is invalid.";
          break;
        case 'user-disabled':
          errorMessage = "This account has been disabled. Please contact support.";
          break;
        case 'invalid-credential':
          final userExists = await _checkIfUserExists(email);
          if (userExists) {
            errorMessage = "Incorrect password. Please try again.";
          } else {
            errorMessage = "No account found with this email address.";
          }
          break;
        default:
          errorMessage = "Login failed (${e.code}). Please try again.";
      }
      _showError(errorMessage);
    } catch (e) {
      _showError("Something went wrong: $e");
    }
  }


  Future<bool> _checkIfUserExists(String email) async {
    final users = ['students', 'mentors', 'admins'];
    for (var collection in users) {
      final query = await FirebaseFirestore.instance
          .collection(collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return true;
      }
    }
    return false;
  }


  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Oops!"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo outside the card
              Image.asset(
                'assets/images/school_logo.png',
                width: 120,
                height: 120,
              ),
              SizedBox(height: 24),

              // The card container
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        "Edu Mentor",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Let's get you signed in!",
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(color: Colors.black),
                          prefixIcon: Icon(Icons.email, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.blue[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: Colors.black),
                          prefixIcon: Icon(Icons.lock, color: Colors.blue),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.blueGrey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.blue[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
