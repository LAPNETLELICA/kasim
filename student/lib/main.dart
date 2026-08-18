import 'package:flutter/material.dart';
import 'screens/exam_entry_screen.dart';

void main() {
  runApp(const KasimStudentApp());
}

class KasimStudentApp extends StatelessWidget {
  const KasimStudentApp({super.key});

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
      home: const ExamEntryScreen(),
    );
  }
}
