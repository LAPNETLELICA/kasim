import 'package:flutter/material.dart';
import '../models/student_session.dart';
import '../services/lockdown_service.dart';
import '../services/api_service.dart';

class ExamActiveScreen extends StatefulWidget {
  final ActiveStudentSession session;
  const ExamActiveScreen({super.key, required this.session});

  @override
  State<ExamActiveScreen> createState() => _ExamActiveScreenState();
}

class _ExamActiveScreenState extends State<ExamActiveScreen> {
  late LockdownService lockdownService;
  bool isCompliant = true;
  String statusMessage = "Lockdown active";
  int remainingSeconds = 0;
  bool isExpired = false;

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.session.endTime.difference(DateTime.now().toUtc()).inSeconds;
    
    lockdownService = LockdownService(
      session: widget.session,
      onStatusUpdate: (compliant, msg, seconds) {
        if (mounted) {
          setState(() {
            isCompliant = compliant;
            statusMessage = msg;
            remainingSeconds = seconds;
          });
        }
      },
      onExamExpired: () {
        if (mounted) {
          setState(() {
            isExpired = true;
            statusMessage = "EXAM WINDOW EXPIRED: Lockdown restrictions automatically lifted.";
          });
        }
      },
    );

    lockdownService.startLockdownEnforcement();
  }

  @override
  void dispose() {
    lockdownService.stopLockdown();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return "00:00:00";
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }

  Future<void> _exitExam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131B2A),
        title: const Text("Exit Exam Session?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to finish and submit your exam session? Desktop lockdown will be released.",
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Continue Exam", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("Submit & Exit", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      lockdownService.stopLockdown();
      await StudentApiService.leaveSession(widget.session.sessionId);
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              // Top Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpired
                        ? Colors.grey
                        : (isCompliant ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.examTitle,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Allowed Browser: ${widget.session.allowedBrowser}",
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("TIME REMAINING", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(remainingSeconds),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: remainingSeconds < 300 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Security Policy Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isCompliant ? const Color(0xFF052E16) : const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompliant ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompliant ? Icons.verified_user : Icons.warning_amber_rounded,
                      color: isCompliant ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 80, color: Color(0xFF1E293B)),
                      SizedBox(height: 16),
                      Text(
                        "Exam In Progress - Desktop Lockdown Active",
                        style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Open your designated browser to take the exam. Your activity is monitored.",
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              // Exit Button
              ElevatedButton.icon(
                onPressed: _exitExam,
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: Text(
                  isExpired ? "Exit Exam Client" : "Finish & Submit Exam",
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
