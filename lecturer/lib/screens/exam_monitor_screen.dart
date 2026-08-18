import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/exam.dart';
import '../services/api_service.dart';

class ExamMonitorScreen extends StatefulWidget {
  final String examId;
  const ExamMonitorScreen({super.key, required this.examId});

  @override
  State<ExamMonitorScreen> createState() => _ExamMonitorScreenState();
}

class _ExamMonitorScreenState extends State<ExamMonitorScreen> {
  ExamSession? exam;
  bool isLoading = true;
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchDetails());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await ApiService.fetchExamDetail(widget.examId);
      if (mounted) {
        setState(() {
          exam = details;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleStatus() async {
    try {
      final updated = await ApiService.toggleExamStatus(widget.examId);
      setState(() => exam = updated);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Text(exam?.title ?? "Exam Monitor", style: const TextStyle(color: Colors.white)),
        actions: [
          if (exam != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Switch(
                value: exam!.isActive,
                onChanged: (_) => _toggleStatus(),
                activeColor: const Color(0xFF3FB950),
              ),
            ),
        ],
      ),
      body: isLoading || exam == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
          : Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  // Top Code Banner
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "UNIQUE EXAM CODE FOR STUDENTS",
                              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              exam!.examCode,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF58A6FF),
                                letterSpacing: 8,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Allowed Browser: ${exam!.allowedBrowser}",
                              style: const TextStyle(color: Color(0xFF3FB950), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Window: ${dateFormat.format(exam!.startTime.toLocal())} - ${dateFormat.format(exam!.endTime.toLocal())}",
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Stat cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Active Students Currently In Exam",
                          "${exam!.activeStudentsCount}",
                          Icons.person_outline,
                          const Color(0xFF3FB950),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildStatCard(
                          "Total Joined Students",
                          "${exam!.totalJoinedCount}",
                          Icons.groups_outlined,
                          const Color(0xFF58A6FF),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildStatCard(
                          "Session Enforcement Status",
                          exam!.isActive ? "Active Lockdown" : "Session Paused",
                          Icons.security,
                          exam!.isActive ? const Color(0xFF1F6FEB) : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
