import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
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
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Text(
          'Live Audit Log: ${widget.examTitle}',
          style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.textMuted), onPressed: _fetchViolations),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _violations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: AppTheme.softGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.shield_outlined, size: 48, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(height: 16),
                      const Text('No Policy Violations Recorded', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                      const SizedBox(height: 6),
                      const Text('All connected student devices are strictly compliant with the active policy.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _violations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final v = _violations[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderGray),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFFFDE8E8), shape: BoxShape.circle),
                            child: const Icon(Icons.gpp_bad, color: AppTheme.errorMuted, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(v.studentName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDE8E8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        v.violationType,
                                        style: const TextStyle(color: AppTheme.errorMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Resource: ${v.resourceName} • Action: ${v.actionTaken}${v.details != null ? " • ${v.details}" : ""}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${v.timestamp.hour.toString().padLeft(2, '0')}:${v.timestamp.minute.toString().padLeft(2, '0')}:${v.timestamp.second.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
