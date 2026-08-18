import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student_session.dart';

class StudentApiService {
  static String baseUrl = 'http://localhost:8000/api';
  static String? token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      token = data['access_token'];
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }

  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'role': 'student',
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  static Future<LockdownRules> verifyExamCode(String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sessions/verify-code'),
      headers: _headers,
      body: jsonEncode({'exam_code': code}),
    );

    if (response.statusCode == 200) {
      return LockdownRules.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to verify exam code');
    }
  }

  static Future<ActiveStudentSession> joinExamSession(String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sessions/join'),
      headers: _headers,
      body: jsonEncode({
        'exam_code': code,
        'device_info': 'Kasim Desktop Lockdown Client (Windows 11)',
      }),
    );

    if (response.statusCode == 200) {
      return ActiveStudentSession.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to join exam session');
    }
  }

  static Future<Map<String, dynamic>> sendHeartbeat(
      String sessionId, String? runningBrowser) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sessions/heartbeat'),
      headers: _headers,
      body: jsonEncode({
        'session_id': sessionId,
        'current_running_browser': runningBrowser,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Heartbeat check failed');
    }
  }

  static Future<void> leaveSession(String sessionId) async {
    await http.post(
      Uri.parse('$baseUrl/sessions/leave?session_id=$sessionId'),
      headers: _headers,
    );
  }
}
