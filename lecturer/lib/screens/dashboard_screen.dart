import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/exam.dart';
import '../models/resource.dart';
import '../models/policy.dart';
import '../services/api_service.dart';
import 'exam_monitor_screen.dart';
import 'resource_manager_screen.dart';
import 'live_audit_screen.dart';
import '../widgets/matrix_builder_widget.dart';
import '../widgets/policy_preview_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 0; // 0: Dashboard, 1: Sessions, 2: Resources, 3: Policies, 4: Audit
  List<ExamSession> exams = [];
  List<BrowserResource> browsers = [];
  List<AIResource> aiServices = [];
  List<AccessPolicy> policies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      final fExams = await ApiService.fetchExams();
      final fBrowsers = await ApiService.fetchBrowsers();
      final fAi = await ApiService.fetchAIServices();
      final fPolicies = await ApiService.fetchPolicies();
      if (mounted) {
        setState(() {
          exams = fExams;
          browsers = fBrowsers;
          aiServices = fAi;
          policies = fPolicies;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showCreateSessionWizard() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateSessionWizardDialog(
        browsers: browsers,
        aiServices: aiServices,
        onSessionCreated: () => _loadAllData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: Row(
        children: [
          // Navigation Sidebar
          _buildSidebar(),

          // Main Content View
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                      : _buildActiveTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        border: Border(right: BorderSide(color: AppTheme.borderGray, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Brand
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.softGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "KASIM",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      "Access Control Engine",
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderGray),
          const SizedBox(height: 16),

          // Nav Items
          _buildNavItem(0, Icons.dashboard_outlined, "Overview"),
          _buildNavItem(1, Icons.assignment_outlined, "Active Sessions"),
          _buildNavItem(2, Icons.apps_outlined, "Resource Registry"),
          _buildNavItem(3, Icons.policy_outlined, "Policy Templates"),
          _buildNavItem(4, Icons.security_outlined, "Audit Log Stream"),

          const Spacer(),
          const Divider(height: 1, color: AppTheme.borderGray),

          // User Profile Card at Bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.softGreen,
                  child: Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "L",
                    style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.userEmail.isNotEmpty ? widget.userEmail : "Lecturer Account",
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "Logout",
                  icon: const Icon(Icons.logout, color: AppTheme.textMuted, size: 18),
                  onPressed: widget.onLogout,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.softGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        border: Border(bottom: BorderSide(color: AppTheme.borderGray, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                _getTabTitle(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.softGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Default-Deny Engine Active",
                  style: TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: "Refresh Data",
                icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
                onPressed: _loadAllData,
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showCreateSessionWizard,
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  "Create Session",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTabIndex) {
      case 0:
        return "Dashboard Overview";
      case 1:
        return "Exam Sessions & Enforcement";
      case 2:
        return "Dynamic Resource Registry";
      case 3:
        return "Policy Templates & Matrices";
      case 4:
        return "Real-time Security Audit Stream";
      default:
        return "Dashboard";
    }
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildSessionsTab();
      case 2:
        return const ResourceManagerScreen();
      case 3:
        return _buildPoliciesTab();
      case 4:
        return exams.isNotEmpty
            ? LiveAuditScreen(examId: exams.first.id, examTitle: exams.first.title)
            : const Center(child: Text("Create a session to view live audit stream."));
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    final activeSessions = exams.where((e) => e.status == "active").toList();
    final activeStudents = exams.fold<int>(0, (sum, e) => sum + e.activeStudentsCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "Total Exam Sessions",
                  "${exams.length}",
                  Icons.assignment_outlined,
                  AppTheme.primaryGreen,
                  AppTheme.softGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  "Active Enforcement Sessions",
                  "${activeSessions.length}",
                  Icons.shield_outlined,
                  AppTheme.accentGreen,
                  const Color(0xFFE8F5E9),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  "Connected Student Devices",
                  "$activeStudents",
                  Icons.computer_outlined,
                  const Color(0xFF2B5B84),
                  const Color(0xFFE3EFF9),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  "Registered Resources",
                  "${browsers.length + aiServices.length}",
                  Icons.tune_outlined,
                  const Color(0xFF6B4C9A),
                  const Color(0xFFF3E8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Active Session Highlight Banner (if any active)
          if (activeSessions.isNotEmpty) ...[
            _buildActiveSessionBanner(activeSessions.first),
            const SizedBox(height: 28),
          ],

          // Recent Sessions Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Exam Sessions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedTabIndex = 1),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
                child: const Text("View All Sessions →", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          exams.isEmpty
              ? _buildEmptySessionsCard()
              : Column(
                  children: exams.take(4).map((exam) => _buildSessionCard(exam)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color iconColor, Color bg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBanner(ExamSession session) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.softGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.paleGreen, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.cardWhite,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield, color: AppTheme.primaryGreen, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text("LIVE ENFORCEMENT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      session.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Session Code: ${session.examCode} • Allowed Browser: ${session.allowedBrowser} • ${session.activeStudentsCount} Active Student Agents",
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => ExamMonitorScreen(examId: session.id)),
              ).then((_) => _loadAllData());
            },
            icon: const Icon(Icons.monitor_heart, size: 16, color: Colors.white),
            label: const Text("Open Live Monitor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Session Management", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  SizedBox(height: 2),
                  Text("Manage, launch, pause, and review student exam policies", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateSessionWizard,
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text("New Exam Session", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: exams.isEmpty
                ? _buildEmptySessionsCard()
                : ListView.builder(
                    itemCount: exams.length,
                    itemBuilder: (ctx, i) => _buildSessionCard(exams[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ExamSession exam) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Row(
        children: [
          // Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.creamBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderGray),
            ),
            child: Column(
              children: [
                const Text("CODE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(
                  exam.examCode,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(width: 10),
                    _buildStatusBadge(exam),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      exam.startTime != null && exam.endTime != null
                          ? "${dateFormat.format(exam.startTime!.toLocal())} → ${dateFormat.format(exam.endTime!.toLocal())}"
                          : "Scheduled: ${exam.durationMinutes} Minutes (Waiting to Launch)",
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.language, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      "Browser: ${exam.allowedBrowser}",
                      style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats & Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${exam.totalJoinedCount} Joined • ${exam.activeStudentsCount} Active",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => ExamMonitorScreen(examId: exam.id)),
                  ).then((_) => _loadAllData());
                },
                icon: Icon(
                  exam.status == "waiting" ? Icons.play_arrow : Icons.monitor,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  exam.status == "waiting" ? "Launch Session" : "Monitor",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: exam.status == "waiting" ? AppTheme.primaryGreen : AppTheme.accentGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ExamSession exam) {
    Color bg;
    Color text;
    String label;

    if (!exam.isActive) {
      bg = const Color(0xFFFDE8E8);
      text = AppTheme.errorMuted;
      label = "PAUSED";
    } else if (exam.status == "waiting") {
      bg = const Color(0xFFFEF3C7);
      text = AppTheme.warningAmber;
      label = "LOBBY (READY)";
    } else if (exam.status == "active") {
      bg = AppTheme.softGreen;
      text = AppTheme.primaryGreen;
      label = "ACTIVE ENFORCEMENT";
    } else {
      bg = const Color(0xFFF3F4F6);
      text = AppTheme.textMuted;
      label = "CONCLUDED";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: text),
      ),
    );
  }

  Widget _buildEmptySessionsCard() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.assignment_outlined, size: 48, color: AppTheme.borderGray),
            const SizedBox(height: 12),
            const Text(
              "No Active Sessions Found",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              "Click 'Create Session' to configure policy rules and launch an exam.",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showCreateSessionWizard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                elevation: 0,
              ),
              child: const Text("Create First Session", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoliciesTab() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Policy Templates & Authorization Engine", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 4),
          const Text("Reusable policy definitions implementing explicit authorization and Default-Deny logic.", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          Expanded(
            child: policies.isEmpty
                ? const Center(child: Text("No policy templates created yet."))
                : ListView.builder(
                    itemCount: policies.length,
                    itemBuilder: (ctx, i) {
                      final p = policies[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.cardWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderGray),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
                                const SizedBox(height: 4),
                                Text(
                                  "Default Action: ${p.defaultAction} • Browser Mode: ${p.browserMode} • Version: ${p.version}",
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final preview = await ApiService.previewDraftPolicy({
                                    'title': p.title,
                                    'browser_mode': p.browserMode,
                                    'ai_mode': p.aiMode,
                                    'desktop_app_mode': p.desktopAppMode,
                                    'allowed_browsers': p.allowedBrowsers,
                                    'allowed_ai': p.allowedAi,
                                    'browser_ai_matrix': p.browserAiMatrix,
                                    'allowed_desktop_apps': p.allowedDesktopApps,
                                  });
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => PolicyPreviewDialog(preview: preview),
                                    );
                                  }
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              label: const Text("Simulate Matrix"),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- Multi-Step Session Creation Wizard Dialog ---
class CreateSessionWizardDialog extends StatefulWidget {
  final List<BrowserResource> browsers;
  final List<AIResource> aiServices;
  final VoidCallback onSessionCreated;

  const CreateSessionWizardDialog({
    super.key,
    required this.browsers,
    required this.aiServices,
    required this.onSessionCreated,
  });

  @override
  State<CreateSessionWizardDialog> createState() => _CreateSessionWizardDialogState();
}

class _CreateSessionWizardDialogState extends State<CreateSessionWizardDialog> {
  int currentStep = 0; // 0: Info, 1: Browser, 2: AI, 3: Matrix, 4: Review

  final titleCtrl = TextEditingController();
  final durationCtrl = TextEditingController(text: "60");
  final descCtrl = TextEditingController();

  List<String> selectedBrowsers = [];
  List<String> selectedAi = [];
  Map<String, List<String>> matrix = {};
  bool isSubmitting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    // Default select first browser if available
    if (widget.browsers.isNotEmpty) {
      selectedBrowsers.add(widget.browsers.first.id);
      matrix[widget.browsers.first.id] = [];
    }
  }

  Future<void> _handleFinish() async {
    final title = titleCtrl.text.trim();
    final duration = int.tryParse(durationCtrl.text.trim()) ?? 60;

    if (title.isEmpty) {
      setState(() => error = "Please provide an exam session title.");
      return;
    }

    if (selectedBrowsers.isEmpty) {
      setState(() => error = "At least one browser must be authorized.");
      return;
    }

    setState(() {
      isSubmitting = true;
      error = null;
    });

    try {
      // 1. Create Policy
      final policyPayload = {
        'title': 'Policy: $title',
        'description': descCtrl.text.trim(),
        'browser_mode': 'ALLOW_SELECTED',
        'ai_mode': selectedAi.isNotEmpty ? 'ALLOW_SELECTED' : 'BLOCK_ALL',
        'desktop_app_mode': 'BLOCK_ALL_UNAUTHORIZED',
        'allowed_browsers': selectedBrowsers,
        'allowed_ai': selectedAi,
        'browser_ai_matrix': matrix,
        'allowed_desktop_apps': [],
      };

      final policy = await ApiService.createPolicy(policyPayload);

      // Find primary browser name for display
      final primaryB = widget.browsers.firstWhere((b) => b.id == selectedBrowsers.first, orElse: () => widget.browsers.first);

      // 2. Create Exam Session
      await ApiService.createExam(
        title: title,
        durationMinutes: duration,
        allowedBrowser: primaryB.name,
        policyId: policy.id,
      );

      widget.onSessionCreated();
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
    return Dialog(
      backgroundColor: AppTheme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        height: 620,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Step Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppTheme.softGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.lock_clock, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Create Controlled Session",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step Progress Bar
            Row(
              children: [
                _buildStepPill(0, "1. Information"),
                const SizedBox(width: 8),
                _buildStepPill(1, "2. Browsers"),
                const SizedBox(width: 8),
                _buildStepPill(2, "3. AI Access"),
                const SizedBox(width: 8),
                _buildStepPill(3, "4. Matrix"),
                const SizedBox(width: 8),
                _buildStepPill(4, "5. Review"),
              ],
            ),
            const Divider(height: 24, color: AppTheme.borderGray),

            // Error Alert
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF8B4B4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorMuted, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error!, style: const TextStyle(color: AppTheme.errorMuted, fontSize: 12))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Step Body
            Expanded(
              child: SingleChildScrollView(
                child: _buildCurrentStepContent(),
              ),
            ),

            const Divider(height: 24, color: AppTheme.borderGray),

            // Bottom Navigation Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                currentStep > 0
                    ? OutlinedButton(
                        onPressed: () => setState(() => currentStep--),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textDark),
                        child: const Text("Back"),
                      )
                    : const SizedBox.shrink(),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              if (currentStep < 4) {
                                setState(() => currentStep++);
                              } else {
                                _handleFinish();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(currentStep == 4 ? "Start Session & Enforce" : "Next Step →"),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPill(int step, String label) {
    final isActive = currentStep == step;
    final isDone = currentStep > step;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryGreen : (isDone ? AppTheme.softGreen : AppTheme.creamBg),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : (isDone ? AppTheme.primaryGreen : AppTheme.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Step 1: Session Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              decoration: _inputDeco("Exam Session Title", "e.g. Mathematics Midterm Examination"),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco("Duration (Minutes)", "60", suffix: "mins"),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: _inputDeco("Description / Notes (Optional)", "Instructions for student desktop environment..."),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Step 2: Authorized Browsers (Default Deny)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text("Select which browsers student agents are permitted to use during this session.", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.browsers.map((b) {
                final isSelected = selectedBrowsers.contains(b.id);
                return FilterChip(
                  label: Text(b.name),
                  selected: isSelected,
                  selectedColor: AppTheme.softGreen,
                  checkmarkColor: AppTheme.primaryGreen,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selectedBrowsers.add(b.id);
                        matrix.putIfAbsent(b.id, () => []);
                      } else {
                        selectedBrowsers.remove(b.id);
                        matrix.remove(b.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Step 3: AI Services Authorization", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text("Select AI platforms permitted in this exam. If none are selected, all AI will be strictly blocked.", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.aiServices.map((a) {
                final isSelected = selectedAi.contains(a.id);
                return FilterChip(
                  label: Text(a.name),
                  selected: isSelected,
                  selectedColor: const Color(0xFFF3E8FF),
                  checkmarkColor: const Color(0xFF6B4C9A),
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF6B4C9A) : AppTheme.textDark,
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selectedAi.add(a.id);
                      } else {
                        selectedAi.remove(a.id);
                        matrix.forEach((k, v) => v.remove(a.id));
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Step 4: Browser ↔ AI Permission Matrix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
            const SizedBox(height: 4),
            const Text("Explicitly authorize which AI service each browser is allowed to access.", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            MatrixBuilderWidget(
              browsers: widget.browsers,
              aiServices: widget.aiServices,
              selectedBrowserIds: selectedBrowsers,
              selectedAiIds: selectedAi,
              browserAiMatrix: matrix,
              onChanged: (bList, aList, m) {
                setState(() {
                  selectedBrowsers = bList;
                  selectedAi = aList;
                  matrix = m;
                });
              },
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Step 5: Policy Verification & Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.creamBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Exam Title: ${titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Untitled'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Duration: ${durationCtrl.text} Minutes"),
                  const Divider(height: 16),
                  Text("Authorized Browsers: ${selectedBrowsers.length} selected"),
                  Text("Authorized AI Services: ${selectedAi.isEmpty ? 'NONE (Browser-Without-AI Mode)' : selectedAi.length.toString() + ' selected'}"),
                  const SizedBox(height: 8),
                  const Text("Default Deny: Active (All unlisted applications, browsers, and domains denied).", style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  InputDecoration _inputDeco(String label, String hint, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppTheme.creamBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.borderGray),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
