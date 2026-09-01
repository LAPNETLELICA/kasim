import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/student_session.dart';

class StudentApiService {
  static String baseUrl = const String.fromEnvironment(
    'KASIM_API_URL',
    defaultValue: 'http://localhost:8000/api',
  );
  static String fallbackBaseUrl = 'http://127.0.0.1:8000/api';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  static Future<http.Response> _postRequest(String path, Map<String, dynamic> body) async {
    try {
      return await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
    } catch (_) {
      return await http.post(
        Uri.parse('$fallbackBaseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
    }
  }

  static Future<LockdownRules> verifyExamCode(String code) async {
    final response = await _postRequest('/sessions/verify-code', {'exam_code': code});

    if (response.statusCode == 200) {
      return LockdownRules.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to verify exam code');
    }
  }

  static Future<ActiveStudentSession> joinExamSession(String code, String studentName) async {
    final response = await _postRequest('/sessions/join', {
      'exam_code': code,
      'student_name': studentName,
      'device_info': 'Kasim Desktop Lockdown Client (Windows 11)',
    });

    if (response.statusCode == 200) {
      return ActiveStudentSession.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to join exam session');
    }
  }

  static Future<HeartbeatResult> sendHeartbeat(
      String sessionId, String? runningBrowser) async {
    final response = await _postRequest('/sessions/heartbeat', {
      'session_id': sessionId,
      'current_running_browser': runningBrowser,
    });

    if (response.statusCode == 200) {
      return HeartbeatResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Heartbeat check failed');
    }
  }

  static Future<void> leaveSession(String sessionId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/sessions/leave?session_id=$sessionId'),
        headers: _headers,
      );
    } catch (_) {
      await http.post(
        Uri.parse('$fallbackBaseUrl/sessions/leave?session_id=$sessionId'),
        headers: _headers,
      );
    }
  }

  static Future<void> updateCameraStatus(String sessionId, String status) async {
    final response = await _postRequest('/camera/$sessionId/status', {'status': status});
    if (response.statusCode != 200) {
      throw Exception('Could not update camera status');
    }
  }

  static Future<void> uploadCameraFrame(String sessionId, Uint8List bytes) async {
    Future<http.StreamedResponse> send(String root) async {
      final request = http.MultipartRequest('POST', Uri.parse('$root/camera/$sessionId/frame'));
      request.files.add(http.MultipartFile.fromBytes(
        'frame',
        bytes,
        filename: 'camera.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
      return request.send();
    }

    http.StreamedResponse response;
    try {
      response = await send(baseUrl);
    } catch (_) {
      response = await send(fallbackBaseUrl);
    }
    if (response.statusCode != 200) {
      throw Exception('Camera frame upload failed');
    }
  }

  static Future<Map<String, dynamic>> uploadSubmission(
    String sessionId,
    String fileName,
    Uint8List bytes,
  ) async {
    Future<http.StreamedResponse> send(String root) async {
      final request = http.MultipartRequest('POST', Uri.parse('$root/submissions/$sessionId'));
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      return request.send();
    }

    http.StreamedResponse streamed;
    try {
      streamed = await send(baseUrl);
    } catch (_) {
      streamed = await send(fallbackBaseUrl);
    }
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 201) return jsonDecode(response.body);
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Document upload failed');
  }
}
