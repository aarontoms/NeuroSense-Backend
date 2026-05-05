import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;

import 'package:autism/secrets.dart';

class TeacherService {
  static const String baseUrl = BACKEND_URL;
  static const _storage = FlutterSecureStorage();

  /// Upload a file (video/image/document)
  static Future<String> uploadFile(File file, {String? customFilename}) async {
    try {
      // Get User ID
      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      // Read file as bytes
      final bytes = await file.readAsBytes();

      // Get filename safely - handle web and mobile platforms
      String filename;
      try {
        filename = path.basename(file.path);
      } catch (e) {
        // Fallback for web or when path operations fail
        filename =
            customFilename ??
            'upload_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }

      print('📤 Uploading file: $filename');
      print('   Size: ${bytes.length} bytes');

      // Upload file
      final response = await http.post(
        Uri.parse('$baseUrl/teacher/upload'),
        headers: {
          'Content-Type': 'application/octet-stream',
          'X-User-Id': userId, // New ID-based header
          'x-filename': filename,
        },
        body: bytes,
      );

      print('📥 Upload response: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['Status'] == 'Success') {
          return data['fileId']; // Return fileId for metadata upload
        }
      }

      throw Exception('Upload failed: ${response.body}');
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  /// Upload metadata (timestamps and descriptions)
  static Future<void> uploadMetadata({
    required String fileId,
    required List<Map<String, String>> metadata,
  }) async {
    try {
      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      print('📤 Uploading metadata for fileId: $fileId');
      print('   Metadata entries: ${metadata.length}');

      final response = await http.post(
        Uri.parse('$baseUrl/teacher/upload-metadata'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': userId, // New ID-based header
        },
        body: jsonEncode({'fileId': fileId, 'metadata': metadata}),
      );

      print('📥 Metadata response: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Status'] == 'Success') {
          return;
        }
      }

      throw Exception('Metadata upload failed: ${response.body}');
    } catch (e) {
      print('❌ Metadata upload error: $e');
      rethrow;
    }
  }

  /// Complete upload flow: file + metadata
  static Future<void> uploadContent({
    required File file,
    required List<Map<String, String>> metadata,
    String? filename,
  }) async {
    // Step 1: Upload file
    final fileId = await uploadFile(file, customFilename: filename);

    // Step 2: Upload metadata
    await uploadMetadata(fileId: fileId, metadata: metadata);
  }
}
