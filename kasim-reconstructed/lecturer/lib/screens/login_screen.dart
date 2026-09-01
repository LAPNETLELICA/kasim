import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(String name, String email) onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  final identifierController = TextEditingController();
  final registerNameController = TextEditingController();
  final registerEmailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool isLoading = false;
  String? errorMessage;
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
    scopes: const ['email', 'profile'],
  );

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      if (auth.idToken == null) {
        throw Exception('Google did not return an identity token. Check GOOGLE_CLIENT_ID configuration.');
      }
      final res = await ApiService.googleLogin(auth.idToken!);
      final user = res['user'] ?? {};
      widget.onLoginSuccess(user['username'] ?? account.displayName ?? account.email, user['email'] ?? account.email);
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    final password = passwordController.text.trim();

    if (isLoginMode) {
      final identifier = identifierController.text.trim();
      if (identifier.isEmpty || password.isEmpty) {
        setState(() {
          errorMessage = "Please enter your Email or Platform Name, and Password.";
        });
        return;
      }

      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      try {
        final res = await ApiService.login(identifier, password);
        final user = res['user'] ?? {};
        final name = user['username'] ?? identifier;
        final email = user['email'] ?? "";
        widget.onLoginSuccess(name, email);
      } catch (e) {
        _handleError(e);
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    } else {
      final name = registerNameController.text.trim();
      final email = registerEmailController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
        setState(() {
          errorMessage = "Please fill in all registration fields.";
        });
        return;
      }

      if (password != confirmPassword) {
        setState(() {
          errorMessage = "Passwords do not match.";
        });
        return;
      }

      if (password.length < 6) {
        setState(() {
          errorMessage = "Password must be at least 6 characters long.";
        });
        return;
      }

      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      try {
        await ApiService.register(name, email, password);
        final res = await ApiService.login(email, password);
        final user = res['user'] ?? {};
        widget.onLoginSuccess(user['username'] ?? name, user['email'] ?? email);
      } catch (e) {
        _handleError(e);
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  void _handleError(dynamic e) {
    final errStr = e.toString().replaceAll('Exception: ', '');
    if (errStr.contains('Failed to fetch') || errStr.contains('ClientException') || errStr.contains('SocketException')) {
      setState(() {
        errorMessage = "Cannot connect to Kasim Security Server (http://localhost:8000).\nPlease make sure the backend server is running.";
      });
    } else {
      setState(() {
        errorMessage = errStr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderGray, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Academic Platform Brand Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.softGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.primaryGreen,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "KASIM ACCESS CONTROL",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isLoginMode
                      ? "Lecturer Control Plane & Exam Session Portal"
                      : "Create your academic lecturer account",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 28),

                // Error Message Display
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF8B4B4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.errorMuted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: AppTheme.errorMuted, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (isLoginMode) ...[
                  // Identifier Field (Email OR Platform Name)
                  TextField(
                    controller: identifierController,
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                    decoration: _inputDecoration("Email or Platform Name", Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Registration Fields
                  TextField(
                    controller: registerNameController,
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                    decoration: _inputDecoration("Full Name / Platform Name", Icons.badge_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: registerEmailController,
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration("Institutional Email Address", Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                ],

                // Password Field
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                  decoration: _inputDecoration(
                    "Password",
                    Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                if (!isLoginMode) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                    decoration: _inputDecoration(
                      "Confirm Password",
                      Icons.lock_clock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 26),

                // Submit Button
                ElevatedButton(
                  onPressed: isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isLoginMode ? "Sign In to Control Plane" : "Register Dedicated Account",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),

                const SizedBox(height: 18),
                Row(
                  children: const [
                    Expanded(child: Divider(color: AppTheme.borderGray)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(child: Divider(color: AppTheme.borderGray)),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.g_mobiledata_rounded, color: AppTheme.primaryGreen, size: 26),
                  label: Text(
                    isLoginMode ? 'Continue with Google' : 'Register with Google',
                    style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderGray),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                const SizedBox(height: 18),

                // Mode Toggle
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        isLoginMode = !isLoginMode;
                        errorMessage = null;
                      });
                    },
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
                    child: Text(
                      isLoginMode ? "New lecturer? Create an account" : "Already registered? Sign in here",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
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
      labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.creamBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.borderGray),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
