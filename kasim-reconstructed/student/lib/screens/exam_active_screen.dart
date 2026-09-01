import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/student_session.dart';
import '../services/lockdown_service.dart';
import '../services/api_service.dart';
import '../services/camera_capture_service.dart';

class ExamActiveScreen extends StatefulWidget {
  final ActiveStudentSession session;
  final int initialRemainingSeconds;
  const ExamActiveScreen({
    super.key,
    required this.session,
    this.initialRemainingSeconds = 0,
  });

  @override
  State<ExamActiveScreen> createState() => _ExamActiveScreenState();
}

class _ExamActiveScreenState extends State<ExamActiveScreen> {
  late LockdownService lockdownService;
  bool isCompliant = true;
  String statusMessage = "Lockdown active and compliant.";
  int remainingSeconds = 0;
  bool isExpired = false;
  bool isUploading = false;
  String? uploadError;
  final List<String> uploadedFiles = [];
  CameraCaptureService? cameraService;
  String cameraStatus = 'not_required';

  @override
  void initState() {
    super.initState();
    
    // Set initial remaining seconds
    if (widget.initialRemainingSeconds > 0) {
      remainingSeconds = widget.initialRemainingSeconds;
    } else if (widget.session.endTime != null) {
      final diff = widget.session.endTime!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
      remainingSeconds = diff > 0 ? diff : (widget.session.durationMinutes * 60);
    } else {
      remainingSeconds = widget.session.durationMinutes * 60;
    }
    
    lockdownService = LockdownService(
      session: widget.session,
      initialRemainingSeconds: remainingSeconds,
      onStatusUpdate: (compliant, msg, seconds) {
        if (mounted) {
          setState(() {
            isCompliant = compliant;
            statusMessage = msg;
            remainingSeconds = seconds;
          });
        }
      },
      onExamExpired: () {
        if (mounted) {
          setState(() {
            isExpired = true;
            statusMessage = "EXAM SESSION COMPLETED: Desktop lockdown automatically released.";
            remainingSeconds = 0;
          });
        }
      },
    );

    lockdownService.startLockdownEnforcement();
    if (widget.session.cameraRequired) {
      cameraStatus = 'pending';
      cameraService = CameraCaptureService(
        sessionId: widget.session.sessionId,
        onStatusChanged: (status) {
          if (mounted) setState(() => cameraStatus = status);
        },
      );
      cameraService!.start();
    }
  }

  @override
  void dispose() {
    lockdownService.stopLockdown();
    cameraService?.stop();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return "00:00:00";
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }

  Future<void> _exitExam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131B2A),
        title: const Text("Exit Exam Session?", style: TextStyle(color: Colors.white)),
        content: Text(
          isExpired
              ? "Close the exam client and return to the main screen?"
              : "Are you sure you want to finish and submit your exam session? Desktop lockdown will be released.",
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          if (!isExpired)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Continue Exam", style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isExpired ? const Color(0xFF0284C7) : const Color(0xFFEF4444),
            ),
            child: Text(isExpired ? "Close App" : "Submit & Exit", style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      lockdownService.stopLockdown();
      await cameraService?.stop();
      await StudentApiService.leaveSession(widget.session.sessionId);
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  Future<void> _pickAndUploadDocument() async {
    setState(() { isUploading = true; uploadError = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt', 'xls', 'xlsx', 'csv',
          'ppt', 'pptx', 'png', 'jpg', 'jpeg', 'zip', 'py', 'js', 'ts',
          'java', 'c', 'cpp', 'html', 'css',
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) throw Exception('The selected file could not be read');
      if (file.size > 25 * 1024 * 1024) throw Exception('The file must be 25 MB or smaller');
      await StudentApiService.uploadSubmission(
        widget.session.sessionId,
        file.name,
        file.bytes!,
      );
      if (mounted) setState(() => uploadedFiles.add(file.name));
    } catch (e) {
      if (mounted) setState(() => uploadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  String _policyDescription() {
    switch (widget.session.policyMode) {
      case 'SPECIFIC_BROWSER':
        return 'Use ${widget.session.allowedBrowser}. Web access is unrestricted.';
      case 'SPECIFIC_AI':
        return 'Use any browser only for ${widget.session.allowedAi ?? 'the selected AI service'}.';
      case 'SPECIFIC_BROWSER_NO_AI':
        return 'Use ${widget.session.allowedBrowser} for standard websites. AI access is blocked.';
      case 'ANY_BROWSER_NO_AI':
        return 'Any installed browser is allowed. AI access is blocked.';
      case 'SPECIFIC_BROWSER_AND_AI':
        return 'Use ${widget.session.allowedBrowser}. Only ${widget.session.allowedAi ?? 'the selected AI'} is authorized.';
      default:
        return 'Follow the access policy shown by your lecturer.';
    }
  }

  Widget _policyFact(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF64748B), size: 17),
        const SizedBox(width: 9),
        SizedBox(width: 92, child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5))),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = remainingSeconds > 0 && remainingSeconds < 300;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              // Top Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpired
                        ? const Color(0xFF64748B)
                        : (isCompliant
                            ? (isLowTime ? const Color(0xFFF59E0B) : const Color(0xFF16A34A))
                            : const Color(0xFFEF4444)),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.examTitle,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF0284C7)),
                              ),
                              child: Text(
                                "Candidate: ${widget.session.studentName}",
                                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF16A34A)),
                              ),
                              child: Text(
                                "Allowed: ${widget.session.allowedBrowser}",
                                style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            if (widget.session.cameraRequired) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F3D35),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: cameraStatus == 'active' ? const Color(0xFF22C55E) : const Color(0xFFF59E0B)),
                                ),
                                child: Row(children: [
                                  Icon(cameraStatus == 'active' ? Icons.videocam : Icons.videocam_off_outlined, color: cameraStatus == 'active' ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24), size: 14),
                                  const SizedBox(width: 5),
                                  Text(cameraStatus == 'active' ? 'Camera active' : 'Camera attention', style: TextStyle(color: cameraStatus == 'active' ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 12)),
                                ]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "TIME REMAINING",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(remainingSeconds),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: isExpired
                                ? const Color(0xFF64748B)
                                : (isLowTime ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Security Policy Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFF1E293B)
                      : (isCompliant ? const Color(0xFF052E16) : const Color(0xFF450A0A)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpired
                        ? const Color(0xFF475569)
                        : (isCompliant ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired
                          ? Icons.lock_open
                          : (isCompliant ? Icons.verified_user : Icons.warning_amber_rounded),
                      color: isExpired
                          ? const Color(0xFF94A3B8)
                          : (isCompliant ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5)),
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: isExpired
                              ? const Color(0xFFE2E8F0)
                              : (isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF212E46)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF082F49), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.policy_outlined, color: Color(0xFF38BDF8), size: 20)),
                            const SizedBox(width: 11),
                            const Text('Active access policy', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 20),
                          Text(_policyDescription(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 15, height: 1.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 18),
                          const Divider(color: Color(0xFF212E46)),
                          const SizedBox(height: 10),
                          _policyFact(Icons.language_outlined, 'Browser', widget.session.allowedBrowser),
                          if (widget.session.allowedAi != null) _policyFact(Icons.auto_awesome_outlined, 'AI service', widget.session.allowedAi!),
                          _policyFact(Icons.shield_outlined, 'Default action', 'Deny unlisted access'),
                          if (widget.session.cameraRequired) _policyFact(Icons.videocam_outlined, 'Camera', cameraStatus == 'active' ? 'Active' : cameraStatus),
                          const Spacer(),
                          Text(isExpired ? 'Restrictions released' : 'The desktop guard checks this policy continuously.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: widget.session.submissionsEnabled
                          ? Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(color: const Color(0xFF131B2A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF212E46))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF2E1065), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.upload_file_outlined, color: Color(0xFFC4B5FD), size: 20)),
                                  const SizedBox(width: 11),
                                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Working documents', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 2),
                                    Text('Upload one or more files before finishing.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                                  ])),
                                ]),
                                const SizedBox(height: 18),
                                OutlinedButton.icon(
                                  onPressed: isExpired || isUploading ? null : _pickAndUploadDocument,
                                  icon: isUploading
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFFC4B5FD), strokeWidth: 2))
                                      : const Icon(Icons.add, color: Color(0xFFC4B5FD), size: 18),
                                  label: Text(isUploading ? 'Uploading…' : 'Choose document', style: const TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6D28D9)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                                if (uploadError != null) ...[
                                  const SizedBox(height: 10),
                                  Text(uploadError!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5)),
                                ],
                                const SizedBox(height: 14),
                                const Divider(color: Color(0xFF212E46)),
                                Expanded(
                                  child: uploadedFiles.isEmpty
                                      ? const Center(child: Text('No document uploaded yet', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)))
                                      : ListView.separated(
                                          itemCount: uploadedFiles.length,
                                          separatorBuilder: (_, __) => const Divider(color: Color(0xFF212E46), height: 1),
                                          itemBuilder: (_, index) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            leading: const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
                                            title: Text(uploadedFiles[index], overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600)),
                                            subtitle: const Text('Uploaded successfully', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                                          ),
                                        ),
                                ),
                              ]),
                            )
                          : Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(color: const Color(0xFF131B2A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF212E46))),
                              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(isExpired ? Icons.check_circle_outline : Icons.security, size: 56, color: isExpired ? const Color(0xFF22C55E) : const Color(0xFF38BDF8)),
                                const SizedBox(height: 14),
                                Text(isExpired ? 'Exam concluded' : 'Exam in progress', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 7),
                                Text(isExpired ? 'Your session has been recorded.' : 'Document upload is disabled for this session.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ])),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Exit Button
              ElevatedButton.icon(
                onPressed: _exitExam,
                icon: Icon(isExpired ? Icons.check : Icons.exit_to_app, color: Colors.white),
                label: Text(
                  isExpired ? "Exit Exam Client" : "Finish & Submit Exam",
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
