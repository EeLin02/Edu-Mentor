import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentQuizzesScreen extends StatelessWidget {
  final String sectionId;
  final String subjectId;
  final String studentId;
  final Color color;

  const StudentQuizzesScreen({
    super.key,
    required this.sectionId,
    required this.subjectId,
    required this.studentId,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLight = color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Quizzes", style: TextStyle(color: textColor)),
        backgroundColor: color,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("quizzes")
            .where("sectionId", isEqualTo: sectionId)
            .where("subjectId", isEqualTo: subjectId)
            .orderBy("publishDate", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final quizzes = snapshot.data!.docs;
          if (quizzes.isEmpty) {
            return const Center(
              child: Text("No quizzes available yet.", style: TextStyle(fontSize: 16)),
            );
          }

          // Group quizzes by category
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (var quiz in quizzes) {
            final data = quiz.data() as Map<String, dynamic>;
            final category = data["category"] ?? "Uncategorized";
            grouped.putIfAbsent(category, () => []);
            grouped[category]!.add(quiz);
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: grouped.entries.map((entry) {
              final category = entry.key;
              final categoryQuizzes = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  backgroundColor: Colors.grey[50],
                  collapsedBackgroundColor: Colors.grey[100],
                  title: Row(
                    children: [
                      const Icon(Icons.category, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  children: categoryQuizzes.map((quiz) {
                    final data = quiz.data() as Map<String, dynamic>;
                    final quizId = quiz.id;
                    final title = data["title"] ?? "Untitled Quiz";
                    final publishDate = (data["publishDate"] as Timestamp).toDate();
                    final now = DateTime.now();
                    final isAvailable =
                        publishDate.isBefore(now) || publishDate.isAtSameMomentAs(now);

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection("quizzes")
                          .doc(quizId)
                          .collection("submissions")
                          .doc(studentId)
                          .get(),
                      builder: (context, submissionSnap) {
                        bool attempted =
                            submissionSnap.hasData && submissionSnap.data!.exists;
                        int score = 0, total = 0;
                        if (attempted) {
                          score = submissionSnap.data?["score"] ?? 0;
                          total = submissionSnap.data?["total"] ?? 0;
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAvailable ? color : Colors.grey,
                              child: const Icon(Icons.quiz, color: Colors.white),
                            ),
                            title: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  "Published: ${DateFormat('dd MMM yyyy').format(publishDate)}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                attempted
                                    ? Chip(
                                  label: Text("✅ Completed (Score: $score/$total)"),
                                  backgroundColor: Colors.green.shade100,
                                  labelStyle:
                                  const TextStyle(color: Colors.green),
                                )
                                    : isAvailable
                                    ? Chip(
                                  label: const Text("❌ Not Attempted"),
                                  backgroundColor: Colors.red.shade100,
                                  labelStyle:
                                  const TextStyle(color: Colors.red),
                                )
                                    : Chip(
                                  label: const Text("⏳ Not yet available"),
                                  backgroundColor: Colors.orange.shade100,
                                  labelStyle:
                                  const TextStyle(color: Colors.orange),
                                ),
                              ],
                            ),
                            trailing: isAvailable
                                ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                attempted ? Colors.green : color,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/takeQuiz',
                                  arguments: {
                                    "quizId": quizId,
                                    "studentId": studentId,
                                    "sectionId": sectionId,
                                    "subjectId": subjectId,
                                    "color": color,
                                    "title": title,
                                  },
                                );
                              },
                              child: Text(attempted ? "View" : "Start"),
                            )
                                : null,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
