// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:autism/secrets.dart';

class AuthService {
  // Use global constant from secrets.dart + /auth
  static const String baseUrl = '$BACKEND_URL/auth';

  static const _storage = FlutterSecureStorage();

  // Helper to parse and throw clean error message
  static void _handleResponse(http.Response response) {
    // Backend returns 201 with body containing Status: "OK" for successful signup
    if (response.statusCode == 201 || response.statusCode == 200) {
      // 201 Created - signup successful
      return;
    }

    // Check if response body is empty
    if (response.body.isEmpty) {
      throw Exception(
        'Server returned empty response (status: ${response.statusCode})',
      );
    }

    try {
      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && (body['Status'] == 'Ok')) {
        // Success
        return;
      } else if (response.statusCode >= 400 || body['Status'] == 'Error') {
        // Any error from backend
        final message = body['Message'] ?? 'Unknown error occurred';
        throw Exception(message);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // If JSON parsing fails
      if (e.toString().contains('FormatException')) {
        throw Exception('Invalid server response: ${response.body}');
      }
      rethrow;
    }
  }

  // Student Signup
  static Future<String> studentSignup(
    String fullName,
    String email,
    String description,
    String password,
    String dob,
    String institution,
  ) async {
    print('📤 Student Signup Request:');
    print('   URL: $baseUrl/student/signup');
    print('   FullName: $fullName');
    print('   Email: $email');

    final response = await http.post(
      Uri.parse('$baseUrl/student/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'description': description,
        'password': password,
        'dob': dob,
        'institution': institution,
      }),
    );

    print('📥 Signup Response:');
    print('   Status Code: ${response.statusCode}');
    print('   Body: ${response.body}');
    print('   Body Length: ${response.body.length}');

    _handleResponse(response); // This will throw if not OK
    return 'Student signup successful! You can now login.';
  }

  // Parent Signup
  static Future<String> parentSignup(
    String fullName,
    String email,
    String password,
  ) async {
    print('📤 Parent Signup Request:');
    print('   URL: $baseUrl/parent/signup');

    final response = await http.post(
      Uri.parse('$baseUrl/parent/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );

    print('📥 Response: ${response.statusCode} | Body: ${response.body}');

    _handleResponse(response);
    return 'Parent signup successful! You can now login.';
  }

  // Teacher Signup
  static Future<String> teacherSignup(
    String fullName,
    String email,
    String password,
    String institution,
  ) async {
    print('📤 Teacher Signup Request:');
    print('   URL: $baseUrl/teacher/signup');

    final response = await http.post(
      Uri.parse('$baseUrl/teacher/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
        'institution': institution,
      }),
    );

    print('📥 Response: ${response.statusCode} | Body: ${response.body}');

    _handleResponse(response);
    return 'Teacher signup successful! You can now login.';
  }

  // Sign In (Generic)
  static Future<void> signin({
    required String email,
    required String password,
  }) async {
    print('🔐 Signin attempt:');
    print('   Email: $email');
    print('   URL: $baseUrl/signin');

    final response = await http.post(
      Uri.parse('$baseUrl/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('📦 Parsed data: $data');

      if (data['_id'] != null) {
        print('✅ Login successful! Saving user ID...');

        final userId = data['_id'];
        final userRole = data['role'] ?? 'student';
        final username = data['username'] ?? 'Friend';
        final email = data['email'] ?? '';

        print('🔑 USER ID: $userId');
        print('🔑 ROLE: $userRole');

        await _storage.write(key: 'user_id', value: userId);
        await _storage.write(key: 'user_role', value: userRole.toLowerCase());
        await _storage.write(key: 'user_name', value: username);
        await _storage.write(key: 'user_email', value: email);

        await _saveProfile(userId);
        print('✅ User details saved successfully to secure storage');
        return;
      } else {
        throw Exception('Login failed: Invalid server response');
      }
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['Message'] ?? 'Login failed');
    }
  }

  static Future<bool> isLoggedIn() async {
    final userId = await _storage.read(key: 'user_id');
    final profile = await _storage.read(key: 'user_profile');
    return userId != null &&
        userId.isNotEmpty &&
        profile != null &&
        profile.isNotEmpty;
  }

  // Getter for the current User ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  /// Get the role of the logged-in user (we save it during signin)
  static Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
  }

  static Future<void> _saveProfile(String userId) async {
    var url_ = baseUrl.split("/");
    url_.removeLast();
    var baseurl = url_.join("/");

    // Pass X-User-Id header instead of Bearer token
    final resp = await http.get(
      Uri.parse("$baseurl/profile"),
      headers: {'Content-Type': 'application/json', 'X-User-Id': userId},
    );

    if (resp.statusCode == 200) {
      await _storage.write(key: 'user_profile', value: resp.body);
    }
  }

  // --- New Methods ---

  /// Fetch list of students for the logged-in parent/teacher
  static Future<List<dynamic>> getStudents() async {
    final userId = await getUserId();
    if (userId == null) throw Exception('Not authenticated');

    var url_ = baseUrl.split("/");
    url_.removeLast(); // remove /auth
    var baseurl = url_.join("/");

    // Endpoint: GET /user/students
    final resp = await http.get(
      Uri.parse('$baseurl/user/students'),
      headers: {'Content-Type': 'application/json', 'X-User-Id': userId},
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['students'] ?? [];
    } else {
      throw Exception('Failed to fetch students: ${resp.body}');
    }
  }

  static Future<void> saveHistory(Map<String, dynamic> report) async {
    final userId = await getUserId();
    if (userId == null) throw Exception('Not authenticated');

    var url_ = baseUrl.split("/");
    url_.removeLast(); // remove /auth
    var baseurl = url_.join("/");

    // Endpoint: POST /student/add-history
    final resp = await http.post(
      Uri.parse('$baseurl/student/add-history'),
      headers: {'Content-Type': 'application/json', 'X-User-Id': userId},
      body: jsonEncode({
        'report': report,
        // 'timestamp': DateTime.now().toIso8601String(), // Optional, backend might handle
      }),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      print('✅ History saved successfully');
    } else {
      throw Exception('Failed to save history: ${resp.body}');
    }
  }

  static Future<void> signOut() async {
    await _storage.deleteAll();
  }
}
