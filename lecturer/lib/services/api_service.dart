import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exam.dart';
import '../models/resource.dart';
import '../models/policy.dart';
import '../models/audit.dart';


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

  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await _postRequest('/auth/login', {
      'identifier': identifier,
      'username': identifier,
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

  static Future<Map<String, dynamic>> googleLogin(String email, String name) async {
    final response = await _postRequest('/auth/google', {
      'email': email,
      'name': name,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      token = data['access_token'];
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Google authentication failed');
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
    required int durationMinutes,
    required String allowedBrowser,
    String? policyId,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'duration_minutes': durationMinutes,
      'allowed_browser': allowedBrowser,
      if (policyId != null) 'policy_id': policyId,
    };

    final response = await _postRequest('/exams/', body);

    if (response.statusCode == 201) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create exam');
    }
  }

  static Future<List<BrowserResource>> fetchBrowsers() async {
    final response = await _getRequest('/resources/browsers');
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => BrowserResource.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load browser resources');
    }
  }

  static Future<BrowserResource> addBrowserResource(String name, List<String> executables, String? description) async {
    final response = await _postRequest('/resources/browsers', {
      'name': name,
      'executables': executables,
      'description': description,
    });

    if (response.statusCode == 201) {
      return BrowserResource.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to add browser resource');
    }
  }

  static Future<List<AIResource>> fetchAIServices() async {
    final response = await _getRequest('/resources/ai-services');
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => AIResource.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load AI resources');
    }
  }

  static Future<AIResource> addAIResource(String name, List<String> domains, List<String> desktopExecutables, String? description) async {
    final response = await _postRequest('/resources/ai-services', {
      'name': name,
      'domains': domains,
      'desktop_executables': desktopExecutables,
      'description': description,
    });

    if (response.statusCode == 201) {
      return AIResource.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to add AI resource');
    }
  }

  static Future<List<AccessPolicy>> fetchPolicies() async {
    final response = await _getRequest('/policies');
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => AccessPolicy.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load policies');
    }
  }

  static Future<AccessPolicy> createPolicy(Map<String, dynamic> policyData) async {
    final response = await _postRequest('/policies', policyData);
    if (response.statusCode == 201) {
      return AccessPolicy.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create access policy');
    }
  }

  static Future<PolicyPreviewResponse> previewDraftPolicy(Map<String, dynamic> policyData) async {
    final response = await _postRequest('/policies/preview-draft', policyData);
    if (response.statusCode == 200) {
      return PolicyPreviewResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to generate policy preview');
    }
  }

  static Future<List<AuditViolation>> fetchExamViolations(String examId) async {
    final response = await _getRequest('/audit/violations/$examId');
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => AuditViolation.fromJson(item)).toList();
    } else {
      throw Exception('Failed to fetch exam audit violations');
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

  static Future<ExamSession> startExam(String examId) async {
    final response = await _postRequest('/exams/$examId/start', {});

    if (response.statusCode == 200) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to start exam session');
    }
  }

  static Future<ExamSession> stopExam(String examId) async {
    final response = await _postRequest('/exams/$examId/stop', {});

    if (response.statusCode == 200) {
      return ExamSession.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to stop exam session');
    }
  }

  static Future<AttendanceSummary> fetchExamAttendance(String examId) async {
    final response = await _getRequest('/exams/$examId/attendance');

    if (response.statusCode == 200) {
      return AttendanceSummary.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load attendance report');
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

