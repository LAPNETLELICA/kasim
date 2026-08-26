import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/exam.dart';
import '../models/resource.dart';
import '../models/policy.dart';
import '../services/api_service.dart';
import '../widgets/matrix_builder_widget.dart';
import '../widgets/policy_preview_dialog.dart';
import 'exam_monitor_screen.dart';
import 'resource_manager_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ExamSession> exams = [];
  List<AccessPolicy> policies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => isLoading = true);
    try {
      final fetchedExams = await ApiService.fetchExams();
      final fetchedPolicies = await ApiService.fetchPolicies();
      setState(() {
        exams = fetchedExams;
        policies = fetchedPolicies;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showCreateExamModal() {
    showDialog(
      context: context,
      builder: (context) => CreateExamDialog(policies: policies),
    ).then((_) => _loadExams());
  }

  void _showCreatePolicyModal() async {
    List<BrowserResource> browsers = [];
    List<AIResource> aiServices = [];

    try {
      browsers = await ApiService.fetchBrowsers();
      aiServices = await ApiService.fetchAIServices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching resources: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    final titleCtrl = TextEditingController(text: 'Exam Security Policy');
    final descCtrl = TextEditingController();

    List<String> allowedBrowsers = browsers.map((b) => b.id).toList();
    List<String> allowedAi = [];
    Map<String, List<String>> matrix = {};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Create Policy (Default-Deny Engine)'),
                ],
              ),
              content: SizedBox(
                width: 850,
                height: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Policy Title (e.g. CS101 Final Exam Policy)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description (Optional)'),
                      ),
                      const SizedBox(height: 20),
                      MatrixBuilderWidget(
                        browsers: browsers,
                        aiServices: aiServices,
                        selectedBrowserIds: allowedBrowsers,
                        selectedAiIds: allowedAi,
                        browserAiMatrix: matrix,
                        onChanged: (bList, aList, mDict) {
                          allowedBrowsers = bList;
                          allowedAi = aList;
                          matrix = mDict;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.preview),
                  label: const Text('Preview Policy Matrix'),
                  onPressed: () async {
                    final draftPayload = {
                      'title': titleCtrl.text.trim().isEmpty ? 'Draft Policy' : titleCtrl.text.trim(),
                      'browser_mode': 'ALLOW_SELECTED',
                      'ai_mode': 'ALLOW_SELECTED',
                      'desktop_app_mode': 'BLOCK_ALL_UNAUTHORIZED',
                      'allowed_browsers': allowedBrowsers,
                      'allowed_ai': allowedAi,
                      'browser_ai_matrix': matrix,
                      'allowed_desktop_apps': [],
                    };

                    try {
                      final preview = await ApiService.previewDraftPolicy(draftPayload);
                      showDialog(
                        context: context,
                        builder: (ctx2) => PolicyPreviewDialog(preview: preview),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error generating preview: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;

                    final policyPayload = {
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'browser_mode': 'ALLOW_SELECTED',
                      'ai_mode': 'ALLOW_SELECTED',
                      'desktop_app_mode': 'BLOCK_ALL_UNAUTHORIZED',
                      'allowed_browsers': allowedBrowsers,
                      'allowed_ai': allowedAi,
                      'browser_ai_matrix': matrix,
                      'allowed_desktop_apps': [],
                    };

                    try {
                      await ApiService.createPolicy(policyPayload);
                      Navigator.pop(ctx);
                      _loadExams();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Access Policy created successfully!'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating policy: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Save & Apply Policy'),
                ),
              ],
            );
          },
        );
      },
    );
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
          ElevatedButton.icon(
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Resource Registry'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF21262D)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const ResourceManagerScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.policy, size: 16),
            label: const Text('Create Policy'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F6FEB)),
            onPressed: _showCreatePolicyModal,
          ),
          const SizedBox(width: 12),
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
                      "Exam Sessions & Policy Engine",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Create, launch, monitor and enforce default-deny policies for student desktops",
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
  final List<AccessPolicy> policies;
  const CreateExamDialog({super.key, required this.policies});

  @override
  State<CreateExamDialog> createState() => _CreateExamDialogState();
}

class _CreateExamDialogState extends State<CreateExamDialog> {
  final titleController = TextEditingController();
  final durationController = TextEditingController(text: "60");
  final browserController = TextEditingController(text: "Google Chrome");
  final aiController = TextEditingController(text: "Claude");
  bool allowAiAccess = false;
  String? selectedPolicyId;
  bool isSubmitting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.policies.isNotEmpty) {
      selectedPolicyId = widget.policies.first.id;
    }
  }

  Future<void> _submit() async {
    final title = titleController.text.trim();
    final browserName = browserController.text.trim();
    final aiName = aiController.text.trim();

    if (title.isEmpty) {
      setState(() => error = "Exam Title cannot be empty");
      return;
    }

    if (browserName.isEmpty) {
      setState(() => error = "Please enter exact allowed browser name");
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
      // 1. Create or register resources for the exact browser & AI name
      List<BrowserResource> browsers = await ApiService.fetchBrowsers();
      List<AIResource> aiServices = await ApiService.fetchAIServices();

      String? bId;
      for (final b in browsers) {
        if (b.name.toLowerCase() == browserName.toLowerCase()) {
          bId = b.id;
          break;
        }
      }
      if (bId == null) {
        final newB = await ApiService.addBrowserResource(
          browserName,
          [f'{browserName.toLowerCase().replaceAll(" ", "")}.exe', browserName.toLowerCase()],
          "Direct exam creation browser resource",
        );
        bId = newB.id;
      }

      String? aId;
      if (allowAiAccess && aiName.isNotEmpty && aiName.toLowerCase() != "none") {
        for (final a in aiServices) {
          if (a.name.toLowerCase() == aiName.toLowerCase()) {
            aId = a.id;
            break;
          }
        }
        if (aId == null) {
          final newA = await ApiService.addAIResource(
            aiName,
            [f'{aiName.toLowerCase().replaceAll(" ", "")}.ai', f'{aiName.toLowerCase()}.com'],
            [f'{aiName}.exe'],
            "Direct exam creation AI resource",
          );
          aId = newA.id;
        }
      }

      // 2. Create the exact Default-Deny Access Policy
      final policyPayload = {
        'title': 'Policy for $title',
        'description': 'Policy created directly with exam session',
        'browser_mode': 'ALLOW_SELECTED',
        'ai_mode': allowAiAccess ? 'ALLOW_SELECTED' : 'BLOCK_ALL',
        'desktop_app_mode': 'BLOCK_ALL_UNAUTHORIZED',
        'allowed_browsers': [bId],
        'allowed_ai': (allowAiAccess && aId != null) ? [aId] : [],
        'browser_ai_matrix': {
          bId: (allowAiAccess && aId != null) ? [aId] : []
        },
        'allowed_desktop_apps': [],
      };

      final policy = await ApiService.createPolicy(policyPayload);

      // 3. Create Exam Session with attached policy ID
      await ApiService.createExam(
        title: title,
        durationMinutes: durationMins,
        allowedBrowser: browserName,
        policyId: policy.id,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.add_task, color: Color(0xFF58A6FF)),
          SizedBox(width: 10),
          Text("Create Exam & Policy Session", style: TextStyle(color: Colors.white, fontSize: 20)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D1418),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF85149)),
                  ),
                  child: Text(error!, style: const TextStyle(color: Color(0xFFFF7B72), fontSize: 13)),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Exam Title",
                  hintText: "e.g. CS101 Final Examination",
                  labelStyle: TextStyle(color: Color(0xFF8B949E)),
                  hintStyle: TextStyle(color: Color(0xFF484F58)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF58A6FF))),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Exam Duration (Minutes)",
                  hintText: "e.g. 60, 90, 120",
                  labelStyle: TextStyle(color: Color(0xFF8B949E)),
                  suffixText: "mins",
                  suffixStyle: TextStyle(color: Color(0xFF58A6FF)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF58A6FF))),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "DEFAULT-DENY POLICY ENGINE CONFIGURATION",
                style: TextStyle(color: Color(0xFF58A6FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: browserController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Exact Allowed Browser Name",
                  hintText: "e.g. Google Chrome, Microsoft Edge, Vivaldi",
                  labelStyle: TextStyle(color: Color(0xFF8B949E)),
                  prefixIcon: Icon(Icons.language, color: Color(0xFF8B949E)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF58A6FF))),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Authorize Specific AI Access?", style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  allowAiAccess
                      ? "Pair allowed browser with specific AI service"
                      : "Browser Without AI Mode (All AI services blocked)",
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
                value: allowAiAccess,
                activeColor: const Color(0xFF3FB950),
                onChanged: (val) {
                  setState(() {
                    allowAiAccess = val;
                  });
                },
              ),
              if (allowAiAccess) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: aiController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Exact Allowed AI Service Name / Domain",
                    hintText: "e.g. Claude, ChatGPT, DeepSeek, claude.ai",
                    labelStyle: TextStyle(color: Color(0xFF8B949E)),
                    prefixIcon: Icon(Icons.smart_toy_outlined, color: Color(0xFF8B949E)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF58A6FF))),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFF3FB950), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        allowAiAccess
                            ? "Policy Enforced: Only '${browserController.text}' + '${aiController.text}' will be ALLOWED. All other browsers and AI services are DENIED."
                            : "Policy Enforced: Only '${browserController.text}' is ALLOWED. ALL AI services and other browsers are DENIED.",
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Color(0xFF8B949E))),
        ),
        ElevatedButton.icon(
          onPressed: isSubmitting ? null : _submit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.check, color: Colors.white, size: 18),
          label: const Text("Create & Apply Exam Policy", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        )
      ],
    );
  }
}


