import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../models/student_session.dart';
import 'api_service.dart';
import 'policy_verifier.dart';
import 'browser_policy_guard.dart';

class LockdownService {
  final ActiveStudentSession session;
  Timer? _monitorTimer;
  Timer? _tickerTimer;
  Timer? _heartbeatTimer;

  bool _isLockedDown = false;
  bool get isLockedDown => _isLockedDown;

  String? _detectedBrowser;
  String? get detectedBrowser => _detectedBrowser;

  bool _isCompliant = true;
  bool get isCompliant => _isCompliant;

  String _statusMessage = "Lockdown initialized";
  String get statusMessage => _statusMessage;

  int _remainingSeconds = 0;
  int get remainingSeconds => _remainingSeconds;

  final Function(bool compliant, String msg, int remainingSeconds)? onStatusUpdate;
  final Function()? onExamExpired;

  Map<String, String> get _browserExecutables {
    final result = <String, String>{};
    final registered = widgetPolicy['registered_browsers'] as List? ?? const [];
    for (final raw in registered) {
      final browser = Map<String, dynamic>.from(raw as Map);
      final name = browser['name']?.toString() ?? 'Browser';
      for (final executable in (browser['executables'] as List? ?? const [])) {
        result[executable.toString().toLowerCase()] = name;
      }
    }
    return result;
  }

  Map<String, dynamic> get widgetPolicy => session.signedPolicy ?? const {};
  bool get _allowsAnyBrowser => widgetPolicy['browser_mode'] == 'ALLOW_ANY';

  LockdownService({
    required this.session,
    int initialRemainingSeconds = 0,
    this.onStatusUpdate,
    this.onExamExpired,
  }) {
    _remainingSeconds = initialRemainingSeconds > 0
        ? initialRemainingSeconds
        : (session.durationMinutes * 60);
  }

  void startLockdownEnforcement() {
    _isLockedDown = true;
    _statusMessage = _allowsAnyBrowser
        ? "Enforcing policy across any installed browser."
        : "Enforcing policy: Only '${session.allowedBrowser}' is permitted.";

    // 1. Local live 1-second countdown ticker
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        if (onStatusUpdate != null) {
          onStatusUpdate!(_isCompliant, _statusMessage, _remainingSeconds);
        }
      } else if (_remainingSeconds <= 0 && _isLockedDown) {
        _remainingSeconds = 0;
        // Verify with server before expiring
        _sendHeartbeat();
      }
    });

    // 2. Fast window & process monitoring loop (every 1 second)
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _enforceLockdownPolicy();
    });

    // 3. Backend heartbeat keepalive (every 4 seconds)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _sendHeartbeat();
    });

    _enforceLockdownPolicy();
    _sendHeartbeat();
  }

  Future<void> _enforceLockdownPolicy() async {
    if (!_isLockedDown) return;

    if (Platform.isWindows) {
      try {
        // 1. Process Monitoring via tasklist
        final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        final output = result.stdout.toString().toLowerCase();

        String? approvedFound;
        List<String> forbiddenDetected = [];

        _browserExecutables.forEach((exe, name) {
          if (output.contains(exe)) {
            if (_allowsAnyBrowser || name.toLowerCase() == session.allowedBrowser.toLowerCase()) {
              approvedFound = name;
            } else {
              forbiddenDetected.add(name);
              // Strict Action: Auto-kill unauthorized browser process!
              _terminateProcess(exe);
            }
          }
        });

        _detectedBrowser = approvedFound ?? (forbiddenDetected.isNotEmpty ? forbiddenDetected.first : null);

        if (forbiddenDetected.isNotEmpty) {
          _isCompliant = false;
          _statusMessage = "VIOLATION BLOCKED: Unauthorized browser (${forbiddenDetected.join(', ')}) was detected and closed!";
          _trapAndFocusAllowedApp();
        } else {
          _isCompliant = true;
          _statusMessage = _allowsAnyBrowser
              ? "Compliant: Browser access policy is active. Unauthorized AI and apps are blocked."
              : "Compliant: Approved browser '${session.allowedBrowser}' enforced. Unauthorized apps blocked.";
        }

        // 2. Active Foreground Window Monitoring via Win32 API
        _checkForegroundWindow();

      } catch (_) {
        _statusMessage = "Monitoring browser security policies...";
      }
    } else {
      _detectedBrowser = session.allowedBrowser;
      _isCompliant = true;
      _statusMessage = _allowsAnyBrowser
          ? "Lockdown active: Browser access policy verified."
          : "Lockdown active: Allowed browser '${session.allowedBrowser}' verified.";
    }

    if (onStatusUpdate != null) {
      onStatusUpdate!(_isCompliant, _statusMessage, _remainingSeconds);
    }
  }

  void _terminateProcess(String exeName) {
    try {
      Process.run('taskkill', ['/F', '/IM', exeName]);
    } catch (_) {}
  }

  void _checkForegroundWindow() {
    try {
      final hwnd = GetForegroundWindow();
      if (hwnd != 0) {
        final titleBuffer = wsalloc(256);
        GetWindowText(hwnd, titleBuffer, 256);
        final title = titleBuffer.toDartString().toLowerCase();
        free(titleBuffer);

        // Check if foreground window is a forbidden browser
        for (final entry in _browserExecutables.entries) {
          final browserName = entry.value.toLowerCase();
          if (!_allowsAnyBrowser && browserName != session.allowedBrowser.toLowerCase()) {
            if (title.contains(browserName) || title.contains(entry.key.replaceAll('.exe', ''))) {
              _isCompliant = false;
              _statusMessage = "RESTRICTION: Focus switched to unauthorized application. Trapping window.";
              _trapAndFocusAllowedApp();
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  void _trapAndFocusAllowedApp() {
    try {
      // Find and bring Kasim student app window to front
      final appNameBuffer = TEXT('Kasim Secure Client');
      final appHwnd = FindWindow(nullptr, appNameBuffer);
      free(appNameBuffer);

      if (appHwnd != 0) {
        SetWindowPos(
          appHwnd,
          HWND_TOPMOST,
          0,
          0,
          0,
          0,
          SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW,
        );
        SetForegroundWindow(appHwnd);
        // Release topmost flag after brief moment so allowed browser can also be used
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_isLockedDown) {
            SetWindowPos(
              appHwnd,
              HWND_NOTOPMOST,
              0,
              0,
              0,
              0,
              SWP_NOMOVE | SWP_NOSIZE,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _sendHeartbeat() async {
    try {
      final hb = await StudentApiService.sendHeartbeat(session.sessionId, _detectedBrowser);

      if (hb.endTime != null) {
        session.endTime = hb.endTime;
      }
      if (hb.startTime != null) {
        session.startTime = hb.startTime;
      }

      // Process signed policy payload if provided
      if (hb.signedPolicy != null) {
        final isValid = PolicyVerifier.verifyPolicyPayload(hb.signedPolicy!);
        if (isValid) {
          await PolicyVerifier.savePolicyToCache(hb.signedPolicy!);
          await BrowserPolicyGuard.applyManagedBrowserPolicies(hb.signedPolicy!);
        }
      }

      // Sync remaining seconds from authoritative server calculation
      if (hb.isExamActive && hb.examStatus == "active") {
        if (hb.timeRemainingSeconds > 0) {
          _remainingSeconds = hb.timeRemainingSeconds;
        }
      } else if (hb.examStatus == "completed" || !hb.isExamActive) {
        _remainingSeconds = 0;
        stopLockdown();
        if (onExamExpired != null) onExamExpired!();
        return;
      }

      if (onStatusUpdate != null) {
        onStatusUpdate!(_isCompliant, _statusMessage, _remainingSeconds);
      }
    } catch (_) {
      // Ignore transient network errors
    }
  }

  void stopLockdown() {
    _isLockedDown = false;
    _tickerTimer?.cancel();
    _monitorTimer?.cancel();
    _heartbeatTimer?.cancel();
    BrowserPolicyGuard.clearManagedBrowserPolicies();
    _statusMessage = "Lockdown restrictions released.";
  }
}
