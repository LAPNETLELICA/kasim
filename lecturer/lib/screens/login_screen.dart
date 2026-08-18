import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
        await ApiService.login(
          usernameController.text.trim(),
          passwordController.text.trim(),
        );
        widget.onLoginSuccess();
      } else {
        await ApiService.register(
          usernameController.text.trim(),
          emailController.text.trim(),
          passwordController.text.trim(),
        );
        // Auto login after register
        await ApiService.login(
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
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 10),
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
                    Icon(Icons.security, color: Color(0xFF58A6FF), size: 32),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        "KASIM LECTURER",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isLoginMode ? "Sign in to manage secure exams" : "Create a Lecturer Account",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
                const SizedBox(height: 28),
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D1418),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF85149)),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Color(0xFFFF7B72), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Username", Icons.person_outline),
                ),
                const SizedBox(height: 16),
                if (!isLoginMode) ...[
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Email Address", Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Password", Icons.lock_outline),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isLoginMode ? "Sign In" : "Register Account",
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
                    isLoginMode ? "Don't have an account? Register here" : "Already have an account? Sign in",
                    style: const TextStyle(color: Color(0xFF58A6FF)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8B949E)),
      prefixIcon: Icon(icon, color: const Color(0xFF8B949E)),
      filled: true,
      fillColor: const Color(0xFF0D1117),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF58A6FF)),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
