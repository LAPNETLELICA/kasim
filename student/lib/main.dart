import 'package:flutter/material.dart';
import 'screens/student_login_screen.dart';
import 'screens/exam_entry_screen.dart';

void main() {
  runApp(const KasimStudentApp());
}

class KasimStudentApp extends StatefulWidget {
  const KasimStudentApp({super.key});

  @override
  State<KasimStudentApp> createState() => _KasimStudentAppState();
}

class _KasimStudentAppState extends State<KasimStudentApp> {
  bool isAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasim Secure Exam Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFF38BDF8),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF0284C7),
          surface: Color(0xFF131B2A),
        ),
      ),
      home: isAuthenticated
          ? ExamEntryScreen(
              onLogout: () {
                setState(() {
                  isAuthenticated = false;
                });
              },
            )
          : StudentLoginScreen(
              onLoginSuccess: () {
                setState(() {
                  isAuthenticated = true;
                });
              },
            ),
    );
  }
}
