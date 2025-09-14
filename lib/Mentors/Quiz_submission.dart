import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubmissionDetailScreen extends StatelessWidget {
  final String quizTitle;
  final String quizId;
  final String submissionId;

  const SubmissionDetailScreen({
    Key? key,
    required this.quizTitle,
    required this.quizId,
    required this.submissionId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Submission Detail")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection("quizzes")
            .doc(quizId)
            .collection("submissions")
            .doc(submissionId)
            .get(),
        builder: (context, submissionSnap) {
          if (!submissionSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final submissionData =
          submissionSnap.data!.data() as Map<String, dynamic>;
          final answersMap =
          Map<String, dynamic>.from(submissionData["answers"] ?? {});

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection("quizzes")
                .doc(quizId)
                .collection("questions")
                .orderBy("createdAt")
                .get(),
            builder: (context, questionSnap) {
              if (!questionSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final questions = questionSnap.data!.docs;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (submissionData["studentProfileUrl"] != null)
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(
                            submissionData["studentProfileUrl"]),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      submissionData["studentName"] ?? "Unknown",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Score: ${submissionData["score"]}/${submissionData["total"]}",
                      style: const TextStyle(
                          fontSize: 16, color: Colors.blue),
                    ),
                    const Divider(height: 32),

                    // Show each question with student's answer
                    ...questions.map((q) {
                      final qId = q.id;
                      final questionText = q["question"] ?? "Untitled";
                      final type = q["type"] ?? "multiple_choice";
                      final correctAnswer = q["correctAnswer"]?.toString() ?? "";
                      final options =
                      List<String>.from(q["options"] ?? []);

                      // student's raw answer (index or string)
                      final studentRawAnswer = answersMap[qId];

                      String studentAnswer = "";
                      if (type == "multiple_choice") {
                        if (studentRawAnswer is int &&
                            studentRawAnswer >= 0 &&
                            studentRawAnswer < options.length) {
                          studentAnswer = options[studentRawAnswer];
                        } else {
                          studentAnswer = "(No Answer)";
                        }
                      } else if (type == "fill_blank") {
                        studentAnswer = studentRawAnswer?.toString() ?? "";
                      }

                      final bool isCorrect =
                          studentAnswer.trim().toLowerCase() ==
                              correctAnswer.trim().toLowerCase();

                      return Card(
                        child: ListTile(
                          title: Text(questionText),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Your Answer: $studentAnswer"),
                              Text("Correct Answer: $correctAnswer"),
                            ],
                          ),
                          trailing: Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? Colors.green : Colors.red,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
