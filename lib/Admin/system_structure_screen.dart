import 'package:flutter/material.dart';
import 'system structure/create_school.dart';
import 'system structure/create_programme.dart';
import 'system structure/create_subject.dart';
import 'system structure/create_section.dart';
import 'system structure/assign_mentor.dart';
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
              title: "CREATE SCHOOL",
              subtitle: "Add and Manage Schools",
              icon: Icons.apartment_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageSchoolsScreen()),
                );
              },
            ),
            _DashboardCard(
              title: "CREATE PROGRAMME",
              subtitle: "Add and Manage Programmes (via Schools)",
              icon: Icons.school_outlined,
              onTap: () {
                // 👇 Always go through ManageSchoolsScreen first
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageProgrammesScreen()),
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
              title: "CREATE SECTION",
              subtitle: "Add and Manage Sections",
              icon: Icons.group_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageSectionsScreen()),
                );
              },
            ),
            _DashboardCard(
              title: "ASSIGN MENTOR TO SYSTEM STRUCTURE",
              subtitle: "Assign Roles to Structure",
              icon: Icons.hub_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AssignMentorScreen()),
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
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
