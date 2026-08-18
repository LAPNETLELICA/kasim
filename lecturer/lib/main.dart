import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const KasimLecturerApp());
}

class KasimLecturerApp extends StatefulWidget {
  const KasimLecturerApp({super.key});

  @override
  State<KasimLecturerApp> createState() => _KasimLecturerAppState();
}

class _KasimLecturerAppState extends State<KasimLecturerApp> {
  bool isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasim Lecturer Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF58A6FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          secondary: Color(0xFF238636),
          surface: Color(0xFF161B22),
        ),
      ),
      home: isLoggedIn
          ? DashboardScreen(
              onLogout: () {
                setState(() {
                  isLoggedIn = false;
                });
              },
            )
          : LoginScreen(
              onLoginSuccess: () {
                setState(() {
                  isLoggedIn = true;
                });
              },
            ),
    );
  }
}
