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
  bool _obscurePassword = true;
  bool isLoading = false;
  String? errorMessage;

  Future<void> _handleSubmit() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final email = emailController.text.trim();

    if (username.isEmpty || password.isEmpty || (!isLoginMode && email.isEmpty)) {
      setState(() {
        errorMessage = "Please fill in all required fields.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLoginMode) {
        await ApiService.login(username, password);
        widget.onLoginSuccess();
      } else {
        await ApiService.register(username, email, password);
        // Auto login after register with dedicated username & password
        await ApiService.login(username, password);
        widget.onLoginSuccess();
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('Failed to fetch') || errStr.contains('ClientException') || errStr.contains('SocketException')) {
        setState(() {
          errorMessage = "Cannot connect to Backend Server (http://localhost:8000).\nPlease make sure the server is running:\n'uvicorn app.main:app --reload --port 8000'";
        });
      } else {
        setState(() {
          errorMessage = errStr;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleAuth() async {
    final googleEmailController = TextEditingController(text: "malikalelica@gmail.com");
    final googleNameController = TextEditingController(text: "Lelica Malika");

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, color: Color(0xFF4285F4)),
            ),
            const SizedBox(width: 12),
            const Text("Google Account Sign In", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sign in or create a lecturer account instantly using your Google credentials:",
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: googleEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Google Email", Icons.email_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: googleNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Full Name", Icons.person_outline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.login, color: Colors.white, size: 18),
            label: const Text("Continue with Google", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      try {
        await ApiService.googleLogin(
          googleEmailController.text.trim(),
          googleNameController.text.trim(),
        );
        widget.onLoginSuccess();
      } catch (e) {
        final errStr = e.toString().replaceAll('Exception: ', '');
        if (errStr.contains('Failed to fetch') || errStr.contains('ClientException')) {
          setState(() {
            errorMessage = "Cannot connect to Backend Server (http://localhost:8000).\nPlease start backend server with 'uvicorn app.main:app --reload --port 8000'";
          });
        } else {
          setState(() {
            errorMessage = errStr;
          });
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
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
                  isLoginMode ? "Sign in with your credentials or Google" : "Create a Lecturer Account with dedicated password",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
                const SizedBox(height: 24),
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
                // Quick Google Sign In Button
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _handleGoogleAuth,
                  icon: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 22),
                  ),
                  label: Text(
                    isLoginMode ? "Sign in with Google" : "Register with Google Account",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF4285F4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("OR DEDICATED LOGIN", style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Dedicated Username", Icons.person_outline),
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
                // Password Field with Password Visibility Eye Toggle Icon
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    "Dedicated Password",
                    Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF8B949E),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      tooltip: _obscurePassword ? "Show Password" : "Hide Password",
                    ),
                  ),
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
                          isLoginMode ? "Sign In with Password" : "Register Dedicated Account",
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

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8B949E)),
      prefixIcon: Icon(icon, color: const Color(0xFF8B949E)),
      suffixIcon: suffixIcon,
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
