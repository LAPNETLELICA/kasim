DateTime? parseUtc(dynamic value) {
  if (value == null) return null;
  String s = value.toString().trim();
  if (s.isEmpty) return null;
  if (!s.endsWith('Z') && !s.contains('+') && !s.contains('-') && s.length >= 19) {
    s = '${s}Z';
  } else if (!s.endsWith('Z') && !s.contains('+') && s.contains('T')) {
    s = '${s}Z';
  }
  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return null;
  }
}

class LockdownRules {
  final bool valid;
  final String examId;
  final String title;
  final String allowedBrowser;
  final String? policyId;
  final Map<String, dynamic>? signedPolicy;
  final int durationMinutes;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isActive;
  final String message;

  LockdownRules({
    required this.valid,
    required this.examId,
    required this.title,
    required this.allowedBrowser,
    this.policyId,
    this.signedPolicy,
    required this.durationMinutes,
    required this.status,
    this.startTime,
    this.endTime,
    required this.isActive,
    required this.message,
  });

  factory LockdownRules.fromJson(Map<String, dynamic> json) {
    return LockdownRules(
      valid: json['valid'] ?? false,
      examId: json['exam_id'] ?? '',
      title: json['title'] ?? '',
      allowedBrowser: json['allowed_browser'] ?? 'Google Chrome',
      policyId: json['policy_id'],
      signedPolicy: json['signed_policy'] != null ? Map<String, dynamic>.from(json['signed_policy']) : null,
      durationMinutes: json['duration_minutes'] ?? 60,
      status: json['status'] ?? 'waiting',
      startTime: parseUtc(json['start_time']),
      endTime: parseUtc(json['end_time']),
      isActive: json['is_active'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class ActiveStudentSession {
  final String sessionId;
  final String examId;
  final String examTitle;
  final String studentName;
  final String allowedBrowser;
  final String? policyId;
  final Map<String, dynamic>? signedPolicy;
  final int durationMinutes;
  String examStatus;
  DateTime? startTime;
  DateTime? endTime;
  String status;
  final DateTime joinedAt;

  ActiveStudentSession({
    required this.sessionId,
    required this.examId,
    required this.examTitle,
    required this.studentName,
    required this.allowedBrowser,
    this.policyId,
    this.signedPolicy,
    required this.durationMinutes,
    required this.examStatus,
    this.startTime,
    this.endTime,
    required this.status,
    required this.joinedAt,
  });

  factory ActiveStudentSession.fromJson(Map<String, dynamic> json) {
    return ActiveStudentSession(
      sessionId: json['session_id'] ?? '',
      examId: json['exam_id'] ?? '',
      examTitle: json['exam_title'] ?? '',
      studentName: json['student_name'] ?? '',
      allowedBrowser: json['allowed_browser'] ?? 'Google Chrome',
      policyId: json['policy_id'],
      signedPolicy: json['signed_policy'] != null ? Map<String, dynamic>.from(json['signed_policy']) : null,
      durationMinutes: json['duration_minutes'] ?? 60,
      examStatus: json['exam_status'] ?? 'waiting',
      startTime: parseUtc(json['start_time']),
      endTime: parseUtc(json['end_time']),
      status: json['status'] ?? 'waiting',
      joinedAt: parseUtc(json['joined_at']) ?? DateTime.now().toUtc(),
    );
  }
}

class HeartbeatResult {
  final String status;
  final String examStatus;
  final bool isExamActive;
  final bool isAllowed;
  final int policyVersion;
  final Map<String, dynamic>? signedPolicy;
  final int timeRemainingSeconds;
  final DateTime? startTime;
  final DateTime? endTime;
  final String message;

  HeartbeatResult({
    required this.status,
    required this.examStatus,
    required this.isExamActive,
    required this.isAllowed,
    this.policyVersion = 1,
    this.signedPolicy,
    required this.timeRemainingSeconds,
    this.startTime,
    this.endTime,
    required this.message,
  });

  factory HeartbeatResult.fromJson(Map<String, dynamic> json) {
    return HeartbeatResult(
      status: json['status'] ?? 'waiting',
      examStatus: json['exam_status'] ?? 'waiting',
      isExamActive: json['is_exam_active'] ?? false,
      isAllowed: json['is_allowed'] ?? true,
      policyVersion: json['policy_version'] ?? 1,
      signedPolicy: json['signed_policy'] != null ? Map<String, dynamic>.from(json['signed_policy']) : null,
      timeRemainingSeconds: json['time_remaining_seconds'] ?? 0,
      startTime: parseUtc(json['start_time']),
      endTime: parseUtc(json['end_time']),
      message: json['message'] ?? '',
    );
  }
}
