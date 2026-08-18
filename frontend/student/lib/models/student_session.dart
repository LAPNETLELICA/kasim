class LockdownRules {
  final bool valid;
  final String examId;
  final String title;
  final String allowedBrowser;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final String message;

  LockdownRules({
    required this.valid,
    required this.examId,
    required this.title,
    required this.allowedBrowser,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.message,
  });

  factory LockdownRules.fromJson(Map<String, dynamic> json) {
    return LockdownRules(
      valid: json['valid'] ?? false,
      examId: json['exam_id'] ?? '',
      title: json['title'] ?? '',
      allowedBrowser: json['allowed_browser'] ?? 'Google Chrome',
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      isActive: json['is_active'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class ActiveStudentSession {
  final String sessionId;
  final String examId;
  final String examTitle;
  final String allowedBrowser;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final DateTime joinedAt;

  ActiveStudentSession({
    required this.sessionId,
    required this.examId,
    required this.examTitle,
    required this.allowedBrowser,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.joinedAt,
  });

  factory ActiveStudentSession.fromJson(Map<String, dynamic> json) {
    return ActiveStudentSession(
      sessionId: json['session_id'] ?? '',
      examId: json['exam_id'] ?? '',
      examTitle: json['exam_title'] ?? '',
      allowedBrowser: json['allowed_browser'] ?? 'Google Chrome',
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      status: json['status'] ?? 'active',
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}
