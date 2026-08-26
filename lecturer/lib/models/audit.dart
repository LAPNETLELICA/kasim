class AuditViolation {
  final String id;
  final String? examSessionId;
  final String? studentSessionId;
  final String studentName;
  final String? deviceId;
  final String violationType;
  final String resourceName;
  final String actionTaken;
  final String? details;
  final DateTime timestamp;

  AuditViolation({
    required this.id,
    this.examSessionId,
    this.studentSessionId,
    required this.studentName,
    this.deviceId,
    required this.violationType,
    required this.resourceName,
    required this.actionTaken,
    this.details,
    required this.timestamp,
  });

  factory AuditViolation.fromJson(Map<String, dynamic> json) {
    return AuditViolation(
      id: json['id'] ?? '',
      examSessionId: json['exam_session_id'],
      studentSessionId: json['student_session_id'],
      studentName: json['student_name'] ?? 'Unknown Student',
      deviceId: json['device_id'],
      violationType: json['violation_type'] ?? 'SECURITY_ALERT',
      resourceName: json['resource_name'] ?? 'Unknown Resource',
      actionTaken: json['action_taken'] ?? 'BLOCKED',
      details: json['details'],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']).toUtc() : DateTime.now().toUtc(),
    );
  }
}
