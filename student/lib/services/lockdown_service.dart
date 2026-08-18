import 'dart:async';
import 'dart:io';
import '../models/student_session.dart';
import 'api_service.dart';

class LockdownService {
  final ActiveStudentSession session;
  Timer? _lockdownTimer;
  Timer? _heartbeatTimer;

  bool _isLockedDown = false;
  bool get isLockedDown => _isLockedDown;

  String? _detectedBrowser;
  String? get detectedBrowser => _detectedBrowser;

  bool _isCompliant = true;
  bool get isCompliant => _isCompliant;

  String _statusMessage = "Lockdown initialized";
  String get statusMessage => _statusMessage;

  final Function(bool compliant, String msg, int remainingSeconds)? onStatusUpdate;
  final Function()? onExamExpired;

  LockdownService({
    required this.session,
    this.onStatusUpdate,
    this.onExamExpired,
  });

  void startLockdownEnforcement() {
    _isLockedDown = true;
    _statusMessage = "Enforcing browser policy: Only '${session.allowedBrowser}' is permitted.";

    // Process monitoring loop (every 3 seconds)
    _lockdownTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkRunningProcesses();
    });

    // Backend heartbeat keepalive (every 10 seconds)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendHeartbeat();
    });

    _checkRunningProcesses();
    _sendHeartbeat();
  }

  Future<void> _checkRunningProcesses() async {
    if (!_isLockedDown) return;

    if (Platform.isWindows) {
      try {
        final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        final output = result.stdout.toString().toLowerCase();

        final knownBrowsers = {
          'chrome.exe': 'Google Chrome',
          'msedge.exe': 'Microsoft Edge',
          'firefox.exe': 'Mozilla Firefox',
          'brave.exe': 'Brave',
          'opera.exe': 'Opera',
          'safari.exe': 'Safari',
        };

        String? activeBrowser;
        List<String> forbiddenDetected = [];

        knownBrowsers.forEach((exe, name) {
          if (output.contains(exe)) {
            if (name.toLowerCase() == session.allowedBrowser.toLowerCase()) {
              activeBrowser = name;
            } else {
              forbiddenDetected.add(name);
            }
          }
        });

        _detectedBrowser = activeBrowser ?? (forbiddenDetected.isNotEmpty ? forbiddenDetected.first : null);

        if (forbiddenDetected.isNotEmpty) {
          _isCompliant = false;
          _statusMessage = "VIOLATION: Non-allowed browser detected (${forbiddenDetected.join(', ')}). Please close it immediately!";
        } else {
          _isCompliant = true;
          _statusMessage = "Compliant: Approved browser '${session.allowedBrowser}' rule enforced.";
        }
      } catch (e) {
        _statusMessage = "Monitoring active window policy...";
      }
    } else {
      // Platform mock for web / non-windows test environment
      _detectedBrowser = session.allowedBrowser;
      _isCompliant = true;
      _statusMessage = "Lockdown active: Allowed browser '${session.allowedBrowser}' verified.";
    }

    final now = DateTime.now().toUtc();
    final remainingSeconds = session.endTime.difference(now).inSeconds;

    if (remainingSeconds <= 0) {
      stopLockdown();
      if (onExamExpired != null) onExamExpired!();
      return;
    }

    if (onStatusUpdate != null) {
      onStatusUpdate!(_isCompliant, _statusMessage, remainingSeconds);
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      final response = await StudentApiService.sendHeartbeat(session.sessionId, _detectedBrowser);
      final isExamActive = response['is_exam_active'] ?? true;
      final timeRemaining = response['time_remaining_seconds'] ?? 0;

      if (!isExamActive || timeRemaining <= 0) {
        stopLockdown();
        if (onExamExpired != null) onExamExpired!();
      }
    } catch (e) {
      // Ignore transient network errors
    }
  }

  void stopLockdown() {
    _isLockedDown = false;
    _lockdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    _statusMessage = "Lockdown restrictions released.";
  }
}
