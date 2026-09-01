import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student_session.dart';
import '../services/api_service.dart';
import '../services/camera_capture_service.dart';
import 'exam_active_screen.dart';

class ExamLobbyScreen extends StatefulWidget {
  final ActiveStudentSession session;
  const ExamLobbyScreen({super.key, required this.session});

  @override
  State<ExamLobbyScreen> createState() => _ExamLobbyScreenState();
}

class _ExamLobbyScreenState extends State<ExamLobbyScreen> with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  late AnimationController _animController;
  String statusText = "Connected to lobby. Waiting for lecturer to launch session...";
  bool isLeaving = false;
  bool isTransitioning = false;
  CameraCaptureService? _cameraService;
  String cameraStatus = 'not_required';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startLobbyPolling();
    if (widget.session.cameraRequired) {
      cameraStatus = 'pending';
      _cameraService = CameraCaptureService(
        sessionId: widget.session.sessionId,
        onStatusChanged: (status) {
          if (mounted) setState(() => cameraStatus = status);
        },
      );
      _cameraService!.start();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animController.dispose();
    _cameraService?.stop();
    super.dispose();
  }

  void _startLobbyPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkLobbyStatus());
    _checkLobbyStatus();
  }

  Future<void> _checkLobbyStatus() async {
    if (isTransitioning) return;
    try {
      final hb = await StudentApiService.sendHeartbeat(widget.session.sessionId, null);
      if (!mounted) return;

      if ((hb.examStatus == "active" || hb.isExamActive) && hb.examStatus != "completed") {
        isTransitioning = true;
        _pollTimer?.cancel();
        await _cameraService?.stop();
        widget.session.examStatus = "active";
        widget.session.startTime = hb.startTime ?? DateTime.now().toUtc();
        widget.session.endTime = hb.endTime ?? DateTime.now().toUtc().add(Duration(minutes: widget.session.durationMinutes));

        final initialSeconds = hb.timeRemainingSeconds > 0
            ? hb.timeRemainingSeconds
            : (widget.session.durationMinutes * 60);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExamActiveScreen(
              session: widget.session,
              initialRemainingSeconds: initialSeconds,
            ),
          ),
        );
      } else if (hb.examStatus == "completed") {
        _pollTimer?.cancel();
        setState(() {
          statusText = "Exam session has been closed or cancelled by the lecturer.";
        });
      }
    } catch (_) {
      // Ignore network flutter in lobby
    }
  }

  Future<void> _leaveLobby() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131B2A),
        title: const Text("Leave Waiting Room?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to leave the exam lobby? You will need to rejoin before the session starts.",
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Stay", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("Leave", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      _pollTimer?.cancel();
      setState(() => isLeaving = true);
      await _cameraService?.stop();
      await StudentApiService.leaveSession(widget.session.sessionId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131B2A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text("Kasim Secure Client - Waiting Lobby", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Leave Waiting Room",
            icon: const Icon(Icons.exit_to_app, color: Color(0xFFEF4444)),
            onPressed: isLeaving ? null : _leaveLobby,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF212E46)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pulse Indicator
              Center(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0284C7).withAlpha((25 + (_animController.value * 38)).round()),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withAlpha((100 + (_animController.value * 155)).round()),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.access_time_filled, size: 48, color: Color(0xFF38BDF8)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Waiting Room",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                "Candidate: ${widget.session.studentName}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              // Exam Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF212E46)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Exam Title:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Text(
                          widget.session.examTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    if (widget.session.cameraRequired) ...[
                      const Divider(color: Color(0xFF212E46), height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Camera Monitoring:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          Row(children: [
                            Icon(
                              cameraStatus == 'active' ? Icons.videocam : Icons.videocam_off_outlined,
                              color: cameraStatus == 'active' ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cameraStatus == 'active' ? 'Active' : (cameraStatus == 'denied' ? 'Permission denied' : 'Connecting'),
                              style: TextStyle(
                                color: cameraStatus == 'active' ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ],
                    const Divider(color: Color(0xFF212E46), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Allowed Browser:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0369A1).withAlpha(76),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0284C7)),
                          ),
                          child: Text(
                            widget.session.allowedBrowser,
                            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF212E46), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Session Duration:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Text(
                          "${widget.session.durationMinutes} Minutes",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Status notification
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        statusText,
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Lockdown enforcement and timer will automatically engage the moment your lecturer clicks 'Start Session'. Please stay on this screen.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
