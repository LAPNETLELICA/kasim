import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StudentLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const StudentLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  bool isLoginMode = true;
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  Future<void> _handleSubmit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLoginMode) {
        await StudentApiService.login(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
        widget.onLoginSuccess();
      } else {
        await StudentApiService.register(
          usernameController.text.trim(),
          emailController.text.trim(),
          passwordController.text.trim(),
        );
        await StudentApiService.login(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
        widget.onLoginSuccess();
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF212E46)),
            boxShadow: const [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.desktop_windows, color: Color(0xFF38BDF8), size: 36),
                  SizedBox(width: 12),
                  Text(
                    "KASIM SECURE",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isLoginMode ? "Student Identification & Portal Access" : "Create Student Account",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 28),
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Student Username", Icons.person),
              ),
              const SizedBox(height: 16),
              if (!isLoginMode) ...[
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Email Address", Icons.email),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Password", Icons.lock),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isLoginMode ? "Authenticate" : "Create Student Account",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLoginMode = !isLoginMode;
                    errorMessage = null;
                  });
                },
                child: Text(
                  isLoginMode ? "Need a student account? Register" : "Already registered? Sign in",
                  style: const TextStyle(color: Color(0xFF38BDF8)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
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
    );
  }
}
