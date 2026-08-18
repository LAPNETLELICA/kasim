class ExamSession {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String allowedBrowser;
  final String examCode;
  final bool isActive;
  final String lecturerId;
  final DateTime createdAt;
  final int activeStudentsCount;
  final int totalJoinedCount;

  ExamSession({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.allowedBrowser,
    required this.examCode,
    required this.isActive,
    required this.lecturerId,
    required this.createdAt,
    this.activeStudentsCount = 0,
    this.totalJoinedCount = 0,
  });

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    return ExamSession(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      allowedBrowser: json['allowed_browser'] ?? 'Google Chrome',
      examCode: json['exam_code'] ?? '',
      isActive: json['is_active'] ?? true,
      lecturerId: json['lecturer_id'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      activeStudentsCount: json['active_students_count'] ?? 0,
      totalJoinedCount: json['total_joined_count'] ?? 0,
    );
  }
}
