import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:autism/secrets.dart';

/// HTTP client that accepts self-signed / adhoc SSL certificates.
/// The backend uses `ssl_context="adhoc"` which generates a self-signed cert.
http.Client _buildInsecureClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(ioClient);
}

final http.Client _client = _buildInsecureClient();

class AttentionService {
  static String get baseUrl => ATTENTION_BACKEND_URL;
  static const Duration _timeout = Duration(seconds: 10);

  // ───────── Session Control ─────────

  static Future<Map<String, dynamic>> startStimulus({
    required String studentId,
    int totalTime = 30,
    bool voiceOnLow = false,
    double voiceThreshold = 0.4,
  }) async {
    try {
      debugPrint('[AttentionService] startStimulus -> $baseUrl/start_stimulus');
      final res = await _client.post(
        Uri.parse('$baseUrl/start_stimulus'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'total_time': totalTime,
          'voice_on_low_attention': voiceOnLow,
          'voice_threshold': voiceThreshold,
        }),
      ).timeout(_timeout);

      debugPrint('[AttentionService] startStimulus response: ${res.statusCode}');
      if (res.statusCode != 200) {
        throw Exception('Server error ${res.statusCode}: ${res.body}');
      }
      return jsonDecode(res.body);
    } on SocketException catch (e) {
      throw Exception('Cannot reach server at $baseUrl — is the backend running? ($e)');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Connection to $baseUrl timed out — is the backend running?');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> endStimulus(String studentId) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/end_stimulus'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId}),
      ).timeout(_timeout);
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[AttentionService] endStimulus error: $e');
      throw Exception('Failed to end stimulus: $e');
    }
  }

  static Future<Map<String, dynamic>> nextInstruction(String studentId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/next_instruction/$studentId'),
    ).timeout(const Duration(seconds: 5));
    return jsonDecode(res.body);
  }

  // ───────── Frame Processing ─────────

  static Future<Map<String, dynamic>> sendFrame({
    required String studentId,
    required List<Map<String, double>> landmarks,
    int imageW = 640,
    int imageH = 480,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/frame'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': studentId,
        'ts': DateTime.now().millisecondsSinceEpoch / 1000.0,
        'image_w': imageW,
        'image_h': imageH,
        'landmarks': landmarks,
      }),
    ).timeout(const Duration(seconds: 5));
    return jsonDecode(res.body);
  }

  // ───────── Analytics ─────────

  static Future<Map<String, dynamic>> analyticsSummary() async {
    final res = await _client.get(Uri.parse('$baseUrl/analytics/summary'))
        .timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> analyticsByStudent(String studentId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/analytics/student/$studentId'),
    ).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> analyticsStudentStimulus(
    String studentId,
  ) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/analytics/student/$studentId/stimulus'),
    ).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> analyticsStudentBest(
    String studentId,
  ) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/analytics/student/$studentId/best'),
    ).timeout(_timeout);
    return jsonDecode(res.body);
  }

  /// Build a full URL for a stimulus or voice file served by the backend.
  static String mediaUrl(String relativePath) {
    if (relativePath.startsWith('http')) return relativePath;
    return '$baseUrl$relativePath';
  }
}
