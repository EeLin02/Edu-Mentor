import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'edit_account_screen.dart';

class ManageAccountsScreen extends StatefulWidget {
  @override
  _ManageAccountsScreenState createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String selectedRoleFilter = 'All';
  late Future<List<Map<String, dynamic>>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = fetchAllAccounts();
  }

  Future<List<Map<String, dynamic>>> fetchAllAccounts() async {
    final students = await _firestore.collection('students').get();
    final mentors = await _firestore.collection('mentors').get();

    List<Map<String, dynamic>> accounts = [];

    accounts.addAll(students.docs.map((doc) => {
      ...doc.data(),
      'uid': doc.id,
      'role': 'Student',
    }));

    accounts.addAll(mentors.docs.map((doc) => {
      ...doc.data(),
      'uid': doc.id,
      'role': 'Mentor',
    }));

    return accounts;
  }

  Future<void> disableAccount(String uid, String role) async {
    try {
      final collection = role == 'Student' ? 'students' : 'mentors';
      await _firestore.collection(collection).doc(uid).update({'disabled': true});

      _showMessage("✅ Account has been disabled.");
      setState(() {
        _accountsFuture = fetchAllAccounts();
      });
    } catch (e) {
      _showMessage("❌ Error disabling account: $e");
    }
  }

  Future<void> enableAccount(String uid, String role) async {
    try {
      final collection = role == 'Student' ? 'students' : 'mentors';
      await _firestore.collection(collection).doc(uid).update({'disabled': false});

      _showMessage("✅ Account has been enabled.");
      setState(() {
        _accountsFuture = fetchAllAccounts();
      });
    } catch (e) {
      _showMessage("❌ Error enabling account: $e");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAndDisable(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Confirm Disable"),
        content: Text("Are you sure you want to disable ${user['name']}'s account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Disable", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await disableAccount(user['uid'], user['role']);
    }
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    bool isDisabled = user['disabled'] == true;

    Color activeColor;
    Color disabledColor;

    if (user['role'] == 'Student') {
      activeColor = Colors.blue;
      disabledColor = Colors.blue.shade200;
    } else {
      // Mentor
      activeColor = Colors.green;
      disabledColor = Colors.green.shade200;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDisabled ? disabledColor : activeColor,
          child: Icon(
            user['role'] == 'Student' ? Icons.school : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          user['name'] ?? 'No name',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isDisabled ? TextDecoration.lineThrough : null,
            color: isDisabled ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              user['email'] ?? 'No email',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            SizedBox(height: 2),
            Text(
              'Role: ${user['role']}',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            SizedBox(height: 2),
            Text(
              isDisabled ? "Status: Disabled" : "Status: Active",
              style: TextStyle(
                fontSize: 13,
                color: isDisabled ? Colors.redAccent : Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          children: [
            Tooltip(
              message: 'Edit Account',
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditAccountScreen(userData: user),
                    ),
                  );
                  setState(() {
                    _accountsFuture = fetchAllAccounts();
                  });
                },
              ),
            ),
            Tooltip(
              message: isDisabled ? "Enable Account" : "Disable Account",
              child: IconButton(
                icon: Icon(
                  isDisabled ? Icons.check_circle : Icons.block,
                  color: isDisabled ? Colors.green : Colors.redAccent,
                ),
                onPressed: isDisabled
                    ? () => enableAccount(user['uid'], user['role'])
                    : () => _confirmAndDisable(user),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Accounts"),
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<String>(
              value: selectedRoleFilter,
              decoration: InputDecoration(
                labelText: "Filter by Role",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: ['All', 'Student', 'Mentor'].map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedRoleFilter = value;
                  });
                }
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _accountsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final accounts = snapshot.data ?? [];

                final filtered = selectedRoleFilter == 'All'
                    ? accounts
                    : accounts.where((u) => u['role'] == selectedRoleFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      "No ${selectedRoleFilter.toLowerCase()}s found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemBuilder: (_, index) => _buildUserTile(filtered[index]),
                  separatorBuilder: (_, __) => Divider(indent: 16, endIndent: 16),
                  itemCount: filtered.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
