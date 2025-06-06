import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'system structure/create_department.dart';
import 'system structure/create_class.dart';
import 'system structure/create_subject.dart';
import 'system structure/assign_student_&_mentor.dart';
import 'system structure/view_assign_roles.dart';


class SystemStructureScreen extends StatefulWidget {
  @override
  _SystemStructureScreenState createState() => _SystemStructureScreenState();
}

class _SystemStructureScreenState extends State<SystemStructureScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("System Structure")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          children: [
            _DashboardCard(
              title: "CREATE DEPARTMENT",
              subtitle: "Add and Manage Departments",
              icon: Icons.account_tree_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageDepartmentsScreen()),
                );
              },
            ),
            _DashboardCard(
              title: "CREATE SUBJECT",
              subtitle: "Add and Manage Subjects",
              icon: Icons.book_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageSubjectsScreen()),
                );
              },
            ),
            _DashboardCard(
              title: "CREATE CLASS",
              subtitle: "Add and Manage Classes",
              icon: Icons.class_,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageClassesScreen()),
                );
              },
            ),

            _DashboardCard(
              title: "ASSIGN ROLES TO SYSTEM STRUCTURE",
              subtitle: "Assign by Department, Class, and Subject",
              icon: Icons.hub_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageStudentsAndMentorsScreen()),
                );
              },
            ),
            _DashboardCard(
              title: "ASSIGN ROLES DASHBOARD",
              subtitle: "Preview roles assignments",
              icon: Icons.assignment,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AssignmentsDashboardScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

