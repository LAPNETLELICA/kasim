import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/exam.dart';
import '../services/api_service.dart';
import 'live_audit_screen.dart';

class ExamMonitorScreen extends StatefulWidget {
  final String examId;
  const ExamMonitorScreen({super.key, required this.examId});

  @override
  State<ExamMonitorScreen> createState() => _ExamMonitorScreenState();
}

class _ExamMonitorScreenState extends State<ExamMonitorScreen> {
  ExamSession? exam;
  bool isLoading = true;
  bool isActionLoading = false;
  bool isDownloading = false;
  List<CameraFeedItem> cameraFeed = [];
  List<SubmissionItem> submissions = [];
  Timer? pollTimer;
  Timer? tickTimer;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchDetails());
    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && exam?.status == "active") {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await ApiService.fetchExamDetail(widget.examId);
      final cameraFuture = details.cameraRequired
          ? ApiService.fetchCameraFeed(widget.examId)
          : Future.value(<CameraFeedItem>[]);
      final submissionsFuture = details.submissionsEnabled
          ? ApiService.fetchSubmissions(widget.examId)
          : Future.value(<SubmissionItem>[]);
      final cameraItems = await cameraFuture;
      final submissionItems = await submissionsFuture;
      if (mounted) {
        setState(() {
          exam = details;
          cameraFeed = cameraItems;
          submissions = submissionItems;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _downloadAllSubmissions() async {
    if (exam == null || submissions.isEmpty) return;
    setState(() => isDownloading = true);
    try {
      final response = await ApiService.downloadSubmissionZip(exam!.id);
      if (response.statusCode != 200) throw Exception('Download is not available yet');
      final contentDisposition = response.headers['content-disposition'] ?? '';
      final match = RegExp(r'filename="?([^";]+)').firstMatch(contentDisposition);
      final filename = match?.group(1) ?? '${exam!.title}-${DateFormat('yyyy-MM-dd').format(exam!.createdAt)}.zip';
      final blob = html.Blob([response.bodyBytes], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..download = filename
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => isDownloading = false);
    }
  }

  Future<void> _handleStartSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Launch Exam Session?", style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
        content: Text(
          "Starting the session will immediately begin the ${exam?.durationMinutes ?? 60}-minute exam period and enforce the policy on all ${exam?.totalJoinedCount ?? 0} connected students.\n\nLate student entries will be locked.",
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, elevation: 0),
            child: const Text("Start Session Now", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isActionLoading = true);
      try {
        final updated = await ApiService.startExam(widget.examId);
        setState(() {
          exam = updated;
          isActionLoading = false;
        });
      } catch (e) {
        setState(() => isActionLoading = false);
      }
    }
  }

  Future<void> _handleStopSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("End Exam Session?", style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
        content: const Text(
          "Ending the session will conclude the examination and release desktop restrictions for all student agents.",
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorMuted, elevation: 0),
            child: const Text("End Session", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isActionLoading = true);
      try {
        final updated = await ApiService.stopExam(widget.examId);
        setState(() {
          exam = updated;
          isActionLoading = false;
        });
      } catch (e) {
        setState(() => isActionLoading = false);
      }
    }
  }

  String _formatRemainingTime() {
    if (exam == null || exam!.endTime == null) return "00:00:00";
    final diff = exam!.endTime!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    if (diff <= 0) return "00:00:00 (Time Expired)";
    final d = Duration(seconds: diff);
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    final timeFormat = DateFormat('HH:mm:ss');

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Row(
          children: [
            Text(
              exam?.title ?? "Session Monitor",
              style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (exam != null) ...[
              const SizedBox(width: 12),
              _buildStatusBadge(exam!.status),
            ]
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Live Audit Log Stream",
            icon: const Icon(Icons.security, color: AppTheme.primaryGreen),
            onPressed: () {
              if (exam != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => LiveAuditScreen(examId: exam!.id, examTitle: exam!.title),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: "Refresh Roster",
            icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
            onPressed: _fetchDetails,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isLoading || exam == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Session Code & Launch Banner
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: exam!.status == "active" ? AppTheme.primaryGreen : AppTheme.borderGray,
                        width: exam!.status == "active" ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "STUDENT SESSION JOIN CODE",
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              exam!.examCode,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryGreen,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_policyLabel(exam!.policyMode)} • ${exam!.allowedBrowser}${exam!.allowedAi != null ? ' + ${exam!.allowedAi}' : ''} • ${exam!.durationMinutes} mins",
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                        // Actions
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (exam!.status == "waiting") ...[
                              ElevatedButton.icon(
                                onPressed: isActionLoading ? null : _handleStartSession,
                                icon: isActionLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.play_arrow, color: Colors.white),
                                label: const Text("Start Exam Session", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ] else if (exam!.status == "active") ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.softGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text("REMAINING", style: TextStyle(color: AppTheme.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                        Text(
                                          _formatRemainingTime(),
                                          style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: isActionLoading ? null : _handleStopSession,
                                    icon: const Icon(Icons.stop, color: Colors.white, size: 16),
                                    label: const Text("End Session", style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.errorMuted,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(color: AppTheme.creamBg, borderRadius: BorderRadius.circular(8)),
                                child: const Text("Session Concluded", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stat Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem("Total Joined", "${exam!.totalJoinedCount}", Icons.groups_outlined, AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildMetricItem("Active Agents", "${exam!.activeStudentsCount}", Icons.person_outline, AppTheme.accentGreen),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildMetricItem("Documents", "${exam!.submissionCount}", Icons.description_outlined, const Color(0xFF6B4C9A)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildMetricItem("Policy Violations", "${exam!.attendance.where((a) => !a.browserCompliant).length}", Icons.warning_amber, AppTheme.errorMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (exam!.cameraRequired) ...[
                    _buildCameraSection(),
                    const SizedBox(height: 24),
                  ],

                  if (exam!.submissionsEnabled) ...[
                    _buildSubmissionsSection(),
                    const SizedBox(height: 24),
                  ],

                  // Student Roster
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderGray),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Live Student Roster & Device Enforcement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                              Text("${exam!.attendance.length} Devices Registered", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppTheme.borderGray),
                        exam!.attendance.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(child: Text("Waiting for student desktop agents to join lobby...", style: TextStyle(color: AppTheme.textMuted))),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: exam!.attendance.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
                                itemBuilder: (ctx, i) {
                                  final a = exam!.attendance[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.softGreen,
                                      child: Text("${i + 1}", style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    title: Text(a.studentName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 14)),
                                    subtitle: Text("Joined: ${dateFormat.format(a.joinedAt.toLocal())} • Device: ${a.deviceInfo ?? 'Desktop Agent'}", style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (exam!.cameraRequired) ...[
                                          Icon(
                                            a.cameraStatus == 'active' ? Icons.videocam : Icons.videocam_off_outlined,
                                            color: a.cameraStatus == 'active' ? AppTheme.primaryGreen : AppTheme.warningAmber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        if (exam!.submissionsEnabled) ...[
                                          Row(children: [
                                            const Icon(Icons.description_outlined, color: AppTheme.textMuted, size: 15),
                                            const SizedBox(width: 3),
                                            Text('${a.submissionCount}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                                          ]),
                                          const SizedBox(width: 12),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: a.browserCompliant ? AppTheme.softGreen : const Color(0xFFFDE8E8),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            a.browserCompliant ? "COMPLIANT" : "VIOLATION",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: a.browserCompliant ? AppTheme.primaryGreen : AppTheme.errorMuted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(timeFormat.format(a.lastHeartbeat.toLocal()), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace')),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _policyLabel(String mode) {
    const labels = {
      'SPECIFIC_BROWSER': 'Specific browser',
      'SPECIFIC_AI': 'Specific AI only',
      'SPECIFIC_BROWSER_NO_AI': 'Browser without AI',
      'ANY_BROWSER_NO_AI': 'Any browser · no AI',
      'SPECIFIC_BROWSER_AND_AI': 'Browser + specific AI',
    };
    return labels[mode] ?? 'Custom access policy';
  }

  Widget _buildCameraSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppTheme.softGreen, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.videocam_outlined, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 11),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Camera visualization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
            SizedBox(height: 2),
            Text('Latest frame from each student device. Frames refresh with the session monitor.', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          ])),
          Text('${cameraFeed.where((item) => item.cameraStatus == 'active').length}/${cameraFeed.length} active', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
        ]),
        const SizedBox(height: 16),
        if (cameraFeed.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('Camera tiles will appear when students join.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: cameraFeed.length,
              itemBuilder: (_, index) {
                final item = cameraFeed[index];
                final cacheBust = item.frameUpdatedAt?.millisecondsSinceEpoch ?? 0;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(fit: StackFit.expand, children: [
                    Container(color: const Color(0xFF13221A)),
                    if (item.frameAvailable)
                      Image.network(
                        ApiService.cameraFrameUrl(item.sessionId, cacheBust: cacheBust),
                        headers: ApiService.authHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _cameraPlaceholder(item.cameraStatus),
                      )
                    else
                      _cameraPlaceholder(item.cameraStatus),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 18, 10, 9),
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xD9000000)])),
                        child: Row(children: [
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: item.cameraStatus == 'active' ? const Color(0xFF4ADE80) : const Color(0xFFF59E0B), shape: BoxShape.circle)),
                          const SizedBox(width: 7),
                          Expanded(child: Text(item.studentName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            );
          }),
      ]),
    );
  }

  Widget _cameraPlaceholder(String status) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(status == 'denied' ? Icons.videocam_off_outlined : Icons.videocam_outlined, color: const Color(0xFF8AA396), size: 28),
          const SizedBox(height: 7),
          Text(status == 'denied' ? 'Permission denied' : 'Waiting for frame', style: const TextStyle(color: Color(0xFFB6C6BD), fontSize: 10.5)),
        ]),
      );

  Widget _buildSubmissionsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppTheme.cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderGray)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.folder_zip_outlined, color: Color(0xFF6B4C9A), size: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Student documents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
            const SizedBox(height: 2),
            Text('${submissions.length} file${submissions.length == 1 ? '' : 's'} received from ${submissions.map((item) => item.studentName).toSet().length} student${submissions.map((item) => item.studentName).toSet().length == 1 ? '' : 's'}.', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          ])),
          ElevatedButton.icon(
            onPressed: submissions.isEmpty || isDownloading ? null : _downloadAllSubmissions,
            icon: isDownloading
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_outlined, color: Colors.white, size: 17),
            label: const Text('Download all · ZIP', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4C9A), disabledBackgroundColor: AppTheme.borderGray, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
        if (submissions.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.borderLight),
          ...submissions.reversed.take(4).map((item) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              const Icon(Icons.insert_drive_file_outlined, color: AppTheme.textMuted, size: 18),
              const SizedBox(width: 9),
              Expanded(child: Text(item.originalName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
              Text(item.studentName, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(width: 16),
              Text('${(item.sizeBytes / 1024).ceil()} KB', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _buildMetricItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    if (status == "waiting") {
      bg = const Color(0xFFFEF3C7);
      text = AppTheme.warningAmber;
      label = "LOBBY (WAITING)";
    } else if (status == "active") {
      bg = AppTheme.softGreen;
      text = AppTheme.primaryGreen;
      label = "ACTIVE";
    } else {
      bg = const Color(0xFFF3F4F6);
      text = AppTheme.textMuted;
      label = "CONCLUDED";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: text)),
    );
  }
}
