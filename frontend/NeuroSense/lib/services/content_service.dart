import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:autism/secrets.dart';

class ContentService {
  static const String _baseUrl = '$BACKEND_URL/teacher';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Fetch all content from teachers in the same institution
  static Future<Map<String, dynamic>> getContentByInstitution() async {
    try {
      // Get User ID
      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      print('🏫 Fetching content by institution...');

      final response = await http.get(
        Uri.parse('$_baseUrl/content-by-institution'),
        headers: {
          'X-User-Id': userId,
          'Content-Type': 'application/json',
        },
      );

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '✅ Found ${data['contentCount']} items from institution: ${data['institution']}',
        );
        return data;
      } else if (response.statusCode == 403) {
        throw Exception('Unauthorized - please login again');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch content');
      }
    } catch (e) {
      print('❌ Error fetching content: $e');
      rethrow;
    }
  }

  /// Download a specific file by fileId
  static Future<List<int>> downloadFile(String fileId) async {
    try {
      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      print('📥 Downloading file: $fileId');

      final response = await http.post(
        Uri.parse('$_baseUrl/get'),
        headers: {'X-User-Id': userId},
        body: json.encode({'fileId': fileId}),
      );

      if (response.statusCode == 200) {
        print('✅ File downloaded successfully');
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      print('❌ Error downloading file: $e');
      rethrow;
    }
  }

  /// Get user's institution from stored profile
  static Future<String?> getUserInstitution() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson == null) return null;

      final profile = json.decode(profileJson);
      return profile['institution'] as String?;
    } catch (e) {
      print('❌ Error reading institution: $e');
      return null;
    }
  }
}
