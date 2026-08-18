import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/exam.dart';
import '../services/api_service.dart';
import 'exam_monitor_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ExamSession> exams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => isLoading = true);
    try {
      final fetched = await ApiService.fetchExams();
      setState(() {
        exams = fetched;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showCreateExamModal() {
    showDialog(
      context: context,
      builder: (context) => const CreateExamDialog(),
    ).then((_) => _loadExams());
  }

  Widget _buildStatusBadge(ExamSession exam) {
    Color bg;
    Color border;
    Color text;
    String label;

    if (!exam.isActive) {
      bg = Colors.red.withAlpha(40);
      border = Colors.red;
      text = Colors.red;
      label = "DEACTIVATED";
    } else if (exam.status == "waiting") {
      bg = Colors.amber.withAlpha(30);
      border = Colors.amber;
      text = Colors.amber;
      label = "LOBBY (WAITING)";
    } else if (exam.status == "active") {
      bg = const Color(0xFF238636).withAlpha(40);
      border = const Color(0xFF3FB950);
      text = const Color(0xFF3FB950);
      label = "ACTIVE (IN PROGRESS)";
    } else {
      bg = Colors.blueGrey.withAlpha(40);
      border = Colors.blueGrey;
      text = Colors.blueGrey.shade200;
      label = "CONCLUDED";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF58A6FF)),
            SizedBox(width: 10),
            Text(
              "Kasim Lecturer Portal",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8B949E)),
            onPressed: _loadExams,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFF85149)),
            onPressed: widget.onLogout,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Exam Sessions",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Create, launch, monitor and view attendance for locked exam sessions",
                      style: TextStyle(color: Color(0xFF8B949E)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateExamModal,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "New Exam Session",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
                  : exams.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: exams.length,
                          itemBuilder: (context, index) {
                            final exam = exams[index];
                            return _buildExamCard(exam);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined, size: 64, color: Color(0xFF30363D)),
          const SizedBox(height: 16),
          const Text(
            "No Exam Sessions Yet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Click 'New Exam Session' to create a session code with custom duration and browser rules.",
            style: TextStyle(color: Color(0xFF8B949E)),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(ExamSession exam) {
    final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF58A6FF).withAlpha(80)),
            ),
            child: Column(
              children: [
                const Text("EXAM CODE", style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
                const SizedBox(height: 4),
                Text(
                  exam.examCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF58A6FF),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(exam),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF8B949E)),
                    const SizedBox(width: 6),
                    Text(
                      exam.startTime != null && exam.endTime != null
                          ? "${dateFormat.format(exam.startTime!.toLocal())} → ${dateFormat.format(exam.endTime!.toLocal())}"
                          : "Duration: ${exam.durationMinutes} Minutes (Waiting to Launch)",
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                    ),
                    const SizedBox(width: 20),
                    const Icon(Icons.language, size: 16, color: Color(0xFF8B949E)),
                    const SizedBox(width: 6),
                    Text(
                      "Allowed: ${exam.allowedBrowser}",
                      style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${exam.totalJoinedCount} Student(s) Joined",
                style: const TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "${exam.activeStudentsCount} Currently Active",
                style: const TextStyle(color: Color(0xFF3FB950), fontSize: 12),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExamMonitorScreen(examId: exam.id),
                    ),
                  ).then((_) => _loadExams());
                },
                icon: const Icon(Icons.monitor, size: 16, color: Colors.white),
                label: Text(
                  exam.status == "waiting" ? "Launch & Monitor" : "Monitor Session",
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: exam.status == "waiting"
                      ? const Color(0xFF238636)
                      : const Color(0xFF1F6FEB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class CreateExamDialog extends StatefulWidget {
  const CreateExamDialog({super.key});

  @override
  State<CreateExamDialog> createState() => _CreateExamDialogState();
}

class _CreateExamDialogState extends State<CreateExamDialog> {
  final titleController = TextEditingController();
  final durationController = TextEditingController(text: "60");
  String allowedBrowser = "Google Chrome";
  bool isSubmitting = false;
  String? error;

  final List<String> browserOptions = [
    "Google Chrome",
    "Microsoft Edge",
    "Mozilla Firefox",
    "Brave",
  ];

  Future<void> _submit() async {
    if (titleController.text.trim().isEmpty) {
      setState(() => error = "Title cannot be empty");
      return;
    }

    final durationMins = int.tryParse(durationController.text.trim());
    if (durationMins == null || durationMins <= 0) {
      setState(() => error = "Please enter a valid positive duration in minutes");
      return;
    }

    setState(() {
      isSubmitting = true;
      error = null;
    });

    try {
      await ApiService.createExam(
        title: titleController.text.trim(),
        durationMinutes: durationMins,
        allowedBrowser: allowedBrowser,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        isSubmitting = false;
        error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Create Exam Session", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Color(0xFFF85149))),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Exam Title",
                labelStyle: TextStyle(color: Color(0xFF8B949E)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Exam Duration (Minutes)",
                hintText: "e.g. 30, 60, 90, 120",
                labelStyle: TextStyle(color: Color(0xFF8B949E)),
                hintStyle: TextStyle(color: Color(0xFF484F58)),
                suffixText: "mins",
                suffixStyle: TextStyle(color: Color(0xFF58A6FF)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Allowed Browser Policy:", style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
            DropdownButton<String>(
              value: allowedBrowser,
              dropdownColor: const Color(0xFF161B22),
              isExpanded: true,
              style: const TextStyle(color: Colors.white),
              items: browserOptions.map((b) {
                return DropdownMenuItem(value: b, child: Text(b));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => allowedBrowser = val);
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Text(
                "Note: Session will be created in a waiting lobby. Students can join with the generated code. Once you click 'Start Session', late joiners are blocked.",
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Color(0xFF8B949E))),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
          child: const Text("Generate Exam Code", style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }
}
