import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'Quiz_submission.dart';
import 'package:fl_chart/fl_chart.dart';

class WeeklyQuizScreen extends StatefulWidget {
  final String subjectId;
  final String classId;
  final String mentorId;
  final String subjectName;
  final String className;
  final Color color;

  const WeeklyQuizScreen({
    Key? key,
    required this.subjectId,
    required this.classId,
    required this.mentorId,
    required this.subjectName,
    required this.className,
    required this.color,
  }) : super(key: key);

  @override
  State<WeeklyQuizScreen> createState() => _WeeklyQuizScreenState();
}

class _WeeklyQuizScreenState extends State<WeeklyQuizScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _publishDate;

  final List<Map<String, dynamic>> _questions = [];
  String? _editingQuizId; // null = creating new

  List<String> _categories = [];
  String? _selectedCategory;

  String _searchQuery = "";
  String _filterCategory = "All";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.color.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Weekly Quiz - ${widget.subjectName}",
          style: TextStyle(color: textColor),
        ),
        backgroundColor: widget.color,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: textColor,
          labelColor: textColor,
          unselectedLabelColor: isLight ? Colors.black54 : Colors.white70,
          tabs: const [
            Tab(text: "Create/Edit Quiz", icon: Icon(Icons.add_circle_outline)),
            Tab(text: "Quizzes List", icon: Icon(Icons.list_alt_outlined)),
            Tab(text: "Submissions", icon: Icon(Icons.people_alt_outlined)),

          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateQuizTab(),
          _buildQuizListTab(),
          _buildSubmissionsTab(),
        ],
      ),
    );
  }

  // --- Create/Edit Quiz Form ---
  Widget _buildCreateQuizTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- Add / Manage Categories ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final controller = TextEditingController();
                      final result = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Add New Category"),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(hintText: "Enter category name"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                              child: const Text("Add"),
                            ),
                          ],
                        ),
                      );

                      if (result != null && result.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection("quizCategories")
                            .add({
                          "name": result,
                          "createdAt": FieldValue.serverTimestamp(),
                          "createdBy": FirebaseAuth.instance.currentUser!.uid,
                        });
                        _loadCategories();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Category"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _manageCategoriesDialog,
                    icon: const Icon(Icons.settings),
                    label: const Text("Manage"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- Quiz Title ---
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Quiz Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // --- Quiz Description ---
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // 🔹 Category Dropdown from Firestore
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("quizCategories")
                  .orderBy("createdAt")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final categories = snapshot.data!.docs
                    .map((d) => d["name"].toString())
                    .toList();

                if (_selectedCategory == null && categories.isNotEmpty) {
                  _selectedCategory = categories.first;
                }

                return DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(),
                  ),
                  items: categories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCategory = val);
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // --- Publish Date ---
            Row(
              children: [
                Expanded(
                  child: Text(
                    _publishDate == null
                        ? "No date selected"
                        : "Publish Date: ${_publishDate!.toLocal()}".split(' ')[0],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Pick Date"),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _publishDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Add/Edit Questions ---
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Question"),
                onPressed: () => _addOrEditQuestionDialog(),
              ),
            ),
            const SizedBox(height: 10),

            Column(
              children: _questions.map((q) {
                return Card(
                  child: ListTile(
                    title: Text(q['question']),
                    subtitle: Text("Type: ${q['type']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _addOrEditQuestionDialog(existing: q);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _questions.remove(q);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- Save / Update Quiz ---
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(_editingQuizId == null ? "Save Quiz" : "Update Quiz"),
              onPressed: _saveQuizToFirebase,
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("quizCategories")
        .orderBy("createdAt")
        .get();

    setState(() {
      _categories = snapshot.docs.map((d) => d["name"].toString()).toList();

      if (_selectedCategory == null && _categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }



  Future<void> _manageCategoriesDialog() async {
    final categoriesSnap =
    await FirebaseFirestore.instance.collection("quizCategories").get();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Manage Categories"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: categoriesSnap.docs.map((doc) {
              final category = doc["name"];
              return ListTile(
                title: Text(category),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✏️ Edit button
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
                        final controller = TextEditingController(text: category);

                        final newName = await showDialog<String>(
                          context: context,
                          builder: (editCtx) => AlertDialog(
                            title: const Text("Edit Category"),
                            content: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                labelText: "Category name",
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(editCtx),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(editCtx, controller.text.trim()),
                                child: const Text("Save"),
                              ),
                            ],
                          ),
                        );

                        if (newName != null &&
                            newName.isNotEmpty &&
                            newName != category) {
                          // update quizzes that use old name
                          final batch = FirebaseFirestore.instance.batch();

                          final quizSnap = await FirebaseFirestore.instance
                              .collection("quizzes")
                              .where("category", isEqualTo: category)
                              .get();

                          for (var quiz in quizSnap.docs) {
                            batch.update(quiz.reference, {"category": newName});
                          }

                          // update the category doc itself
                          batch.update(doc.reference, {"name": newName});

                          await batch.commit();
                          Navigator.pop(ctx); // close Manage dialog
                          _loadCategories(); // reload dropdown
                        }
                      },
                    ),

                    // 🗑️ Delete button
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (delCtx) => AlertDialog(
                            title: const Text("Delete Category"),
                            content: Text(
                                "Are you sure you want to delete \"$category\"?\n\nAll quizzes in this category will be moved to \"Uncategorized\"."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(delCtx, false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(delCtx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final batch = FirebaseFirestore.instance.batch();

                          final quizSnap = await FirebaseFirestore.instance
                              .collection("quizzes")
                              .where("category", isEqualTo: category)
                              .get();

                          for (var quiz in quizSnap.docs) {
                            batch.update(
                                quiz.reference, {"category": "Uncategorized"});
                          }

                          batch.delete(doc.reference);

                          await batch.commit();
                          Navigator.pop(ctx); // close Manage dialog
                          _loadCategories(); // reload dropdown
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // --- Add/Edit Question Dialog ---
  void _addOrEditQuestionDialog({Map<String, dynamic>? existing}) {
    final questionController =
    TextEditingController(text: existing?['question'] ?? "");
    final optionController = TextEditingController();
    String type = existing?['type'] ?? "multiple_choice";
    bool allowMultiple = existing?['allowMultiple'] ?? false;
    List<String> options = List<String>.from(existing?['options'] ?? []);
    dynamic correctAnswer = existing?['correctAnswer'] ?? (allowMultiple ? <String>[] : null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? "Add Question" : "Edit Question"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(
                      labelText: "Question",
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(
                          value: "multiple_choice",
                          child: Text("Multiple Choice")),
                      DropdownMenuItem(
                          value: "fill_blank", child: Text("Fill in the Blank")),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        type = val!;
                        correctAnswer = type == "multiple_choice"
                            ? (allowMultiple ? <String>[] : null)
                            : null;
                      });
                    },
                  ),

                  // For Multiple Choice
                  if (type == "multiple_choice") ...[
                    SwitchListTile(
                      title: const Text("Allow multiple correct answers"),
                      value: allowMultiple,
                      onChanged: (val) {
                        setDialogState(() {
                          allowMultiple = val;
                          correctAnswer =
                          allowMultiple ? <String>[] : null; // reset
                        });
                      },
                    ),
                    TextField(
                      controller: optionController,
                      decoration: const InputDecoration(
                        labelText: "Add Option",
                      ),
                      onSubmitted: (val) {
                        if (val.isNotEmpty) {
                          setDialogState(() {
                            options.add(val);
                            optionController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Show options with either Radio or Checkbox
                    ...options.map((o) {
                      if (allowMultiple) {
                        return CheckboxListTile(
                          title: Text(o),
                          value: (correctAnswer as List<String>).contains(o),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                (correctAnswer as List<String>).add(o);
                              } else {
                                (correctAnswer as List<String>).remove(o);
                              }
                            });
                          },
                        );
                      } else {
                        return RadioListTile<String>(
                          title: Text(o),
                          value: o,
                          groupValue: correctAnswer,
                          onChanged: (val) {
                            setDialogState(() {
                              correctAnswer = val;
                            });
                          },
                        );
                      }
                    }).toList(),
                  ],

                  // For Fill in the Blank
                  if (type == "fill_blank") ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Correct Answer",
                      ),
                      controller:
                      TextEditingController(text: correctAnswer ?? ""),
                      onChanged: (val) {
                        correctAnswer = val;
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (questionController.text.isNotEmpty &&
                      (type == "fill_blank"
                          ? correctAnswer != null && correctAnswer.isNotEmpty
                          : options.isNotEmpty &&
                          (allowMultiple
                              ? (correctAnswer as List).isNotEmpty
                              : correctAnswer != null))) {
                    setState(() {
                      if (existing != null) {
                        existing['question'] = questionController.text;
                        existing['type'] = type;
                        existing['allowMultiple'] = allowMultiple;
                        existing['options'] = options;
                        existing['correctAnswer'] = correctAnswer;
                      } else {
                        _questions.add({
                          "id": const Uuid().v4(),
                          "question": questionController.text,
                          "type": type,
                          "allowMultiple": allowMultiple,
                          "options": options,
                          "correctAnswer": correctAnswer,
                        });
                      }
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text(existing == null ? "Add" : "Update"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Save or Update to Firebase ---
  Future<void> _saveQuizToFirebase() async {
    if (_titleController.text.isEmpty ||
        _publishDate == null ||
        _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields & add questions")),
      );
      return;
    }

    final quizId = _editingQuizId ?? const Uuid().v4();
    final quizRef = FirebaseFirestore.instance.collection("quizzes").doc(quizId);

    // Save quiz metadata (without questions array)
    await quizRef.set({
      "quizId": quizId,
      "title": _titleController.text,
      "description": _descriptionController.text,
      "publishDate": _publishDate,
      "subjectId": widget.subjectId,
      "classId": widget.classId,
      "mentorId": widget.mentorId,
      "category": _selectedCategory ?? "Uncategorized",
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Save questions in subcollection
    final batch = FirebaseFirestore.instance.batch();
    final questionsRef = quizRef.collection("questions");

    // If editing, clear old questions first
    if (_editingQuizId != null) {
      final oldQuestions = await questionsRef.get();
      for (var doc in oldQuestions.docs) {
        batch.delete(doc.reference);
      }
    }

    // Add current questions
    for (var q in _questions) {
      final qRef = questionsRef.doc(q['id']);
      batch.set(qRef, {
        "question": q['question'],
        "type": q['type'],
        "allowMultiple": q['allowMultiple'],
        "options": q['options'],
        "correctAnswer": q['correctAnswer'],
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editingQuizId == null ? "Quiz saved successfully!" : "Quiz updated!",
        ),
      ),
    );

    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _publishDate = null;
      _questions.clear();
      _editingQuizId = null;
    });
  }

  // --- Quiz List from Firebase ---
  Widget _buildQuizListTab() {
    return Column(
      children: [
        // 🔹 Search + Filter row at top
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Search quizzes...",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.toLowerCase());
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterCategory,
                items: ["All", ..._categories].map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) {
                  setState(() => _filterCategory = val!);
                },
              ),
            ],
          ),
        ),

        // 🔹 Quizzes list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("quizzes")
                .where("mentorId", isEqualTo: widget.mentorId)
                .where("classId", isEqualTo: widget.classId)
                .where("subjectId", isEqualTo: widget.subjectId)
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var quizzes = snapshot.data!.docs;

              // Apply search filter
              quizzes = quizzes.where((doc) {
                final title = doc["title"].toString().toLowerCase();
                return title.contains(_searchQuery);
              }).toList();

              // Apply category filter
              if (_filterCategory != "All") {
                quizzes = quizzes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data["category"] ?? "Uncategorized"; // safe access
                  return category == _filterCategory;
                }).toList();
              }

              if (quizzes.isEmpty) {
                return const Center(child: Text("No quizzes found"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = quizzes[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.quiz_outlined),
                      title: Text(quiz["title"]),
                      subtitle: Text(
                          "Publish: ${quiz["publishDate"].toDate()}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              // Load quiz metadata into form
                              setState(() {
                                _editingQuizId = quiz.id;
                                _titleController.text = quiz["title"];
                                _descriptionController.text = quiz["description"];
                                _publishDate = quiz["publishDate"].toDate();
                                _selectedCategory = (quiz.data() as Map<String, dynamic>)["category"] ?? "Uncategorized";
                                _questions.clear();
                              });

                              // Fetch questions
                              final qSnap = await FirebaseFirestore.instance
                                  .collection("quizzes")
                                  .doc(quiz.id)
                                  .collection("questions")
                                  .orderBy("createdAt")
                                  .get();

                              setState(() {
                                _questions.addAll(qSnap.docs.map((d) => {
                                  "id": d.id,
                                  "question": d["question"],
                                  "type": d["type"],
                                  "allowMultiple": d["allowMultiple"],
                                  "options":
                                  List<String>.from(d["options"] ?? []),
                                  "correctAnswer": d["correctAnswer"],
                                }));
                              });

                              _tabController.animateTo(0); // switch to form
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection("quizzes")
                                  .doc(quiz.id)
                                  .delete();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Submissions Tab ---
  Widget _buildSubmissionsTab() {
    return Column(
      children: [
        // 🔹 Search + Filter row at top
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Search submissions...",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.toLowerCase());
                    },
                ),
    ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _filterCategory,
          items: ["All", ..._categories].map((c) {
            return DropdownMenuItem(value: c, child: Text(c));
          }).toList(),
          onChanged: (val) {
            setState(() => _filterCategory = val!);
            },
        ),
      ],
    ),
  ),
        // Submission list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("quizzes")
                .where("mentorId", isEqualTo: widget.mentorId)
                .where("classId", isEqualTo: widget.classId)
                .where("subjectId", isEqualTo: widget.subjectId)
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
    }

    var quizzes = snapshot.data!.docs;
    // ✅ Apply search filter
    quizzes = quizzes.where((doc) {
    final title = (doc.data() as Map<String, dynamic>)["title"]?.toString().toLowerCase() ?? "";
    return title.contains(_searchQuery);
    }).toList();

    // ✅ Apply category filter
    if (_filterCategory != "All") {
    quizzes = quizzes.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    return data.containsKey("category") && data["category"] == _filterCategory;
    }).toList();
    }

    if (quizzes.isEmpty) {
    return const Center(child: Text("No quizzes found"));
    }

    return ListView(
          children: quizzes.map((quiz) {

          final data = quiz.data() as Map<String, dynamic>;

          final title = data["title"] ?? "Untitled Quiz";
          final publishDate = data["publishDate"] != null
          ? (data["publishDate"] as Timestamp).toDate(): null;

            return ExpansionTile(
              leading: const Icon(Icons.quiz),
              title: Text(title),
              subtitle: publishDate != null
                   ? Text("Published: $publishDate")
                   : const Text("Published: Unknown"),

    children: [
                // ---Submission Stream ---
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("quizzes")
                      .doc(quiz.id)
                      .collection("submissions")
                      .orderBy("submittedAt", descending: true)
                      .snapshots(),
                  builder: (context, subSnap) {
                    if (!subSnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final submissions = subSnap.data!.docs;
                    if (submissions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("No submissions yet"),
                      );
                    }

                    // 📊 Calculate summary
                    final scores = submissions
                        .map((s) => (s["score"] ?? 0) as int)
                        .toList();
                    final totals = submissions
                        .map((s) => (s["total"] ?? 0) as int)
                        .toList();

                    final totalParticipants = submissions.length;
                    final highest = scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0;
                    final lowest = scores.isNotEmpty ? scores.reduce((a, b) => a < b ? a : b) : 0;
                    final average = scores.isNotEmpty
                        ? (scores.reduce((a, b) => a + b) / scores.length)
                        : 0;

                    return Column(
                      children: [
                        // --- Summary Card with Chart ---
                        Card(
                          margin: const EdgeInsets.all(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "📊 Quiz Summary",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text("👥 Participants: $totalParticipants"),
                                Text("🏆 Highest Score: $highest"),
                                Text("📉 Lowest Score: $lowest"),
                                Text("📊 Average Score: ${average.toStringAsFixed(2)}"),
                                const SizedBox(height: 20),

                                // --- Bar Chart (distribution) ---
                                SizedBox(
                                  height: 200,
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: submissions.length.toDouble(),
                                      barTouchData: BarTouchData(enabled: true),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 28,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              switch (value.toInt()) {
                                                case 0:
                                                  return const Text("0-2");
                                                case 1:
                                                  return const Text("3-5");
                                                case 2:
                                                  return const Text("6-8");
                                                case 3:
                                                  return const Text("9-10");
                                                default:
                                                  return const Text("");
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      barGroups: [
                                        BarChartGroupData(
                                          x: 0,
                                          barRods: [
                                            BarChartRodData(
                                              toY: scores.where((s) => s >= 0 && s <= 2).length.toDouble(),
                                              color: Colors.redAccent,
                                              width: 16,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ],
                                        ),
                                        BarChartGroupData(
                                          x: 1,
                                          barRods: [
                                            BarChartRodData(
                                              toY: scores.where((s) => s >= 3 && s <= 5).length.toDouble(),
                                              color: Colors.orangeAccent,
                                              width: 16,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ],
                                        ),
                                        BarChartGroupData(
                                          x: 2,
                                          barRods: [
                                            BarChartRodData(
                                              toY: scores.where((s) => s >= 6 && s <= 8).length.toDouble(),
                                              color: Colors.blueAccent,
                                              width: 16,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ],
                                        ),
                                        BarChartGroupData(
                                          x: 3,
                                          barRods: [
                                            BarChartRodData(
                                              toY: scores.where((s) => s >= 9 && s <= 10).length.toDouble(),
                                              color: Colors.green,
                                              width: 16,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(),

                        // --- List of Submissions ---
                        ...submissions.map((sub) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: sub["studentProfileUrl"] != null
                                  ? NetworkImage(sub["studentProfileUrl"])
                                  : null,
                              child: sub["studentProfileUrl"] == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(sub["studentName"] ?? "Unknown"),
                            subtitle: Text(
                              "Score: ${sub["score"] ?? 0}/${sub["total"] ?? 0} • "
                                  "Submitted at: ${sub["submittedAt"].toDate()}",
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubmissionDetailScreen(
                                    quizTitle: quiz["title"],
                                    submissionId: sub.id,
                                    quizId: quiz.id,
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            );
          }).toList(),
    );
            },
          ),
        ),
      ],
    );
  }
}
