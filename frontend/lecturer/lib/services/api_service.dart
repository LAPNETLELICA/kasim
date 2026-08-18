import 'convert_helpers.dart' if (dart.library.html) 'dart:html';
import 'convert_helpers.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exam.dart';

class ApiService {
  static String baseUrl = 'http://localhost:8000/api';
  static String? token;

  static void setToken(String newToken) {
    token = newToken;
  }

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
        'role': 'lecturer',
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  static Future<ExamSession> createExam({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String allowedBrowser,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/exams/'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'allowed_browser': allowedBrowser,
      }),
    );

    if (response.statusCode == 201) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create exam');
    }
  }

  static Future<List<ExamSession>> fetchExams() async {
    final response = await http.get(
      Uri.parse('$baseUrl/exams/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => ExamSession.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load exams');
    }
  }

  static Future<ExamSession> fetchExamDetail(String examId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/exams/$examId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load exam details');
    }
  }

  static Future<ExamSession> toggleExamStatus(String examId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/exams/$examId/toggle'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to toggle exam status');
    }
  }
}
