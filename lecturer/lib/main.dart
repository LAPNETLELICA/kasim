import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const KasimLecturerApp());
}

class AppTheme {
  static const Color creamBg = Color(0xFFF9F7F2);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1E2D24);
  static const Color textMuted = Color(0xFF6B7B70);
  static const Color primaryGreen = Color(0xFF2E6B44);
  static const Color softGreen = Color(0xFFE8F3EB);
  static const Color paleGreen = Color(0xFFD4E8DA);
  static const Color accentGreen = Color(0xFF3F8A58);
  static const Color borderGray = Color(0xFFE2DFD6);
  static const Color borderLight = Color(0xFFECEAE2);
  static const Color errorMuted = Color(0xFFC84545);
  static const Color warningAmber = Color(0xFFD9822B);
  static const Color successGreen = Color(0xFF2E7D32);
}

class KasimLecturerApp extends StatefulWidget {
  const KasimLecturerApp({super.key});

  @override
  State<KasimLecturerApp> createState() => _KasimLecturerAppState();
}

class _KasimLecturerAppState extends State<KasimLecturerApp> {
  bool isLoggedIn = false;
  String currentUserName = "Dr. Lecturer";
  String currentUserEmail = "lecturer@university.edu";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasim — Academic Access Control & Exam Security',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTheme.creamBg,
        primaryColor: AppTheme.primaryGreen,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: AppTheme.primaryGreen,
          secondary: AppTheme.accentGreen,
          surface: AppTheme.cardWhite,
          error: AppTheme.errorMuted,
        ),
        dividerColor: AppTheme.borderGray,
        cardTheme: CardThemeData(
          color: AppTheme.cardWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderGray, width: 1),
          ),
        ),
      ),
      home: isLoggedIn
          ? DashboardScreen(
              userName: currentUserName,
              userEmail: currentUserEmail,
              onLogout: () {
                setState(() {
                  isLoggedIn = false;
                });
              },
            )
          : LoginScreen(
              onLoginSuccess: (name, email) {
                setState(() {
                  currentUserName = name;
                  currentUserEmail = email;
                  isLoggedIn = true;
                });
              },
            ),
    );
  }
}
