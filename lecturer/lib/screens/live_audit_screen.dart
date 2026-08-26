import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audit.dart';
import '../services/api_service.dart';

class LiveAuditScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const LiveAuditScreen({Key? key, required this.examId, required this.examTitle}) : super(key: key);

  @override
  _LiveAuditScreenState createState() => _LiveAuditScreenState();
}

class _LiveAuditScreenState extends State<LiveAuditScreen> {
  List<AuditViolation> _violations = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchViolations();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchViolations());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchViolations() async {
    try {
      final list = await ApiService.fetchExamViolations(widget.examId);
      if (mounted) {
        setState(() {
          _violations = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Audit & Violation Stream: ${widget.examTitle}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchViolations),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _violations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_outlined, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('No Security Violations Logged', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      SizedBox(height: 8),
                      Text('All connected student devices are compliant with active policy rules.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _violations.length,
                  itemBuilder: (ctx, i) {
                    final v = _violations[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[100],
                          child: const Icon(Icons.gpp_bad, color: Colors.red),
                        ),
                        title: Row(
                          children: [
                            Text(v.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(v.violationType, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.red[700],
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        subtitle: Text('Resource: ${v.resourceName}\nAction Taken: ${v.actionTaken}${v.details != null ? "\nDetails: ${v.details}" : ""}'),
                        trailing: Text(
                          '${v.timestamp.hour.toString().padLeft(2, '0')}:${v.timestamp.minute.toString().padLeft(2, '0')}:${v.timestamp.second.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
