import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentSubjectSectionsDetailsScreen extends StatefulWidget {
  final String sectionId;
  final String subjectId;
  final String studentId;
  final String schoolId;
  final String programmeId;
  final Color color;

  const StudentSubjectSectionsDetailsScreen({
    super.key,
    required this.sectionId,
    required this.subjectId,
    required this.studentId,
    required this.schoolId,
    required this.programmeId,
    required this.color,
  });


  @override
  State<StudentSubjectSectionsDetailsScreen> createState() =>
      _StudentSubjectClassDetailsScreenState();
}

class _StudentSubjectClassDetailsScreenState
    extends State<StudentSubjectSectionsDetailsScreen> {
  String subjectName = '';
  String subjectCode = '';
  String sectionName = '';
  String mentorId = '';
  String mentorName = '';
  Color color = Colors.blue;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    color = widget.color;
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    try {
      final schoolsSnapshot =
      await FirebaseFirestore.instance.collection('schools').get();

      for (var dept in schoolsSnapshot.docs) {
        final subjectDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('programmes')
            .doc(widget.programmeId)
            .collection('subjects')
            .doc(widget.subjectId)
            .get();

        if (subjectDoc.exists) {
          final subjectNameFromDb = subjectDoc.data()?['name'] ?? 'Unknown Subject';
          final subjectCodeFromDb = subjectDoc.data()?['code'] ?? '';


          final sectionDoc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('programmes')
              .doc(widget.programmeId)
              .collection('subjects')
              .doc(widget.subjectId)
              .collection('sections')
              .doc(widget.sectionId)
              .get();

          if (sectionDoc.exists) {
            String fetchedMentorId = '';

            final mentorQuery = await FirebaseFirestore.instance
                .collection('subjectMentors')
                .where('schoolId', isEqualTo: widget.schoolId)
                .where('programmeId', isEqualTo: widget.programmeId)
                .where('subjectId', isEqualTo: widget.subjectId)
                .where('sectionId', isEqualTo: widget.sectionId)
                .get();


            print('[DEBUG] subjectMentors result count = ${mentorQuery.docs.length}');

            if (mentorQuery.docs.isNotEmpty) {
              fetchedMentorId = mentorQuery.docs.first.data()?['mentorId'] ?? '';
              print('[DEBUG] fetchedMentorId = $fetchedMentorId');
            } else {
              print('[DEBUG] No matching subjectMentors document found.');
            }

            final sectionNameFromDb = sectionDoc.data()?['name'] ?? 'Unknown Class';

            Color updatedColor = widget.color;
            if (fetchedMentorId.isNotEmpty) {
              final customizationDoc = await FirebaseFirestore.instance
                  .collection('studentCustomizations')
                  .doc('${fetchedMentorId}_${widget.sectionId}')
                  .get();

              if (customizationDoc.exists && customizationDoc.data()?['color'] != null) {
                final colorValue =
                int.tryParse(customizationDoc['color'].toString());
                if (colorValue != null) {
                  updatedColor = Color(colorValue);
                }
              }
            }

            String fetchedMentorName = '';
            if (fetchedMentorId.isNotEmpty) {
              final mentorDoc = await FirebaseFirestore.instance
                  .collection('mentors')
                  .doc(fetchedMentorId)
                  .get();
              if (mentorDoc.exists) {
                fetchedMentorName = mentorDoc.data()?['name'] ?? '';
              }
            } else {
              print('[WARNING] mentorId is empty — skipping mentor name fetch.');
            }

            setState(() {
              subjectName = subjectNameFromDb;
              subjectCode = subjectCodeFromDb;
              sectionName = sectionNameFromDb;
              mentorId = fetchedMentorId;
              mentorName = fetchedMentorName;
              color = updatedColor;
              isLoading = false;
            });
            return;
          }
        }
      }

      setState(() {
        subjectName = 'Not Found';
        sectionName = 'Not Found';
        isLoading = false;
      });
    } catch (e) {
      print('[ERROR] fetchDetails failed: $e');
      setState(() {
        subjectName = 'Error';
        sectionName = 'Error';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;


    return Scaffold(
      appBar: AppBar(
        title: Text(
          isLoading ? 'Loading...' : '$subjectName · $subjectCode · $sectionName',
          style: TextStyle(color: textColor),
        ),
        backgroundColor: color,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoCard(textColor),
            const SizedBox(height: 30),
            _sectionTitle('Home Page',
              Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
            ),
            const SizedBox(height: 14),
            _actionButton(
              icon: Icons.campaign_outlined,
              label: 'View Announcements',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/studentAnnouncement',
                  arguments: {
                    'subjectId': widget.subjectId,
                    'subjectName': subjectName,
                    'sectionId': widget.sectionId,
                    'sectionName': sectionName,
                    'color': color,
                  },
                );
              },
            ),

            const SizedBox(height: 14),
            _actionButton(
              icon: Icons.chat_bubble_outline,
              label: 'Chat with Mentor',
              textColor: textColor,
              onTap: () {
                if (mentorId.isEmpty) {
                  print('[ERROR] mentorId is empty, cannot navigate to chat.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Mentor not assigned yet.')),
                  );
                  return;
                }

                Navigator.pushNamed(
                  context,
                  '/studentClassChat',
                  arguments: {
                    'subjectId': widget.subjectId,
                    'sectionId': widget.sectionId,
                    'subjectName': subjectName,
                    'sectionName': sectionName,
                    'mentorId': mentorId,
                    'color': color,
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            _actionButton(
              icon: Icons.folder_copy_outlined,
              label: 'Shared Resources',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(context, '/studentShareResources', arguments: {
                  'subjectName': subjectName,
                  'sectionName': sectionName,
                  'color': color,
                });
              },
            ),

            const SizedBox(height: 14),
            _actionButton(
              icon: Icons.sticky_note_2_outlined,
              label: 'Notes',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(context, '/studentNotes', arguments: {
                  'subjectName': subjectName,
                  'sectionName': sectionName,
                  'color': color,
                });
              },
            ),

            const SizedBox(height: 14),
            _actionButton(
              icon: Icons.dataset,
              label: 'Attendance Records',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/studentAttendanceRecords',
                  arguments: {
                    'sectionId': widget.sectionId,
                    'subjectId': widget.subjectId,
                    'studentId': widget.studentId, // from list or Firestore query
                    'color': widget.color,
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            _actionButton(
              icon: Icons.quiz_outlined,
              label: 'Quizzes',
              textColor: textColor,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/studentQuizzes',
                  arguments: {
                    'sectionId': widget.sectionId,
                    'subjectId': widget.subjectId,
                    'studentId': widget.studentId,
                    'color': color,
                  },
                );
              },
            ),


          ],
        ),
      ),
    );
  }



  Widget _infoCard(Color textColor) {
    final Color valueColor = textColor.withOpacity(0.7);
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _infoRow('Subject:', subjectName, textColor, valueColor),
            const SizedBox(height: 10),
            _infoRow('Section:', sectionName, textColor, valueColor),
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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: titleColor),
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

  Widget _actionButton({
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
    );
  }
}
