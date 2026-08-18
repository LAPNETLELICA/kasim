import 'package:flutter/material.dart';
import '../models/student_session.dart';
import '../services/api_service.dart';
import 'exam_active_screen.dart';

class ExamEntryScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ExamEntryScreen({super.key, required this.onLogout});

  @override
  State<ExamEntryScreen> createState() => _ExamEntryScreenState();
}

class _ExamEntryScreenState extends State<ExamEntryScreen> {
  final codeController = TextEditingController();
  bool isVerifying = false;
  String? error;
  LockdownRules? verifiedRules;

  Future<void> _verifyCode() async {
    final code = codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => error = "Exam code must be exactly 6 characters");
      return;
    }

    setState(() {
      isVerifying = true;
      error = null;
      verifiedRules = null;
    });

    try {
      final rules = await StudentApiService.verifyExamCode(code);
      if (!rules.valid) {
        setState(() {
          error = rules.message;
          isVerifying = false;
        });
      } else {
        setState(() {
          verifiedRules = rules;
          isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        isVerifying = false;
        error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _startExamSession() async {
    setState(() => isVerifying = true);
    try {
      final activeSession = await StudentApiService.joinExamSession(codeController.text.trim().toUpperCase());
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExamActiveScreen(session: activeSession),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isVerifying = false;
        error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131B2A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text("Kasim Secure Client", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            onPressed: widget.onLogout,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF212E46)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Enter Exam Code",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Provide the 6-character code given by your exam supervisor",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 28),
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Text(error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: codeController,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "______",
                  hintStyle: TextStyle(color: const Color(0xFF64748B).withOpacity(0.5)),
                  filled: true,
                  fillColor: const Color(0xFF090D16),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF212E46)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (verifiedRules == null)
                ElevatedButton(
                  onPressed: isVerifying ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Verify Exam Code", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Exam: ${verifiedRules!.title}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Enforced Browser: ${verifiedRules!.allowedBrowser}",
                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Lockdown: Non-approved web browsers and prohibited applications will be restricted.",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isVerifying ? null : _startExamSession,
                  icon: const Icon(Icons.lock, color: Colors.white),
                  label: const Text(
                    "Start Exam & Apply Lockdown",
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
