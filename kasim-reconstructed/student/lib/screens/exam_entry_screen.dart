import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'exam_lobby_screen.dart';
import 'exam_active_screen.dart';

class ExamEntryScreen extends StatefulWidget {
  const ExamEntryScreen({super.key});

  @override
  State<ExamEntryScreen> createState() => _ExamEntryScreenState();
}

class _ExamEntryScreenState extends State<ExamEntryScreen> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  bool isJoining = false;
  String? error;

  Future<void> _handleJoin() async {
    final name = nameController.text.trim();
    final code = codeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() => error = "Please enter your full name");
      return;
    }

    if (code.length != 6) {
      setState(() => error = "Exam code must be exactly 6 characters");
      return;
    }

    setState(() {
      isJoining = true;
      error = null;
    });

    try {
      final activeSession = await StudentApiService.joinExamSession(code, name);
      if (!mounted) return;

      if (activeSession.examStatus == "waiting") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamLobbyScreen(session: activeSession),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamActiveScreen(session: activeSession),
          ),
        );
      }
    } catch (e) {
      setState(() {
        error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => isJoining = false);
      }
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
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF212E46)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.school_outlined, size: 48, color: Color(0xFF38BDF8)),
                const SizedBox(height: 16),
                const Text(
                  "Student Exam Access",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your full name and the 6-character code provided by your lecturer",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Student Name Field
                const Text("Full Name", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "e.g. Alice Johnson",
                    hintStyle: TextStyle(color: const Color(0xFF64748B).withAlpha(150)),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: const Color(0xFF090D16),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF212E46)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Exam Code Field
                const Text("Exam Code", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: codeController,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "______",
                    hintStyle: TextStyle(color: const Color(0xFF64748B).withAlpha(128)),
                    filled: true,
                    fillColor: const Color(0xFF090D16),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF212E46)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: isJoining ? null : _handleJoin,
                  icon: isJoining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.login, color: Colors.white),
                  label: Text(
                    isJoining ? "Joining Session..." : "Join Exam Session",
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "No account registration required. Your name is recorded for exam attendance.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
