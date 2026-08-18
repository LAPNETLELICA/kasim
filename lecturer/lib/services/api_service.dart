import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exam.dart';

class ApiService {
  static String baseUrl = 'http://localhost:8000/api';
  static String fallbackBaseUrl = 'http://127.0.0.1:8000/api';
  static String? token;

  static void setToken(String newToken) {
    token = newToken;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> _postRequest(String path, Map<String, dynamic> body) async {
    try {
      return await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
    } catch (_) {
      // Fallback to 127.0.0.1 if localhost DNS resolution fails
      return await http.post(
        Uri.parse('$fallbackBaseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
    }
  }

  static Future<http.Response> _getRequest(String path) async {
    try {
      return await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      );
    } catch (_) {
      return await http.get(
        Uri.parse('$fallbackBaseUrl$path'),
        headers: _headers,
      );
    }
  }

  static Future<http.Response> _patchRequest(String path) async {
    try {
      return await http.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      );
    } catch (_) {
      return await http.patch(
        Uri.parse('$fallbackBaseUrl$path'),
        headers: _headers,
      );
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _postRequest('/auth/login', {
      'username': username,
      'password': password,
    });

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
    final response = await _postRequest('/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'role': 'lecturer',
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  static Future<ExamSession> createExam({
    required String title,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    required String allowedBrowser,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'allowed_browser': allowedBrowser,
    };
    if (startTime != null) body['start_time'] = startTime.toUtc().toIso8601String();
    if (endTime != null) body['end_time'] = endTime.toUtc().toIso8601String();
    if (durationMinutes != null) body['duration_minutes'] = durationMinutes;

    final response = await _postRequest('/exams/', body);

    if (response.statusCode == 201) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create exam');
    }
  }

  static Future<List<ExamSession>> fetchExams() async {
    final response = await _getRequest('/exams/');

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => ExamSession.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load exams');
    }
  }

  static Future<ExamSession> fetchExamDetail(String examId) async {
    final response = await _getRequest('/exams/$examId');

    if (response.statusCode == 200) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load exam details');
    }
  }

  static Future<ExamSession> toggleExamStatus(String examId) async {
    final response = await _patchRequest('/exams/$examId/toggle');

    if (response.statusCode == 200) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to toggle exam status');
    }
  }
}
