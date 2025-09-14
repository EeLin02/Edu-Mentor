import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TakeQuizScreen extends StatefulWidget {
  final String quizId;
  final String studentId;
  final String classId;
  final String subjectId;
  final Color color;
  final String title;

  const TakeQuizScreen({
    super.key,
    required this.quizId,
    required this.studentId,
    required this.classId,
    required this.subjectId,
    required this.color,
    required this.title,
  });

  @override
  State<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> {
  Map<String, dynamic> answers = {};
  Map<String, bool> correctness = {};
  Map<String, TextEditingController> controllers = {};
  int score = 0;
  int total = 0;
  bool submitted = false;

  // Hold info about next quiz
  DocumentSnapshot? nextQuizDoc;

  @override
  void initState() {
    super.initState();
    _fetchNextQuiz();
    _loadPreviousSubmission();
  }

  @override
  void dispose() {
    for (var c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }


  Future<void> _fetchNextQuiz() async {
    // Find the next quiz by publishDate > current quiz
    final currentQuiz =
    await FirebaseFirestore.instance.collection("quizzes").doc(widget.quizId).get();

    if (!currentQuiz.exists) return;

    final currentPublishDate = (currentQuiz["publishDate"] as Timestamp).toDate();

    final nextQuizSnapshot = await FirebaseFirestore.instance
        .collection("quizzes")
        .where("classId", isEqualTo: widget.classId)
        .where("subjectId", isEqualTo: widget.subjectId)
        .where("publishDate", isGreaterThan: currentPublishDate)
        .orderBy("publishDate")
        .limit(1)
        .get();

    if (nextQuizSnapshot.docs.isNotEmpty) {
      setState(() {
        nextQuizDoc = nextQuizSnapshot.docs.first;
      });
    }
  }

  Future<void> _loadPreviousSubmission() async {
    final submissionDoc = await FirebaseFirestore.instance
        .collection("quizzes")
        .doc(widget.quizId)
        .collection("submissions")
        .doc(widget.studentId)
        .get();

    if (submissionDoc.exists) {
      final data = submissionDoc.data()!;
      final restoredAnswers = Map<String, dynamic>.from(data["answers"] ?? {});

      setState(() {
        score = data["score"] ?? 0;
        total = data["total"] ?? 0;
        submitted = true;
        answers = restoredAnswers;
      });

      //  update controllers so UI shows the restored answer
      restoredAnswers.forEach((questionId, ans) {
        if (controllers.containsKey(questionId)) {
          controllers[questionId]!.text = ans.toString();
        } else {
          controllers[questionId] = TextEditingController(text: ans.toString());
        }
      });
    }
  }



  Future<void> submitQuiz(List<DocumentSnapshot> questions) async {
    int newScore = 0;
    int totalQuestions = questions.length;
    correctness.clear(); // reset each attempt

    for (var q in questions) {
      final questionId = q.id;
      final type = q["type"] ?? "multiple_choice";
      final correctAnswer = q["correctAnswer"];
      bool isCorrect = false;

      if (type == "multiple_choice") {
        final options = List<String>.from(q["options"] ?? []);
        final selectedIndex = answers[questionId] is int
            ? answers[questionId] as int
            : (answers[questionId] is num ? (answers[questionId] as num).toInt() : null);

        if (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < options.length) {
          final selectedValue = options[selectedIndex];
          if (selectedValue.toString().trim().toLowerCase() ==
              correctAnswer.toString().trim().toLowerCase()) {
            isCorrect = true;
          }
        }
      } else if (type == "fill_blank") {
        final studentAnswer = answers[questionId];
        if (studentAnswer != null) {
          final normalizedStudent = studentAnswer.toString().trim().toLowerCase();
          final normalizedCorrect = correctAnswer.toString().trim().toLowerCase();

          if (normalizedStudent == normalizedCorrect) {
            isCorrect = true;
          }
        }
      }

      if (isCorrect) newScore++;
      correctness[questionId] = isCorrect;
    }

    setState(() {
      score = newScore;
      total = totalQuestions;
      submitted = true;
    });

    //Fetch student info from Firestore
    final studentDoc = await FirebaseFirestore.instance
        .collection("students")
        .doc(widget.studentId)
        .get();

    String studentName = studentDoc["name"] ?? "Unknown";
    String studentProfileUrl = studentDoc["profileUrl"] ?? "";
    String studentIdNo = studentDoc["studentIdNo"] ?? widget.studentId;

    await FirebaseFirestore.instance
        .collection("quizzes")
        .doc(widget.quizId)
        .collection("submissions")
        .doc(widget.studentId)
        .set({
      "score": newScore,
      "total": totalQuestions,
      "answers": answers,
      "submittedAt": FieldValue.serverTimestamp(),
      "studentId": widget.studentId,
      "studentIdNo": studentIdNo,
      "studentName": studentName,
      "studentProfileUrl": studentProfileUrl,
    }, SetOptions(merge: true));
  }


  Future<void> retryQuiz() async {
    setState(() {
      answers.clear();
      correctness.clear();
      score = 0;
      total = 0;
      submitted = false;

      // Clear all text controllers too
      for (var controller in controllers.values) {
        controller.clear();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final bool isLight = widget.color.computeLuminance() > 0.5;
    final Color textColor = isLight ? Colors.black87 : Colors.white;

    DateTime? nextQuizPublishDate;
    bool nextQuizAvailable = false;
    String nextQuizId = "";

    if (nextQuizDoc != null) {
      nextQuizPublishDate = (nextQuizDoc!['publishDate'] as Timestamp).toDate();
      nextQuizAvailable = nextQuizPublishDate.isBefore(DateTime.now());
      nextQuizId = nextQuizDoc!.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: textColor)),
        backgroundColor: widget.color,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("quizzes")
            .doc(widget.quizId)
            .collection("questions")
            .orderBy("createdAt")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final questions = snapshot.data!.docs;
          if (questions.isEmpty) {
            return const Center(child: Text("No questions in this quiz."));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var q in questions) _buildQuestionCard(q),
              const SizedBox(height: 20),
              if (!submitted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: textColor,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => submitQuiz(questions),
                  child: const Text("Submit Quiz"),
                )
              else
                Column(
                  children: [
                    Text(
                      "Your Score: $score / $total",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Retry button (always available)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: retryQuiz,
                      child: const Text("Retry Quiz"),
                    ),

                    const SizedBox(height: 12),

                    // Next Quiz button
                    ElevatedButton(
                      onPressed: (score >= (total * 0.6) &&
                          nextQuizDoc != null &&
                          nextQuizAvailable)
                          ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TakeQuizScreen(
                              quizId: nextQuizId,
                              studentId: widget.studentId,
                              classId: widget.classId,
                              subjectId: widget.subjectId,
                              color: widget.color,
                              title: nextQuizDoc!["title"] ?? "Next Quiz",
                            ),
                          ),
                        );
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (score >= (total * 0.6) &&
                            nextQuizDoc != null &&
                            nextQuizAvailable)
                            ? widget.color
                            : Colors.grey,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(
                        (score < (total * 0.6))
                            ? "Next Quiz Locked (Need 60%)"
                            : (nextQuizDoc == null
                            ? "No Next Quiz"
                            : (nextQuizAvailable
                            ? "Go to Next Quiz"
                            : "Next Quiz Not Yet Available")),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestionCard(DocumentSnapshot q) {
    final questionId = q.id;
    final text = q["question"] ?? "Untitled Question";
    final type = q["type"] ?? "multiple_choice";
    final correctAnswer = q["correctAnswer"];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            if (type == "multiple_choice")
              ..._buildMultipleChoiceOptions(q, questionId, correctAnswer),

            if (type == "fill_blank")
              _buildFillInBlank(q, questionId, correctAnswer),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMultipleChoiceOptions(
      DocumentSnapshot q, String questionId, String correctAnswer) {
    final options = List<String>.from(q["options"] ?? []);
    final selectedIndex = answers[questionId] is int
        ? answers[questionId] as int
        : (answers[questionId] is num ? (answers[questionId] as num).toInt() : null);


    return [
      for (int i = 0; i < options.length; i++)
        RadioListTile<int>(
          value: i,
          groupValue: selectedIndex,
          title: Text(options[i]),
          onChanged: submitted
              ? null
              : (val) {
            setState(() {
              answers[questionId] = val!;
            });
          },
          secondary: submitted
              ? Icon(
            options[i] == correctAnswer
                ? Icons.check_circle
                : (selectedIndex == i && options[i] != correctAnswer
                ? Icons.cancel
                : null),
            color: options[i] == correctAnswer
                ? Colors.green
                : (selectedIndex == i ? Colors.red : Colors.grey),
          )
              : null,
        ),
      if (submitted && selectedIndex != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            selectedIndex != null && options[selectedIndex] == correctAnswer
                ? "You answered correctly ✅"
                : "Your answer: ${options[selectedIndex]} ❌ | Correct: $correctAnswer",
            style: TextStyle(
              color: selectedIndex != null &&
                  options[selectedIndex] == correctAnswer
                  ? Colors.green
                  : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
    ];
  }

  Widget _buildFillInBlank(
      DocumentSnapshot q, String questionId, String correctAnswer) {

    // Ensure controller exists
    controllers.putIfAbsent(
      questionId,
          () => TextEditingController(text: answers[questionId]?.toString() ?? ""),
    );

    // keep controller text in sync with answers map
    if (answers.containsKey(questionId) &&
        controllers[questionId]!.text != answers[questionId].toString()) {
      controllers[questionId]!.text = answers[questionId].toString();
    }

    final controller = controllers[questionId]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: !submitted,
          onChanged: (val) {
            answers[questionId] = val;
          },
          decoration: const InputDecoration(
            labelText: "Your Answer",
            border: OutlineInputBorder(),
          ),
        ),
        if (submitted)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              controller.text.trim().toLowerCase() ==
                  correctAnswer.toString().trim().toLowerCase()
                  ? "You answered correctly ✅"
                  : "Your answer: ${controller.text} ❌ | Correct: $correctAnswer",
              style: TextStyle(
                color: controller.text.trim().toLowerCase() ==
                    correctAnswer.toString().trim().toLowerCase()
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
