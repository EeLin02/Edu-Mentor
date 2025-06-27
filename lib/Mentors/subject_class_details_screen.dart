import 'package:flutter/material.dart';

class SubjectClassDetailsScreen extends StatelessWidget {
  final String subjectName;
  final String className;
  final Color color;
  final String subjectId;
  final String classId;
  final String mentorId;

  const SubjectClassDetailsScreen({
    Key? key,
    required this.subjectName,
    required this.className,
    required this.color,
    required this.subjectId,
    required this.classId,
    required this.mentorId,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // Compute contrast-aware colors
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;


    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('$subjectName · $className', style: TextStyle(color: textColor)),
        backgroundColor: color,
        iconTheme: IconThemeData(color: textColor),
        elevation: 4,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _infoCard(textColor),
            const SizedBox(height: 30),
            _sectionTitle(
              'Home Page',
              Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
            ),

            const SizedBox(height: 10),
            _actionButton(
              context,
              icon: Icons.check_circle_outline,
              label: 'Announcement',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(context, '/announcement', arguments: {
                  'subjectName': subjectName,
                  'className': className,
                  'color': color,
                });
              },
            ),
            const SizedBox(height: 12),
            _actionButton(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'Chat to students',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/classChat',
                  arguments: {
                    'subjectId': subjectId,
                    'classId': classId,
                    'mentorId': mentorId,
                    'subjectName': subjectName,
                    'className': className,
                    'color': color, // optional
                  },
                );

              },
            ),
            const SizedBox(height: 12),
            _actionButton(
              context,
              icon: Icons.folder_shared_outlined,
              label: 'Share Resources',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(context, '/shareResources', arguments: {
                  'subjectName': subjectName,
                  'className': className,
                  'color': color,
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(Color textColor) {
    final bool isLight = color.computeLuminance() > 0.5;
    final Color valueTextColor = isLight ? Colors.black54 : Colors.white70;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color, // changed from white to dynamic color
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _infoRow('Subject:', subjectName, textColor, valueTextColor),
            const SizedBox(height: 10),
            _infoRow('Class:', className, textColor, valueTextColor),
            const SizedBox(height: 10),

          ],
        ),
      ),
    );
  }


  Widget _infoRow(String title, String value, Color titleColor, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: titleColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 16, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


  Widget _sectionTitle(String title, Color textColor) {
    return Row(
      children: [
        Icon(Icons.playlist_add_check, color: textColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textColor, // was hardcoded Colors.black87
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }



  Widget _actionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color textColor,
        required VoidCallback onTap,
      }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onTap,
    );
  }
}
