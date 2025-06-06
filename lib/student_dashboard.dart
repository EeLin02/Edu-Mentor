import 'package:flutter/material.dart';

class StudentDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildDashboardCard(
              context,
              icon: Icons.check_circle,
              title: "Attendance",
              color: Colors.blue,
              onTap: () {
                // Navigate to Attendance Page
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.chat,
              title: "Chat with Mentors",
              color: Colors.green,
              onTap: () {
                // Navigate to Chat Page
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.book,
              title: "Resources",
              color: Colors.orange,
              onTap: () {
                // Navigate to Resources Page
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.forum,
              title: "Forums",
              color: Colors.purple,
              onTap: () {
                // Navigate to Forums Page
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.notifications,
              title: "Notifications",
              color: Colors.red,
              onTap: () {
                // Navigate to Notifications Page
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
        required String title,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
