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
          if (submissionSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!submissionSnap.hasData || !submissionSnap.data!.exists) {
            return const Center(child: Text("Submission not found."));
          }

          final submissionData =
          submissionSnap.data!.data() as Map<String, dynamic>;
          final answersMap =
          Map<String, dynamic>.from(submissionData["answers"] ?? {});
          final correctnessMap =
          Map<String, dynamic>.from(submissionData["correctness"] ?? {});
          final studentId = submissionData["studentId"];

          if (studentId == null) {
            return const Center(child: Text("Student ID missing in submission."));
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection("students")
                .doc(studentId)
                .get(),
            builder: (context, studentSnap) {
              if (studentSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final studentData =
                  studentSnap.data?.data() as Map<String, dynamic>? ?? {};
              final studentName = studentData["name"] ?? "Unknown";
              final studentIdNo = studentData["studentIdNo"] ?? "N/A";
              final profileUrl = studentData["profileUrl"];

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection("quizzes")
                    .doc(quizId)
                    .collection("questions")
                    .orderBy("createdAt", descending: false)
                    .get(),
                builder: (context, questionSnap) {
                  if (questionSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final questions = questionSnap.data?.docs ?? [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🧑‍🎓 Student Info Header
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                              ? NetworkImage(profileUrl)
                              : null,
                          child: (profileUrl == null || profileUrl.isEmpty)
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          studentName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text("Student ID: $studentIdNo"),
                        const SizedBox(height: 6),
                        Text(
                          "Score: ${submissionData["score"] ?? 0}/${submissionData["total"] ?? questions.length}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Divider(height: 32, thickness: 1),

                        // 🧩 Questions List
                        ...questions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final q = entry.value;
                          final qId = q.id;

                          final questionText = q["question"] ?? "Untitled question";
                          final type = q["type"] ?? "multiple_choice";
                          final options = List<String>.from(q["options"] ?? []);
                          final correctAnswerRaw = q["correctAnswer"];

                          // Handle correct answer(s)
                          String correctAnswerDisplay = "";
                          if (correctAnswerRaw is List) {
                            // Multiple correct answers (indices or text)
                            final list = correctAnswerRaw.map((a) {
                              if (a is int && a >= 0 && a < options.length) {
                                return options[a];
                              }
                              return a.toString();
                            }).toList();
                            correctAnswerDisplay = list.join(", ");
                          } else if (correctAnswerRaw is int) {
                            correctAnswerDisplay = (correctAnswerRaw >= 0 &&
                                correctAnswerRaw < options.length)
                                ? options[correctAnswerRaw]
                                : correctAnswerRaw.toString();
                          } else {
                            correctAnswerDisplay =
                                correctAnswerRaw?.toString() ?? "(No Correct Answer)";
                          }

                          // Handle student's submitted answer
                          final studentRawAnswer = answersMap[qId];
                          String studentAnswer = "(No Answer)";

                          if (type == "multiple_choice") {
                            if (studentRawAnswer is List) {
                              // assume array of strings
                              final selected = studentRawAnswer.whereType<String>().toList();
                              if (selected.isNotEmpty) {
                                studentAnswer = selected.join(", ");
                              }
                            } else if (studentRawAnswer is String) {
                              studentAnswer = studentRawAnswer;
                            }
                          } else if (type == "fill_blank") {
                            studentAnswer = studentRawAnswer?.toString() ?? "(No Answer)";
                          }



                          final bool isCorrect = correctnessMap[qId] == true;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Text(
                                "Q${index + 1}: $questionText",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Student Answer: $studentAnswer"),
                                    Text("Correct Answer: $correctAnswerDisplay"),
                                  ],
                                ),
                              ),
                              trailing: Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: 28,
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
          );
        },
      ),
    );
  }
}
