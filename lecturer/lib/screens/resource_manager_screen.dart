import 'package:flutter/material.dart';
import '../main.dart';
import '../models/resource.dart';
import '../services/api_service.dart';

class ResourceManagerScreen extends StatefulWidget {
  const ResourceManagerScreen({Key? key}) : super(key: key);

  @override
  _ResourceManagerScreenState createState() => _ResourceManagerScreenState();
}

class _ResourceManagerScreenState extends State<ResourceManagerScreen> {
  List<BrowserResource> _browsers = [];
  List<AIResource> _aiServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    try {
      final bList = await ApiService.fetchBrowsers();
      final aList = await ApiService.fetchAIServices();
      if (mounted) {
        setState(() {
          _browsers = bList;
          _aiServices = aList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddBrowserDialog() {
    final nameCtrl = TextEditingController();
    final execsCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Register Custom Browser', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: _inputDeco('Browser Name', 'e.g. Vivaldi, Arc'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: execsCtrl,
                decoration: _inputDeco('Process Executables', 'comma-separated: vivaldi.exe, vivaldi'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: _inputDeco('Description (Optional)', 'Notes on browser identification'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || execsCtrl.text.trim().isEmpty) return;
              final execs = execsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              try {
                await ApiService.addBrowserResource(nameCtrl.text.trim(), execs, descCtrl.text.trim());
                Navigator.pop(ctx);
                _loadResources();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Register Browser', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddAIDialog() {
    final nameCtrl = TextEditingController();
    final domainsCtrl = TextEditingController();
    final execsCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Register Custom AI Service', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: _inputDeco('AI Service Name', 'e.g. DeepSeek, Mistral'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: domainsCtrl,
                decoration: _inputDeco('Domains & Endpoints', 'comma-separated: deepseek.com, api.deepseek.com'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: execsCtrl,
                decoration: _inputDeco('Desktop Binaries (Optional)', 'e.g. DeepSeek.exe'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: _inputDeco('Description (Optional)', 'Notes on AI identification'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || domainsCtrl.text.trim().isEmpty) return;
              final domains = domainsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final execs = execsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              try {
                await ApiService.addAIResource(nameCtrl.text.trim(), domains, execs, descCtrl.text.trim());
                Navigator.pop(ctx);
                _loadResources();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Register AI Service', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppTheme.creamBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.borderGray),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : Padding(
              padding: const EdgeInsets.all(28.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registered Browsers Column
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderGray),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Browser Registry', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                  Text('Dynamic browser resource definitions', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _showAddBrowserDialog,
                                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                label: const Text('Add Browser', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, elevation: 0),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: AppTheme.borderGray),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _browsers.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
                              itemBuilder: (ctx, i) {
                                final b = _browsers[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(color: AppTheme.softGreen, shape: BoxShape.circle),
                                    child: const Icon(Icons.language, color: AppTheme.primaryGreen, size: 20),
                                  ),
                                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 14)),
                                  subtitle: Text('Executables: ${b.executables.join(", ")}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: b.isCustom ? const Color(0xFFFEF3C7) : AppTheme.softGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b.isCustom ? 'Custom' : 'System Default',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: b.isCustom ? AppTheme.warningAmber : AppTheme.primaryGreen),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Registered AI Services Column
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderGray),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('AI Services Registry', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                  Text('Domains & desktop applications', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _showAddAIDialog,
                                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                label: const Text('Add AI Service', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4C9A), elevation: 0),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: AppTheme.borderGray),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _aiServices.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
                              itemBuilder: (ctx, i) {
                                final a = _aiServices[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(color: Color(0xFFF3E8FF), shape: BoxShape.circle),
                                    child: const Icon(Icons.psychology, color: Color(0xFF6B4C9A), size: 20),
                                  ),
                                  title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 14)),
                                  subtitle: Text('Domains: ${a.domains.join(", ")}\nDesktop Apps: ${a.desktopExecutables.isEmpty ? "None" : a.desktopExecutables.join(", ")}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: a.isCustom ? const Color(0xFFFEF3C7) : const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      a.isCustom ? 'Custom' : 'System Default',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: a.isCustom ? AppTheme.warningAmber : const Color(0xFF6B4C9A)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
