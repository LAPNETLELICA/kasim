import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/exam.dart';
import '../services/api_service.dart';

class ExamMonitorScreen extends StatefulWidget {
  final String examId;
  const ExamMonitorScreen({super.key, required this.examId});

  @override
  State<ExamMonitorScreen> createState() => _ExamMonitorScreenState();
}

class _ExamMonitorScreenState extends State<ExamMonitorScreen> {
  ExamSession? exam;
  bool isLoading = true;
  bool isActionLoading = false;
  Timer? pollTimer;
  Timer? tickTimer;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchDetails());
    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && exam?.status == "active") {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await ApiService.fetchExamDetail(widget.examId);
      if (mounted) {
        setState(() {
          exam = details;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleStartSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Launch Exam Session?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Starting the session will immediately start the ${exam?.durationMinutes ?? 60}-minute exam period and apply desktop lockdown to all ${exam?.totalJoinedCount ?? 0} students currently in the lobby.\n\nOnce started, no new students will be allowed to join.",
          style: const TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            child: const Text("Start Session Now", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isActionLoading = true);
      try {
        final updated = await ApiService.startExam(widget.examId);
        setState(() {
          exam = updated;
          isActionLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF238636),
              content: Text("Exam session officially started! Late student entry is now locked."),
            ),
          );
        }
      } catch (e) {
        setState(() => isActionLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDA3633),
              content: Text(e.toString().replaceAll('Exception: ', '')),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleStopSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("End Exam Session Early?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Ending the session will conclude the examination for all students and automatically lift lockdown restrictions on their devices.",
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDA3633)),
            child: const Text("End Session", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isActionLoading = true);
      try {
        final updated = await ApiService.stopExam(widget.examId);
        setState(() {
          exam = updated;
          isActionLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF1F6FEB),
              content: Text("Exam session ended. Desktop lockdown released for all students."),
            ),
          );
        }
      } catch (e) {
        setState(() => isActionLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDA3633),
              content: Text(e.toString().replaceAll('Exception: ', '')),
            ),
          );
        }
      }
    }
  }

  Future<void> _copyAttendanceReport() async {
    if (exam == null) return;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buffer = StringBuffer();

    buffer.writeln("==================================================");
    buffer.writeln("KASIM SECURE EXAM - ATTENDANCE & PARTICIPATION REPORT");
    buffer.writeln("==================================================");
    buffer.writeln("Exam Title:        ${exam!.title}");
    buffer.writeln("Exam Code:         ${exam!.examCode}");
    buffer.writeln("Allowed Browser:   ${exam!.allowedBrowser}");
    buffer.writeln("Session Status:    ${exam!.status.toUpperCase()}");
    buffer.writeln("Duration:          ${exam!.durationMinutes} minutes");
    if (exam!.startTime != null) {
      buffer.writeln("Started At:        ${dateFormat.format(exam!.startTime!.toLocal())}");
    }
    if (exam!.endTime != null) {
      buffer.writeln("Ended At:          ${dateFormat.format(exam!.endTime!.toLocal())}");
    }
    buffer.writeln("Total Attendees:   ${exam!.attendance.length}");
    buffer.writeln("Currently Active:  ${exam!.activeStudentsCount}");
    buffer.writeln("--------------------------------------------------");
    buffer.writeln("STUDENT ROSTER:");
    buffer.writeln("--------------------------------------------------");

    if (exam!.attendance.isEmpty) {
      buffer.writeln("No students participated in this exam session.");
    } else {
      for (int i = 0; i < exam!.attendance.length; i++) {
        final a = exam!.attendance[i];
        final compliantStr = a.browserCompliant ? "COMPLIANT" : "POLICY VIOLATION";
        buffer.writeln(
            "${i + 1}. [${a.status.toUpperCase()}] ${a.studentName} | Joined: ${dateFormat.format(a.joinedAt.toLocal())} | Browser Rule: $compliantStr | Device: ${a.deviceInfo ?? 'Unknown'}");
      }
    }
    buffer.writeln("==================================================");

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF238636),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text("Attendance roster copied to clipboard!"),
            ],
          ),
        ),
      );
    }
  }

  String _formatRemainingTime() {
    if (exam == null || exam!.endTime == null) return "00:00:00";
    final diff = exam!.endTime!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    if (diff <= 0) return "00:00:00 (Time Expired)";
    final d = Duration(seconds: diff);
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');
    final timeFormat = DateFormat('HH:mm:ss');

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Text(exam?.title ?? "Exam Monitor", style: const TextStyle(color: Colors.white)),
            if (exam != null) ...[
              const SizedBox(width: 12),
              _buildStatusBadge(exam!.status),
            ]
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Data",
            icon: const Icon(Icons.refresh, color: Color(0xFF8B949E)),
            onPressed: _fetchDetails,
          ),
          IconButton(
            tooltip: "Copy Attendance Summary",
            icon: const Icon(Icons.copy_all, color: Color(0xFF58A6FF)),
            onPressed: _copyAttendanceReport,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isLoading || exam == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Exam Code & Launch Control Banner
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: exam!.status == "active"
                            ? const Color(0xFF238636)
                            : (exam!.status == "waiting" ? const Color(0xFF58A6FF).withAlpha(100) : const Color(0xFF30363D)),
                        width: exam!.status == "active" ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "UNIQUE EXAM CODE FOR STUDENTS",
                              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              exam!.examCode,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF58A6FF),
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Allowed Browser: ${exam!.allowedBrowser} | Scheduled Duration: ${exam!.durationMinutes} mins",
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                            ),
                          ],
                        ),
                        // Action Buttons based on status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (exam!.status == "waiting") ...[
                              ElevatedButton.icon(
                                onPressed: isActionLoading ? null : _handleStartSession,
                                icon: isActionLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.play_arrow, color: Colors.white),
                                label: const Text(
                                  "Start Exam Session",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF238636),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Locks entry and engages countdown for all waiting students",
                                style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                              ),
                            ] else if (exam!.status == "active") ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D1117),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF238636)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text("TIME REMAINING", style: TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatRemainingTime(),
                                          style: const TextStyle(
                                            color: Color(0xFF3FB950),
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    onPressed: isActionLoading ? null : _handleStopSession,
                                    icon: const Icon(Icons.stop, color: Colors.white),
                                    label: const Text("End Session Early", style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDA3633),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F6FEB).withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF1F6FEB)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Color(0xFF58A6FF), size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      "Exam Concluded",
                                      style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Stat Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Total Joined Roster",
                          "${exam!.totalJoinedCount}",
                          Icons.groups_outlined,
                          const Color(0xFF58A6FF),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          "Currently Active / In Exam",
                          "${exam!.activeStudentsCount}",
                          Icons.person_outline,
                          const Color(0xFF3FB950),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          "Completed / Finished",
                          "${exam!.attendance.where((a) => a.status == 'completed').length}",
                          Icons.task_alt,
                          Colors.purpleAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          "Browser Policy Violations",
                          "${exam!.attendance.where((a) => !a.browserCompliant).length}",
                          Icons.warning_amber_rounded,
                          const Color(0xFFF85149),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Attendance & Participation Table Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Attendance & Participation Roster",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Live log of all students who entered and attended this examination",
                            style: TextStyle(color: const Color(0xFF8B949E), fontSize: 13),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _copyAttendanceReport,
                        icon: const Icon(Icons.download, size: 16, color: Colors.white),
                        label: const Text("Export / Copy Attendance", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21262D),
                          side: const BorderSide(color: Color(0xFF30363D)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Attendance Roster Table / Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: exam!.attendance.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(48.0),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.people_outline, size: 48, color: Color(0xFF30363D)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No Students in Waiting Lobby Yet",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Share the exam code '${exam!.examCode}' with your students to have them join.",
                                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: exam!.attendance.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFF21262D), height: 1),
                            itemBuilder: (context, index) {
                              final att = exam!.attendance[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    // Index Circle
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFF21262D),
                                      child: Text(
                                        "${index + 1}",
                                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Student Name & Device
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            att.studentName,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            att.deviceInfo ?? "Kasim Desktop Client",
                                            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Join Time
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("JOIN TIME", style: TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                                          const SizedBox(height: 2),
                                          Text(
                                            dateFormat.format(att.joinedAt.toLocal()),
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Attendance / Participation Status
                                    Expanded(
                                      flex: 2,
                                      child: _buildStudentStatusChip(att.status),
                                    ),
                                    // Browser Policy Compliance
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          Icon(
                                            att.browserCompliant ? Icons.check_circle : Icons.error,
                                            color: att.browserCompliant ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            att.browserCompliant ? "Compliant" : "Violation Alert",
                                            style: TextStyle(
                                              color: att.browserCompliant ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Last Heartbeat
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text("LAST HEARTBEAT", style: TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
                                        const SizedBox(height: 2),
                                        Text(
                                          timeFormat.format(att.lastHeartbeat.toLocal()),
                                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;
    String label;

    if (status == "waiting") {
      bg = Colors.amber.withAlpha(30);
      border = Colors.amber;
      text = Colors.amber;
      label = "LOBBY (WAITING)";
    } else if (status == "active") {
      bg = const Color(0xFF238636).withAlpha(40);
      border = const Color(0xFF3FB950);
      text = const Color(0xFF3FB950);
      label = "ACTIVE";
    } else {
      bg = Colors.blueGrey.withAlpha(40);
      border = Colors.blueGrey;
      text = Colors.blueGrey.shade200;
      label = "CONCLUDED";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildStudentStatusChip(String status) {
    Color color;
    String label;

    if (status == "waiting") {
      color = Colors.amber;
      label = "In Lobby";
    } else if (status == "active") {
      color = const Color(0xFF3FB950);
      label = "In Exam";
    } else if (status == "completed") {
      color = const Color(0xFF58A6FF);
      label = "Submitted / Done";
    } else {
      color = Colors.grey;
      label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
