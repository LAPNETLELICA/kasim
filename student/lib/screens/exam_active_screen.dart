import 'package:flutter/material.dart';
import '../models/student_session.dart';
import '../services/lockdown_service.dart';
import '../services/api_service.dart';

class ExamActiveScreen extends StatefulWidget {
  final ActiveStudentSession session;
  final int initialRemainingSeconds;
  const ExamActiveScreen({
    super.key,
    required this.session,
    this.initialRemainingSeconds = 0,
  });

  @override
  State<ExamActiveScreen> createState() => _ExamActiveScreenState();
}

class _ExamActiveScreenState extends State<ExamActiveScreen> {
  late LockdownService lockdownService;
  bool isCompliant = true;
  String statusMessage = "Lockdown active and compliant.";
  int remainingSeconds = 0;
  bool isExpired = false;

  @override
  void initState() {
    super.initState();
    
    // Set initial remaining seconds
    if (widget.initialRemainingSeconds > 0) {
      remainingSeconds = widget.initialRemainingSeconds;
    } else if (widget.session.endTime != null) {
      final diff = widget.session.endTime!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
      remainingSeconds = diff > 0 ? diff : (widget.session.durationMinutes * 60);
    } else {
      remainingSeconds = widget.session.durationMinutes * 60;
    }
    
    lockdownService = LockdownService(
      session: widget.session,
      initialRemainingSeconds: remainingSeconds,
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
            statusMessage = "EXAM SESSION COMPLETED: Desktop lockdown automatically released.";
            remainingSeconds = 0;
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
        content: Text(
          isExpired
              ? "Close the exam client and return to the main screen?"
              : "Are you sure you want to finish and submit your exam session? Desktop lockdown will be released.",
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          if (!isExpired)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Continue Exam", style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isExpired ? const Color(0xFF0284C7) : const Color(0xFFEF4444),
            ),
            child: Text(isExpired ? "Close App" : "Submit & Exit", style: const TextStyle(color: Colors.white)),
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
    final isLowTime = remainingSeconds > 0 && remainingSeconds < 300;

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
                        ? const Color(0xFF64748B)
                        : (isCompliant
                            ? (isLowTime ? const Color(0xFFF59E0B) : const Color(0xFF16A34A))
                            : const Color(0xFFEF4444)),
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
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF0284C7)),
                              ),
                              child: Text(
                                "Candidate: ${widget.session.studentName}",
                                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF16A34A)),
                              ),
                              child: Text(
                                "Allowed: ${widget.session.allowedBrowser}",
                                style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "TIME REMAINING",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(remainingSeconds),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: isExpired
                                ? const Color(0xFF64748B)
                                : (isLowTime ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Security Policy Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFF1E293B)
                      : (isCompliant ? const Color(0xFF052E16) : const Color(0xFF450A0A)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpired
                        ? const Color(0xFF475569)
                        : (isCompliant ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired
                          ? Icons.lock_open
                          : (isCompliant ? Icons.verified_user : Icons.warning_amber_rounded),
                      color: isExpired
                          ? const Color(0xFF94A3B8)
                          : (isCompliant ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5)),
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: isExpired
                              ? const Color(0xFFE2E8F0)
                              : (isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isExpired ? Icons.check_circle_outline : Icons.security,
                        size: 72,
                        color: isExpired ? const Color(0xFF22C55E) : const Color(0xFF0284C7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isExpired
                            ? "Exam Concluded - Response Recorded"
                            : "Exam In Progress - Desktop Lockdown Active",
                        style: TextStyle(
                          fontSize: 20,
                          color: isExpired ? Colors.white : const Color(0xFFE2E8F0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isExpired
                            ? "Thank you for completing the exam. You may safely exit the exam client."
                            : "Use only your designated '${widget.session.allowedBrowser}' browser. Other applications are strictly restricted.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              // Exit Button
              ElevatedButton.icon(
                onPressed: _exitExam,
                icon: Icon(isExpired ? Icons.check : Icons.exit_to_app, color: Colors.white),
                label: Text(
                  isExpired ? "Exit Exam Client" : "Finish & Submit Exam",
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
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
