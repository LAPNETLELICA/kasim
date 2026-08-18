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

class StudentAttendance {
  final String sessionId;
  final String studentName;
  final DateTime joinedAt;
  final String status;
  final String? deviceInfo;
  final bool browserCompliant;
  final DateTime lastHeartbeat;

  StudentAttendance({
    required this.sessionId,
    required this.studentName,
    required this.joinedAt,
    required this.status,
    this.deviceInfo,
    required this.browserCompliant,
    required this.lastHeartbeat,
  });

  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    return StudentAttendance(
      sessionId: json['session_id'] ?? '',
      studentName: json['student_name'] ?? 'Unknown Student',
      joinedAt: parseUtc(json['joined_at']) ?? DateTime.now().toUtc(),
      status: json['status'] ?? 'waiting',
      deviceInfo: json['device_info'],
      browserCompliant: json['browser_compliant'] ?? true,
      lastHeartbeat: parseUtc(json['last_heartbeat']) ?? DateTime.now().toUtc(),
    );
  }
}

class ExamSession {
  final String id;
  final String title;
  final int durationMinutes;
  final String status; // "waiting", "active", "completed"
  final DateTime? startTime;
  final DateTime? endTime;
  final String allowedBrowser;
  final String examCode;
  final bool isActive;
  final String lecturerId;
  final DateTime createdAt;
  final int activeStudentsCount;
  final int totalJoinedCount;
  final List<StudentAttendance> attendance;

  ExamSession({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.status,
    this.startTime,
    this.endTime,
    required this.allowedBrowser,
    required this.examCode,
    required this.isActive,
    required this.lecturerId,
    required this.createdAt,
    this.activeStudentsCount = 0,
    this.totalJoinedCount = 0,
    this.attendance = const [],
  });

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    var rawAttendance = json['attendance'] as List? ?? [];
    List<StudentAttendance> attendanceList =
        rawAttendance.map((item) => StudentAttendance.fromJson(item)).toList();

    return ExamSession(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 60,
      status: json['status'] ?? 'waiting',
      startTime: parseUtc(json['start_time']),
      endTime: parseUtc(json['end_time']),
      allowedBrowser: json['allowed_browser'] ?? 'Google Chrome',
      examCode: json['exam_code'] ?? '',
      isActive: json['is_active'] ?? true,
      lecturerId: json['lecturer_id'] ?? '',
      createdAt: parseUtc(json['created_at']) ?? DateTime.now().toUtc(),
      activeStudentsCount: json['active_students_count'] ?? 0,
      totalJoinedCount: json['total_joined_count'] ?? 0,
      attendance: attendanceList,
    );
  }
}

class AttendanceSummary {
  final String examId;
  final String title;
  final String status;
  final int durationMinutes;
  final DateTime? startTime;
  final DateTime? endTime;
  final int totalAttendees;
  final int activeAttendees;
  final int completedAttendees;
  final List<StudentAttendance> attendanceList;

  AttendanceSummary({
    required this.examId,
    required this.title,
    required this.status,
    required this.durationMinutes,
    this.startTime,
    this.endTime,
    required this.totalAttendees,
    required this.activeAttendees,
    required this.completedAttendees,
    required this.attendanceList,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    var rawList = json['attendance_list'] as List? ?? [];
    List<StudentAttendance> list =
        rawList.map((item) => StudentAttendance.fromJson(item)).toList();

    return AttendanceSummary(
      examId: json['exam_id'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? 'waiting',
      durationMinutes: json['duration_minutes'] ?? 60,
      startTime: parseUtc(json['start_time']),
      endTime: parseUtc(json['end_time']),
      totalAttendees: json['total_attendees'] ?? 0,
      activeAttendees: json['active_attendees'] ?? 0,
      completedAttendees: json['completed_attendees'] ?? 0,
      attendanceList: list,
    );
  }
}
