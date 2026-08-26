import 'package:flutter/material.dart';
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
      setState(() {
        _browsers = bList;
        _aiServices = aList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading resources: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddBrowserDialog() {
    final nameCtrl = TextEditingController();
    final execsCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Custom Browser'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Browser Name (e.g. Vivaldi)')),
            TextField(controller: execsCtrl, decoration: const InputDecoration(labelText: 'Executables (comma separated, e.g. vivaldi.exe, vivaldi)')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || execsCtrl.text.trim().isEmpty) return;
              final execs = execsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              try {
                await ApiService.addBrowserResource(nameCtrl.text.trim(), execs, descCtrl.text.trim());
                Navigator.pop(ctx);
                _loadResources();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Add Browser'),
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
        title: const Text('Register Custom AI Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'AI Service Name (e.g. DeepSeek)')),
            TextField(controller: domainsCtrl, decoration: const InputDecoration(labelText: 'Domains (comma separated, e.g. deepseek.com, api.deepseek.com)')),
            TextField(controller: execsCtrl, decoration: const InputDecoration(labelText: 'Desktop Executables (Optional, e.g. DeepSeek.exe)')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || domainsCtrl.text.trim().isEmpty) return;
              final domains = domainsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final execs = execsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              try {
                await ApiService.addAIResource(nameCtrl.text.trim(), domains, execs, descCtrl.text.trim());
                Navigator.pop(ctx);
                _loadResources();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Add AI Service'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Resource Registry'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registered Browsers Column
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Browsers Registry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  onPressed: _showAddBrowserDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('+ Add Browser'),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _browsers.length,
                                itemBuilder: (ctx, i) {
                                  final b = _browsers[i];
                                  return ListTile(
                                    leading: Icon(Icons.web, color: Colors.blue[700]),
                                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Executables: ${b.executables.join(", ")}'),
                                    trailing: b.isCustom
                                        ? const Chip(label: Text('Custom', style: TextStyle(fontSize: 10)), backgroundColor: Colors.orangeAccent)
                                        : const Chip(label: Text('System Default', style: TextStyle(fontSize: 10))),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Registered AI Services Column
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('AI Services Registry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  onPressed: _showAddAIDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('+ Add AI Service'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _aiServices.length,
                                itemBuilder: (ctx, i) {
                                  final a = _aiServices[i];
                                  return ListTile(
                                    leading: Icon(Icons.psychology, color: Colors.purple[700]),
                                    title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Domains: ${a.domains.join(", ")}\nApps: ${a.desktopExecutables.isEmpty ? "None" : a.desktopExecutables.join(", ")}'),
                                    trailing: a.isCustom
                                        ? const Chip(label: Text('Custom', style: TextStyle(fontSize: 10)), backgroundColor: Colors.orangeAccent)
                                        : const Chip(label: Text('System Default', style: TextStyle(fontSize: 10))),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
