import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api_service.dart';


class ProfileSettingsDialog extends StatefulWidget {
  final String currentName;
  final String email;

  const ProfileSettingsDialog({
    super.key,
    required this.currentName,
    required this.email,
  });

  @override
  State<ProfileSettingsDialog> createState() => _ProfileSettingsDialogState();
}


class _ProfileSettingsDialogState extends State<ProfileSettingsDialog> {
  late final TextEditingController nameController;
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    nameController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (newPasswordController.text.isNotEmpty && newPasswordController.text.length < 8) {
      setState(() => error = 'The dedicated password must contain at least 8 characters.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await ApiService.updateProfile(
        name: nameController.text,
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Profile & dedicated password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.email, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 18),
          TextField(controller: nameController, decoration: _input('Profile name')),
          const SizedBox(height: 14),
          TextField(controller: currentPasswordController, obscureText: true, decoration: _input('Current password (password accounts)')),
          const SizedBox(height: 14),
          TextField(controller: newPasswordController, obscureText: true, decoration: _input('New dedicated password')),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: AppTheme.errorMuted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          const Text('Google accounts can add a dedicated password without entering a current password.', style: TextStyle(fontSize: 11, height: 1.35, color: AppTheme.textMuted)),
        ]),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
        ElevatedButton(
          onPressed: saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, elevation: 0),
          child: saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.creamBg,
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.borderGray), borderRadius: BorderRadius.circular(9)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.primaryGreen), borderRadius: BorderRadius.circular(9)),
      );
}
