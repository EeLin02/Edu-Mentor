import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TakeQuizScreen extends StatefulWidget {
  final String quizId;
  final String studentId;
  final String sectionId;
  final String subjectId;
  final Color color;
  final String title;

  const TakeQuizScreen({
    super.key,
    required this.quizId,
    required this.studentId,
    required this.sectionId,
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
    try {
      final quizDoc = await FirebaseFirestore.instance
          .collection("quizzes")
          .doc(widget.quizId)
          .get();

      if (!quizDoc.exists) return;

      final quizData = quizDoc.data() as Map<String, dynamic>;
      final DateTime currentPublishDate =
      (quizData["publishDate"] as Timestamp).toDate();

      final String category = quizData["category"] ?? "Uncategorized";
      final String sectionId = quizData["sectionId"];
      final String subjectId = quizData["subjectId"];

      // Query for next quiz in SAME category, section, subject
      final querySnap = await FirebaseFirestore.instance
          .collection("quizzes")
          .where("sectionId", isEqualTo: sectionId)
          .where("subjectId", isEqualTo: subjectId)
          .where("category", isEqualTo: category)
          .where("publishDate", isGreaterThan: currentPublishDate)
          .orderBy("publishDate")
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        setState(() {
          nextQuizDoc = querySnap.docs.first; // just store it
        });
      } else {
        setState(() {
          nextQuizDoc = null; // no more quizzes
        });
      }
    } catch (e) {
      debugPrint("Error fetching next quiz: $e");
    }
  }




  Future<void> _loadPreviousSubmission() async {
    final submissionDoc = await FirebaseFirestore.instance
        .collection("quizzes")
        .doc(widget.quizId)
        .collection("submissions")
        .doc(widget.studentId)
        .get();

    if (!submissionDoc.exists) return;

    final data = submissionDoc.data()!;
    final restoredAnswers = Map<String, dynamic>.from(data["answers"] ?? {});
    final restoredCorrectness = Map<String, bool>.from(data["correctness"] ?? {});

    setState(() {
      score = data["score"] ?? 0;
      total = data["total"] ?? 0;
      submitted = true;
      answers = {};
      correctness = restoredCorrectness;
    });

    // 🔹 Rebuild the answers map in the proper index form for MCQs
    final questionsSnap = await FirebaseFirestore.instance
        .collection("quizzes")
        .doc(widget.quizId)
        .collection("questions")
        .get();

    for (var q in questionsSnap.docs) {
      final questionId = q.id;
      final type = q["type"] ?? "multiple_choice";
      final List<String> options =
      (q["options"] != null) ? List<String>.from(q["options"]) : [];

      if (!restoredAnswers.containsKey(questionId)) continue;

      final savedAns = restoredAnswers[questionId];

      if (type == "multiple_choice") {
        final allowMultiple = q["allowMultiple"] == true;

        if (allowMultiple) {
          // MULTIPLE ANSWERS (array of strings)
          if (savedAns is List) {
            answers[questionId] = savedAns
                .map((ans) => options
                .indexWhere((opt) => opt.toLowerCase() == ans.toString().toLowerCase()))
                .where((i) => i >= 0)
                .toList();
          }
        } else {
          // SINGLE ANSWER (string)
          if (savedAns is String) {
            final idx = options
                .indexWhere((opt) => opt.toLowerCase() == savedAns.toLowerCase());
            if (idx != -1) answers[questionId] = idx;
          }
        }
      } else if (type == "fill_blank") {
        answers[questionId] = savedAns.toString();
        controllers.putIfAbsent(
          questionId,
              () => TextEditingController(text: savedAns.toString()),
        );
      }
    }
  }




  Future<void> submitQuiz(List<DocumentSnapshot> questions) async {
    int newScore = 0;
    int totalQuestions = questions.length;
    correctness.clear();

    final normalizedAnswers = <String, dynamic>{};

    for (var q in questions) {
      final questionId = q.id;
      final type = q["type"] ?? "multiple_choice";
      final List<String> options =
      (q["options"] != null) ? List<String>.from(q["options"]) : [];

      // Normalize correct answers to lowercase list
      final rawAnswer = q["correctAnswer"];
      final List<String> correctAnswers = (rawAnswer is List)
          ? rawAnswer.map((e) => e.toString().trim().toLowerCase()).toList()
          : [rawAnswer?.toString().trim().toLowerCase() ?? ""];

      bool isCorrect = false;

      if (type == "multiple_choice") {
        final allowMultiple = q["allowMultiple"] == true;

        if (allowMultiple) {
          // MULTIPLE CHOICE (multiple answers)
          final selectedIndexes = (answers[questionId] is List)
              ? List<int>.from(answers[questionId])
              : <int>[];

          final selectedValues = selectedIndexes
              .where((i) => i >= 0 && i < options.length)
              .map((i) => options[i].toString().trim().toLowerCase())
              .toList();

          isCorrect = selectedValues.toSet().containsAll(correctAnswers) &&
              correctAnswers.toSet().containsAll(selectedValues);

          // Store readable answer
          normalizedAnswers[questionId] = selectedValues;
        } else {
          // MULTIPLE CHOICE (single answer)
          final selectedIndex = answers[questionId] is int
              ? answers[questionId] as int
              : (answers[questionId] is num
              ? (answers[questionId] as num).toInt()
              : null);

          if (selectedIndex != null &&
              selectedIndex >= 0 &&
              selectedIndex < options.length) {
            final selectedValue =
            options[selectedIndex].toString().trim().toLowerCase();
            isCorrect = correctAnswers.contains(selectedValue);
            normalizedAnswers[questionId] = options[selectedIndex];
          } else {
            normalizedAnswers[questionId] = null;
          }
        }
      } else if (type == "fill_blank") {
        // FILL IN THE BLANK
        final studentAnswer = answers[questionId];
        if (studentAnswer != null) {
          final normalizedStudent =
          studentAnswer.toString().trim().toLowerCase();
          isCorrect = correctAnswers.contains(normalizedStudent);
          normalizedAnswers[questionId] = studentAnswer.toString();
        } else {
          normalizedAnswers[questionId] = "";
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

    // 🔹 Save submission
    await FirebaseFirestore.instance
        .collection("quizzes")
        .doc(widget.quizId)
        .collection("submissions")
        .doc(widget.studentId)
        .set({
      "score": newScore,
      "total": totalQuestions,
      "answers": normalizedAnswers, // 🔹 Readable format
      "correctness": correctness,
      "submittedAt": FieldValue.serverTimestamp(),
      "studentId": widget.studentId,
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
                      total > 0
                          ? "Score: $score / $total (${(score / total * 100).toStringAsFixed(1)}%)"
                          : "Score: 0 / 0 (0%)",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Retry button
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
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TakeQuizScreen(
                              quizId: nextQuizId,
                              studentId: widget.studentId,
                              sectionId: widget.sectionId,
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
                        foregroundColor: Colors.white,
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
    final dynamic rawAnswer = q["correctAnswer"];
    final String correctAnswer = (rawAnswer is List && rawAnswer.isNotEmpty)
        ? rawAnswer.first.toString()
        : rawAnswer?.toString() ?? "";
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
      final allowMultiple = q["allowMultiple"] == true;

      if (allowMultiple) {
        final selectedIndexes = (answers[questionId] is List)
            ? List<int>.from(answers[questionId])
            : <int>[];

        return [
          for (int i = 0; i < options.length; i++)
            CheckboxListTile(
              value: selectedIndexes.contains(i),
              title: Text(options[i]),
              onChanged: submitted
                  ? null
                  : (val) {
                setState(() {
                  if (val == true) {
                    selectedIndexes.add(i);
                  } else {
                    selectedIndexes.remove(i);
                  }
                  answers[questionId] = selectedIndexes;
                });
              },
            ),
          if (submitted)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                correctness[questionId] == true
                    ? "Correct ✅"
                    : "Incorrect ❌ | Correct answers: ${List<String>.from(q["correctAnswer"]).join(", ")}",
                style: TextStyle(
                  color: correctness[questionId] == true ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ];
      } else {
        // Keep your existing RadioListTile logic for single-choice
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
            ),
          if (submitted && selectedIndex != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                correctness[questionId] == true
                    ? "You answered correctly ✅"
                    : "Your answer: ${options[selectedIndex]} ❌ | Correct: $correctAnswer",
                style: TextStyle(
                  color: correctness[questionId] == true ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ];
      }
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
              correctness[questionId] == true
                  ? "You answered correctly ✅"
                  : "Your answer: ${controller.text} ❌ | Correct: ${q["correctAnswer"]}",
              style: TextStyle(
                color: correctness[questionId] == true ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

      ],
    );
  }
}
