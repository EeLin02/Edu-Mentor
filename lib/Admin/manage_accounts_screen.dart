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
  String searchQuery = '';
  String selectedProgrammeId = '';
  List<Map<String, dynamic>> programmes = [];
  late Future<List<Map<String, dynamic>>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _loadProgrammes();
    _accountsFuture = fetchAllAccounts();
  }

  Future<void> _loadProgrammes() async {
    final snapshot = await _firestore.collection('schools').get();
    // Flatten all programmes in all schools
    final List<Map<String, dynamic>> temp = [];
    for (var schoolDoc in snapshot.docs) {
      final schoolId = schoolDoc.id;
      final progSnapshot = await _firestore.collection('schools').doc(schoolId).collection('programmes').get();
      for (var progDoc in progSnapshot.docs) {
        temp.add({
          'id': progDoc.id,
          'name': progDoc['name'],
          'schoolId': schoolId,
        });
      }
    }
    setState(() => programmes = temp);
  }

  Future<List<Map<String, dynamic>>> fetchAllAccounts() async {
    final studentsSnapshot = await _firestore.collection('students').get();
    final mentorsSnapshot = await _firestore.collection('mentors').get();

    List<Map<String, dynamic>> accounts = [];

    accounts.addAll(studentsSnapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      data['role'] = 'Student';
      data['programmeIds'] = [data['programmeId'] ?? ''];
      return data;
    }));

    accounts.addAll(mentorsSnapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      data['role'] = 'Mentor';
      data['programmeIds'] = List<String>.from(data['programmeIds'] ?? []);
      return data;
    }));

    return accounts;
  }

  Future<List<String>> getProgrammeNames(List<String> programmeIds) async {
    final names = <String>[];
    for (var id in programmeIds) {
      final prog = programmes.firstWhere(
            (p) => p['id'] == id,
        orElse: () => {'name': 'N/A'},
      );
      names.add(prog['name']);
    }
    return names;
  }

  Future<void> disableAccount(String uid, String role) async {
    final collection = role == 'Student' ? 'students' : 'mentors';
    await _firestore.collection(collection).doc(uid).update({'disabled': true});
    _showMessage("✅ Account has been disabled.");
    setState(() => _accountsFuture = fetchAllAccounts());
  }

  Future<void> enableAccount(String uid, String role) async {
    final collection = role == 'Student' ? 'students' : 'mentors';
    await _firestore.collection(collection).doc(uid).update({'disabled': false});
    _showMessage("✅ Account has been enabled.");
    setState(() => _accountsFuture = fetchAllAccounts());
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Disable", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) await disableAccount(user['uid'], user['role']);
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    bool isDisabled = user['disabled'] == true;
    Color activeColor = user['role'] == 'Student' ? Colors.blue : Colors.green;
    Color disabledColor = user['role'] == 'Student' ? Colors.blue.shade200 : Colors.green.shade200;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDisabled ? disabledColor : activeColor,
          child: Icon(user['role'] == 'Student' ? Icons.school : Icons.person, color: Colors.white),
        ),
        title: Text(user['name'] ?? 'No name', style: TextStyle(fontWeight: FontWeight.w600, decoration: isDisabled ? TextDecoration.lineThrough : null)),
        subtitle: FutureBuilder<List<String>>(
          future: getProgrammeNames(List<String>.from(user['programmeIds'] ?? [])),
          builder: (context, snapshot) {
            final progText = snapshot.hasData ? (snapshot.data!.isEmpty ? 'N/A' : snapshot.data!.join(', ')) : 'Loading...';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(user['email'] ?? 'No email', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                SizedBox(height: 2),
                Text('Role: ${user['role']}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                SizedBox(height: 2),
                Text('ID: ${user['studentIdNo'] ?? user['mentorIdNo'] ?? 'N/A'}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                SizedBox(height: 2),
                Text('Programme: $progText', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                SizedBox(height: 2),
                Text(isDisabled ? "Status: Disabled" : "Status: Active", style: TextStyle(fontSize: 13, color: isDisabled ? Colors.redAccent : Colors.green[700], fontWeight: FontWeight.w600)),
              ],
            );
          },
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Edit Account',
              icon: Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => EditAccountScreen(userId: user['uid'],          // use uid from user map
                    role: user['role'],           // role from user map
                    userData: user)));
                setState(() => _accountsFuture = fetchAllAccounts());
              },
            ),
            IconButton(
              tooltip: isDisabled ? "Enable Account" : "Disable Account",
              icon: Icon(isDisabled ? Icons.check_circle : Icons.block, color: isDisabled ? Colors.green : Colors.redAccent),
              onPressed: isDisabled ? () => enableAccount(user['uid'], user['role']) : () => _confirmAndDisable(user),
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
          // Role filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: selectedRoleFilter,
              decoration: InputDecoration(
                labelText: "Filter by Role",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: ['All', 'Student', 'Mentor'].map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
              onChanged: (value) { if (value != null) setState(() => selectedRoleFilter = value); },
            ),
          ),

          // Programme filter (searchable dropdown)
          if (programmes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return programmes.where((prog) => prog['name'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (prog) => prog['name'],
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: "Filter by Programme",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.school),
                    ),
                  );
                },
                onSelected: (prog) {
                  setState(() {
                    selectedProgrammeId = prog['id'];
                  });
                },
              ),
            ),

          // Search bar for name
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search by Name",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),

          // Accounts list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('students').snapshots(),
              builder: (context, studentSnap) {
                if (studentSnap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!studentSnap.hasData) return Center(child: Text("No students found."));

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('mentors').snapshots(),
                  builder: (context, mentorSnap) {
                    if (mentorSnap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!mentorSnap.hasData) return Center(child: Text("No mentors found."));

                    // 🔹 Convert snapshots into accounts
                    final students = studentSnap.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['uid'] = doc.id;
                      data['role'] = 'Student';
                      data['programmeIds'] = [data['programmeId'] ?? ''];
                      return data;
                    }).toList();

                    final mentors = mentorSnap.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['uid'] = doc.id;
                      data['role'] = 'Mentor';
                      data['programmeIds'] = List<String>.from(data['programmeIds'] ?? []);
                      return data;
                    }).toList();

                    final accounts = [...students, ...mentors];

                    //  Apply filters
                    final filtered = accounts.where((u) {
                      final matchesRole =
                          selectedRoleFilter == 'All' || u['role'] == selectedRoleFilter;
                      final matchesName = searchQuery.isEmpty ||
                          (u['name']?.toLowerCase().contains(searchQuery) ?? false);

                      final programmeIds = (u['programmeIds'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                          [];
                      final matchesProgramme =
                          selectedProgrammeId.isEmpty || programmeIds.contains(selectedProgrammeId);

                      return matchesRole && matchesName && matchesProgramme;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text("No accounts found.",
                            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemBuilder: (_, index) => _buildUserTile(filtered[index]),
                      separatorBuilder: (_, __) => Divider(indent: 16, endIndent: 16),
                      itemCount: filtered.length,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
