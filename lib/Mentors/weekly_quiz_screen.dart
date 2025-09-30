import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'Quiz_submission.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dropdown_search/dropdown_search.dart';


class WeeklyQuizScreen extends StatefulWidget {
  final String subjectId;
  final String sectionId;
  final String mentorId;
  final String subjectName;
  final String sectionName;
  final Color color;

  const WeeklyQuizScreen({
    Key? key,
    required this.subjectId,
    required this.sectionId,
    required this.mentorId,
    required this.subjectName,
    required this.sectionName,
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
                    .toSet() // 🔹 ensure no duplicates
                    .toList();

                // Ensure current selection is valid
                if (!categories.contains(_selectedCategory)) {
                  _selectedCategory = categories.isNotEmpty ? categories.first : null;
                }

                return DropdownSearch<String>(
                  items: categories,
                  selectedItem: _selectedCategory,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true, // 🔎 enables search
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: "Search category...",
                      ),
                    ),
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: "Category",
                      border: OutlineInputBorder(),
                    ),
                  ),
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

    String searchQuery = "";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // 🔎 Filter categories by search
          final filteredDocs = categoriesSnap.docs.where((doc) {
            final name = (doc["name"] ?? "").toString().toLowerCase();
            return name.contains(searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            title: const Text("Manage Categories"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔎 Search box
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: "Search categories...",
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: filteredDocs.map((doc) {
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
                                  final controller =
                                  TextEditingController(text: category);

                                  final newName =
                                  await showDialog<String>(
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
                                          onPressed: () =>
                                              Navigator.pop(editCtx),
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(
                                              editCtx,
                                              controller.text.trim()),
                                          child: const Text("Save"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (newName != null &&
                                      newName.isNotEmpty &&
                                      newName != category) {
                                    final batch =
                                    FirebaseFirestore.instance.batch();

                                    final quizSnap = await FirebaseFirestore
                                        .instance
                                        .collection("quizzes")
                                        .where("category", isEqualTo: category)
                                        .get();

                                    for (var quiz in quizSnap.docs) {
                                      batch.update(
                                          quiz.reference, {"category": newName});
                                    }

                                    batch.update(doc.reference, {"name": newName});

                                    await batch.commit();
                                    Navigator.pop(ctx);
                                    _loadCategories();
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
                                          onPressed: () =>
                                              Navigator.pop(delCtx, false),
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(delCtx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final batch =
                                    FirebaseFirestore.instance.batch();

                                    final quizSnap = await FirebaseFirestore
                                        .instance
                                        .collection("quizzes")
                                        .where("category", isEqualTo: category)
                                        .get();

                                    for (var quiz in quizSnap.docs) {
                                      batch.update(
                                          quiz.reference,
                                          {"category": "Uncategorized"});
                                    }

                                    batch.delete(doc.reference);

                                    await batch.commit();
                                    Navigator.pop(ctx);
                                    _loadCategories();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ],
          );
        },
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
      "sectionId": widget.sectionId,
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
                .where("sectionId", isEqualTo: widget.sectionId)
                .where("subjectId", isEqualTo: widget.subjectId)
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var quizzes = snapshot.data!.docs;

              // Apply search + category filter safely
              quizzes = quizzes.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = (data["title"] ?? "").toString().toLowerCase();
                final category = data["category"] ?? "Uncategorized";

                final matchesSearch = title.contains(_searchQuery);
                final matchesCategory = _filterCategory == "All" || category == _filterCategory;

                return matchesSearch && matchesCategory;
              }).toList();

              if (quizzes.isEmpty) {
                return const Center(child: Text("No quizzes found"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = quizzes[index];
                  final data = quiz.data() as Map<String, dynamic>;

                  final title = data["title"] ?? "Untitled Quiz";
                  final publishDate = data["publishDate"] != null
                      ? (data["publishDate"] as Timestamp).toDate()
                      : null;

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.quiz_outlined),
                      title: Text(title),
                      subtitle: Text(
                        publishDate != null
                            ? "Publish: $publishDate"
                            : "Publish: Unknown",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              // Load quiz metadata into form
                              setState(() {
                                _editingQuizId = quiz.id;
                                _titleController.text = data["title"] ?? "";
                                _descriptionController.text = data["description"] ?? "";
                                _publishDate = publishDate;
                                _selectedCategory = data["category"] ?? "Uncategorized";
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
                                  "options": List<String>.from(d["options"] ?? []),
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
        // 🔎 Search + Filter row
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

        // 🔹 Quiz list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("quizzes")
                .where("mentorId", isEqualTo: widget.mentorId)
                .where("sectionId", isEqualTo: widget.sectionId)
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
                final title = (doc.data() as Map<String, dynamic>)["title"]
                    ?.toString()
                    .toLowerCase() ??
                    "";
                return title.contains(_searchQuery);
              }).toList();

              // ✅ Apply category filter
              if (_filterCategory != "All") {
                quizzes = quizzes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data.containsKey("category") &&
                      data["category"] == _filterCategory;
                }).toList();
              }

              if (quizzes.isEmpty) {
                return const Center(child: Text("No quizzes found"));
              }

              // 🔹 Show quiz list
              return ListView(
                children: quizzes.map((quiz) {
                  final data = quiz.data() as Map<String, dynamic>;
                  final title = data["title"] ?? "Untitled Quiz";
                  final publishDate = data["publishDate"] != null
                      ? (data["publishDate"] as Timestamp).toDate()
                      : null;

                  return ListTile(
                    leading: const Icon(Icons.quiz),
                    title: Text(title),
                    subtitle: publishDate != null
                        ? Text(
                        "Published: ${publishDate.toLocal().toString().split(" ")[0]}")
                        : const Text("Published: Unknown"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizSubmissionsScreen(
                            quizId: quiz.id,
                            quizTitle: title,
                          ),
                        ),
                      );
                    },
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

class QuizSubmissionsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizSubmissionsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizSubmissionsScreen> createState() => _QuizSubmissionsScreenState();
}

class _QuizSubmissionsScreenState extends State<QuizSubmissionsScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.quizTitle)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("quizzes")
            .doc(widget.quizId)
            .collection("submissions")
            .orderBy("submittedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final submissions = snapshot.data!.docs;

          if (submissions.isEmpty) {
            return const Center(child: Text("No submissions yet"));
          }

          // 📊 Calculate summary
          final scores = submissions.map((s) => (s["score"] ?? 0) as int).toList();
          final totals = submissions.map((s) => (s["total"] ?? 0) as int).toList();
          final highest = scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0;
          final lowest = scores.isNotEmpty ? scores.reduce((a, b) => a < b ? a : b) : 0;
          final average = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0;

          // ✅ Apply search filter
          final filtered = submissions.where((s) {
            final name = (s["studentName"] ?? "").toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              // --- Summary ---
              // --- Summary ---
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizStatsDetailScreen(
                        quizId: widget.quizId,
                        quizTitle: widget.quizTitle,
                      ),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("📊 Quiz Summary",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("👥 Participants: ${submissions.length}"),
                        Text("🏆 Highest Score: $highest"),
                        Text("📉 Lowest Score: $lowest"),
                        Text("📊 Average Score: ${average.toStringAsFixed(2)}"),
                      ],
                    ),
                  ),
                ),
              ),

              // --- Search bar ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search student...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),

              // --- List of submissions ---
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final sub = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: sub["profileUrl"] != null
                            ? NetworkImage(sub["profileUrl"])
                            : null,
                        child: sub["profileUrl"] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(sub["studentName"] ?? "Unknown"),
                      subtitle: Text(
                        "Score: ${sub["score"] ?? 0}/${sub["total"] ?? 0} • "
                            "Submitted: ${sub["submittedAt"].toDate()}",
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubmissionDetailScreen(
                              quizTitle: widget.quizTitle,
                              submissionId: sub.id,
                              quizId: widget.quizId,
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
        },
      ),
    );
  }
}

class QuizStatsDetailScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizStatsDetailScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizStatsDetailScreen> createState() => _QuizStatsDetailScreenState();
}

class _QuizStatsDetailScreenState extends State<QuizStatsDetailScreen> {
  String _selectedChart = "Bar Chart"; // default chart type

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Stats · ${widget.quizTitle}")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("quizzes")
            .doc(widget.quizId)
            .collection("submissions")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final submissions = snapshot.data!.docs;
          if (submissions.isEmpty) {
            return const Center(child: Text("No submissions yet"));
          }

          final scores = submissions.map((s) => (s["score"] ?? 0) as int).toList();

          // Stats
          final highest = scores.reduce((a, b) => a > b ? a : b);
          final lowest = scores.reduce((a, b) => a < b ? a : b);
          final average = scores.reduce((a, b) => a + b) / scores.length;

          // Group counts
          final group0to2 = scores.where((s) => s >= 0 && s <= 2).length;
          final group3to5 = scores.where((s) => s >= 3 && s <= 5).length;
          final group6to8 = scores.where((s) => s >= 6 && s <= 8).length;
          final group9to10 = scores.where((s) => s >= 9 && s <= 10).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Stats Card ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("👥 Participants: ${submissions.length}"),
                      Text("🏆 Highest: $highest"),
                      Text("📉 Lowest: $lowest"),
                      Text("📊 Average: ${average.toStringAsFixed(2)}"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- Dropdown for chart selection ---
              Row(
                children: [
                  const Text("Select Chart: "),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedChart,
                    items: const [
                      DropdownMenuItem(value: "Bar Chart", child: Text("Bar Chart")),
                      DropdownMenuItem(value: "Pie Chart", child: Text("Pie Chart")),
                      DropdownMenuItem(value: "Line Chart", child: Text("Line Chart")),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedChart = val!;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Render chart based on selection ---
              SizedBox(
                height: 300,
                child: _buildChart(
                  _selectedChart,
                  group0to2,
                  group3to5,
                  group6to8,
                  group9to10,
                  scores,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChart(
      String chartType,
      int group0to2,
      int group3to5,
      int group6to8,
      int group9to10,
      List<int> scores,
      ) {
    switch (chartType) {
      case "Pie Chart":
        return PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(value: group0to2.toDouble(), color: Colors.red, title: "0-2"),
              PieChartSectionData(value: group3to5.toDouble(), color: Colors.orange, title: "3-5"),
              PieChartSectionData(value: group6to8.toDouble(), color: Colors.blue, title: "6-8"),
              PieChartSectionData(value: group9to10.toDouble(), color: Colors.green, title: "9-10"),
            ],
          ),
        );

      case "Line Chart":
        return LineChart(
          LineChartData(
            titlesData: FlTitlesData(show: true),
            borderData: FlBorderData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: scores.asMap().entries
                    .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
              ),
            ],
          ),
        );

      default: // Bar Chart
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (scores.length.toDouble() + 1),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    switch (value.toInt()) {
                      case 0: return const Text("0-2");
                      case 1: return const Text("3-5");
                      case 2: return const Text("6-8");
                      case 3: return const Text("9-10");
                    }
                    return const Text("");
                  },
                ),
              ),
            ),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [
                BarChartRodData(toY: group0to2.toDouble(), color: Colors.redAccent),
              ]),
              BarChartGroupData(x: 1, barRods: [
                BarChartRodData(toY: group3to5.toDouble(), color: Colors.orangeAccent),
              ]),
              BarChartGroupData(x: 2, barRods: [
                BarChartRodData(toY: group6to8.toDouble(), color: Colors.blueAccent),
              ]),
              BarChartGroupData(x: 3, barRods: [
                BarChartRodData(toY: group9to10.toDouble(), color: Colors.green),
              ]),
            ],
          ),
        );
    }
  }
}

