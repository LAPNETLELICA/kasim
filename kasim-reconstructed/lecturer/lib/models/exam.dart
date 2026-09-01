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
  final String cameraStatus;
  final DateTime? cameraFrameUpdatedAt;
  final int submissionCount;
  final DateTime? completedAt;

  StudentAttendance({
    required this.sessionId,
    required this.studentName,
    required this.joinedAt,
    required this.status,
    this.deviceInfo,
    required this.browserCompliant,
    required this.lastHeartbeat,
    this.cameraStatus = 'not_required',
    this.cameraFrameUpdatedAt,
    this.submissionCount = 0,
    this.completedAt,
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
      cameraStatus: json['camera_status'] ?? 'not_required',
      cameraFrameUpdatedAt: parseUtc(json['camera_frame_updated_at']),
      submissionCount: json['submission_count'] ?? 0,
      completedAt: parseUtc(json['completed_at']),
    );
  }
}

class ExamSession {
  final String id;
  final String title;
  final String? description;
  final int durationMinutes;
  final String status; // "waiting", "active", "completed"
  final DateTime? startTime;
  final DateTime? endTime;
  final String allowedBrowser;
  final String? allowedAi;
  final String policyMode;
  final bool cameraRequired;
  final bool submissionsEnabled;
  final String examCode;
  final bool isActive;
  final String lecturerId;
  final DateTime createdAt;
  final int activeStudentsCount;
  final int totalJoinedCount;
  final int submissionCount;
  final List<StudentAttendance> attendance;

  ExamSession({
    required this.id,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.status,
    this.startTime,
    this.endTime,
    required this.allowedBrowser,
    this.allowedAi,
    this.policyMode = 'SPECIFIC_BROWSER_NO_AI',
    this.cameraRequired = false,
    this.submissionsEnabled = true,
    required this.examCode,
    required this.isActive,
    required this.lecturerId,
    required this.createdAt,
    this.activeStudentsCount = 0,
    this.totalJoinedCount = 0,
    this.submissionCount = 0,
    this.attendance = const [],
  });

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    var rawAttendance = json['attendance'] as List? ?? [];
    List<StudentAttendance> attendanceList =
        rawAttendance.map((item) => StudentAttendance.fromJson(item)).toList();

    return ExamSession(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      durationMinutes: json['duration_minutes'] ?? 60,
      status: json['status'] ?? 'waiting',
      startTime: parseUtc(json['start_time']),
      endTime: parseUtc(json['end_time']),
      allowedBrowser: json['allowed_browser'] ?? 'Any installed browser',
      allowedAi: json['allowed_ai'],
      policyMode: json['policy_mode'] ?? 'SPECIFIC_BROWSER_NO_AI',
      cameraRequired: json['camera_required'] ?? false,
      submissionsEnabled: json['submissions_enabled'] ?? true,
      examCode: json['exam_code'] ?? '',
      isActive: json['is_active'] ?? true,
      lecturerId: json['lecturer_id'] ?? '',
      createdAt: parseUtc(json['created_at']) ?? DateTime.now().toUtc(),
      activeStudentsCount: json['active_students_count'] ?? 0,
      totalJoinedCount: json['total_joined_count'] ?? 0,
      submissionCount: json['submission_count'] ?? 0,
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
  final int submissionCount;
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
    this.submissionCount = 0,
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
      submissionCount: json['submission_count'] ?? 0,
      attendanceList: list,
    );
  }
}

class CameraFeedItem {
  final String sessionId;
  final String studentName;
  final String cameraStatus;
  final DateTime? frameUpdatedAt;
  final bool frameAvailable;

  const CameraFeedItem({
    required this.sessionId,
    required this.studentName,
    required this.cameraStatus,
    this.frameUpdatedAt,
    required this.frameAvailable,
  });

  factory CameraFeedItem.fromJson(Map<String, dynamic> json) => CameraFeedItem(
        sessionId: json['session_id'] ?? '',
        studentName: json['student_name'] ?? 'Student',
        cameraStatus: json['camera_status'] ?? 'pending',
        frameUpdatedAt: parseUtc(json['frame_updated_at']),
        frameAvailable: json['frame_available'] ?? false,
      );
}

class SubmissionItem {
  final String id;
  final String studentName;
  final String originalName;
  final int sizeBytes;
  final DateTime uploadedAt;

  const SubmissionItem({
    required this.id,
    required this.studentName,
    required this.originalName,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory SubmissionItem.fromJson(Map<String, dynamic> json) => SubmissionItem(
        id: json['id'] ?? '',
        studentName: json['student_name'] ?? 'Student',
        originalName: json['original_name'] ?? 'submission',
        sizeBytes: json['size_bytes'] ?? 0,
        uploadedAt: parseUtc(json['uploaded_at']) ?? DateTime.now().toUtc(),
      );
}
