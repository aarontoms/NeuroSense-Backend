import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:autism/secrets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:go_router/go_router.dart';
import 'package:autism/services/auth_services.dart';
import '../../theme/app_theme.dart';

const String PREDICT_URL = "$BACKEND_URL/predict";

final methodChannel = MethodChannel("app/landmark_method");

class AutismDetectionScreen extends StatefulWidget {
  const AutismDetectionScreen({super.key});

  @override
  State<AutismDetectionScreen> createState() => _AutismDetectionScreenState();
}

class _AutismDetectionScreenState extends State<AutismDetectionScreen> {
  List<SegmentResult> _segments = [];
  SegmentResult? _activeSegment;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _controller;

  XFile? _videoFile;
  bool _isRecordingMode = false; // false = Upload, true = Record
  bool _isInitializing = false;
  bool _isProcessing = false;
  bool _isAnalyzingGemini = false;
  GeminiReport? _geminiReport;
  String? _errorMessage;

  bool get _hasTrigger => _segments.any((s) => s.trigger);

  void _onVideoTick() {
    if (_segments.isEmpty || _controller == null) return;
    final pos = _controller!.value.position;
    SegmentResult? seg;
    for (final s in _segments) {
      if (pos >= s.start && pos <= s.end) {
        seg = s;
        break;
      }
    }
    if (seg != _activeSegment) {
      setState(() => _activeSegment = seg);
    }
  }

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    await _loadVideo(file);
  }

  Future<void> _recordVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) return;
    await _loadVideo(file);
  }

  Future<void> _loadVideo(XFile file) async {
    setState(() {
      _isInitializing = true;
      _segments = [];
      _geminiReport = null;
      _errorMessage = null;
    });
    await _controller?.pause();
    await _controller?.dispose();
    _videoFile = file;
    _controller = VideoPlayerController.file(File(file.path));
    await _controller!.initialize();
    _controller!.addListener(_onVideoTick);
    _controller!.addListener(() {
      if (mounted) setState(() {});
    });
    _controller!.setLooping(false);
    await _controller!.play();
    setState(() {
      _isInitializing = false;
    });
  }

  Future<String> startLandmarkExtraction(String videoPath) async {
    final csvPath = await methodChannel.invokeMethod<String>(
      "extractLandmarksToCsv",
      {
        "videoPath": videoPath,
        "fps": 30.0,
        "keepIds": [0, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
      },
    );
    return csvPath!;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  List<SegmentResult> parsePredictionCsv(String csv, double fps) {
    final lines = csv.trim().split('\n');
    final out = <SegmentResult>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final firstComma = line.indexOf(',');
      final secondComma = line.indexOf(',', firstComma + 1);
      final thirdComma = line.indexOf(',', secondComma + 1);

      final startFrame = int.parse(line.substring(0, firstComma));
      final endFrame = int.parse(line.substring(firstComma + 1, secondComma));
      final trigger = line.substring(secondComma + 1, thirdComma) == 'trigger';
      final envRaw = line.substring(thirdComma + 1).trim();

      final env = envRaw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll("'", '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      out.add(
        SegmentResult(
          start: Duration(milliseconds: (startFrame / fps * 1000).toInt()),
          end: Duration(milliseconds: (endFrame / fps * 1000).toInt()),
          trigger: trigger,
          env: env,
        ),
      );
    }
    return out;
  }

  Future<void> _generateGeminiReport() async {
    final allInputSegments = _segments.where((s) => s.trigger).toList();

    if (allInputSegments.isEmpty) {
      setState(() => _geminiReport = null);
      return;
    }

    setState(() => _isAnalyzingGemini = true);

    try {
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: googleApiKey,
      );

      final triggersInput = allInputSegments
          .map((s) {
            if (s.env.isEmpty) {
              return "Time: ${_formatDuration(s.start)}-${_formatDuration(s.end)} -> Status: NORMAL BEHAVIOR (No Autism Detected)";
            } else {
              return "Time: ${_formatDuration(s.start)}-${_formatDuration(s.end)} -> Status: POTENTIAL TRIGGER, Environments: ${s.env.join(', ')}";
            }
          })
          .join("\n");

      final prompt =
          """
      You are an autism behavioral analyst assistant.
      Input data (Video analysis segments):
      $triggersInput
      
      CRITICAL INSTRUCTION:
      - This is a high-sensitivity precautionary tool. 
      - If there are ANY "POTENTIAL TRIGGER" segments (even just 1 or 2), the prediction_percentage MUST be 70% or higher and risk_level MUST be "High".
      - "NORMAL BEHAVIOR" segments only lower the score if they significantly outnumber the triggers (e.g., 10 normal vs 1 trigger).
      
      Task:
      Generate a precautionary behavioral report.
      
      Constraints:
      1. NO medical disclaimers.
      2. Keep "analysis_points" extremely short, practical, and direct (Max 10 words per point).
      3. Base the 'prediction_percentage' on an aggressive sensitivity scale (High score for any observed triggers).
      
      Output JSON Schema:
      {
        "prediction_percentage": int,   // Range: 0-100. Even 1-2 triggers should be 70-85%. Multiple triggers should be 90%+.
        "risk_level": "string",         // "Low", "Moderate", or "High"
        "environments": ["string"],     // List ONLY the environments from 'POTENTIAL TRIGGER' segments
        "analysis_points": ["string"],  // 3 distinct observations.
        "triggers": [
          {"timestamp": "string", "description": "string"} // ONLY list the 'POTENTIAL TRIGGER' items here
        ]
      }
      Return ONLY raw JSON.
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        var jsonText = response.text!.trim();
        if (jsonText.startsWith('```json')) {
          jsonText = jsonText.replaceAll('```json', '').replaceAll('```', '');
        }
        jsonText = jsonText.trim();

        final Map<String, dynamic> data = jsonDecode(jsonText);
        setState(() {
          _geminiReport = GeminiReport.fromJson(data);
        });

        // Save history to backend
        try {
          await AuthService.saveHistory(data);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Report saved to history successfully!",
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          debugPrint("Failed to save history: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Note: Failed to save history ($e)"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Gemini Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Analysis failed: $e")));
    } finally {
      setState(() => _isAnalyzingGemini = false);
    }
  }

  Future<void> uploadCsv(String csvPath) async {
    final uri = Uri.parse(PREDICT_URL);
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", csvPath));
    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw "Server error (${response.statusCode}): $body";
    }

    final segments = parsePredictionCsv(body, 30);
    setState(() {
      _segments = segments;
    });

    // Always generate report regardless of triggers logic (user instruction)
    await _generateGeminiReport();
  }

  Future<Map<String, dynamic>> _validateVideoWithGemini(File videoFile) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: googleApiKey,
      );

      final videoBytes = await videoFile.readAsBytes();
      final prompt = """
      Analyze this video content for validity.
      Check if:
      1. It is a real video (not just a black screen, static image, or corrupted).
      2. It contains a human subject (child/person) visible.
      
      Return JSON:
      {
        "isValid": boolean,
        "reason": "string"
      }
      
      CONSTRAINT FOR 'reason':
      - If invalid because no person is found, return exactly: "No human subject detected."
      - If invalid because black screen/static/blur, return exactly: "Video is unclear or empty."
      - Do NOT describe what is actually in the video (e.g. do NOT say "I see a cat").
      """;

      final content = [
        Content.multi([TextPart(prompt), DataPart('video/mp4', videoBytes)]),
      ];

      final response = await model.generateContent(content);

      if (response.text != null) {
        var jsonText = response.text!.trim();
        if (jsonText.startsWith('```json')) {
          jsonText = jsonText.replaceAll('```json', '').replaceAll('```', '');
        }
        return jsonDecode(jsonText);
      }
      return {"isValid": false, "reason": "No response from AI"};
    } catch (e) {
      print("Gemini Validation Error: $e");
      return {"isValid": true, "reason": "Validation skipped: $e"};
    }
  }

  void _runAutismDetection() async {
    if (_videoFile == null) return;
    if (_isProcessing) return;

    if (googleApiKey == "YOUR_API_KEY_HERE") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please set your API Key in lib/secrets.dart"),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final extractionFuture = startLandmarkExtraction(_videoFile!.path);
    final validationFuture = _validateVideoWithGemini(File(_videoFile!.path));

    try {
      final validationResult = await validationFuture;
      if (validationResult['isValid'] == false) {
        throw "Video Rejected: ${validationResult['reason']}";
      }

      final csvPath = await extractionFuture;
      if (!File(csvPath).existsSync()) {
        throw "Landmark extraction failed to produce output.";
      }

      await uploadCsv(csvPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Analysis Complete",
            style: AppTheme.buttonTextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Autism Detection',
          style: AppTheme.headlineStyle(fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.ink),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Video Analysis',
                style: AppTheme.headlineStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),

              Text(
                'Upload or record a clear front-facing video of the child.',
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),

              SegmentedControlToggle(
                value: _isRecordingMode,
                onChanged: (v) => setState(() => _isRecordingMode = v),
              ),
              const SizedBox(height: 20),

              NeoButton(
                onPressed: _isRecordingMode ? _recordVideo : _pickVideo,
                color: AppTheme.accent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRecordingMode ? Icons.videocam : Icons.upload_file,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRecordingMode ? 'RECORD VIDEO' : 'UPLOAD VIDEO',
                      style: AppTheme.buttonTextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              NeoBox(
                color: const Color(0xFFE0F7FA),
                padding: const EdgeInsets.all(16),
                child: _isInitializing
                    ? const Center(child: CircularProgressIndicator())
                    : _videoFile == null || _controller == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.video_file,
                            size: 56,
                            color: AppTheme.ink,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No video selected',
                            style: AppTheme.buttonTextStyle(fontSize: 14),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _controller!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: AppTheme.ink,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller!.value.isPlaying
                                        ? _controller!.pause()
                                        : _controller!.play();
                                  });
                                },
                              ),
                              Text(
                                _formatDuration(_controller!.value.position),
                              ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  height: 30,
                                  child: _buildColorCodedSeekBar(),
                                ),
                              ),
                              Text(
                                _formatDuration(_controller!.value.duration),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null)
                            NeoBox(
                              color: Colors.red.shade50,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Verification Failed",
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  NeoButton(
                                    onPressed: () {
                                      setState(() {
                                        _errorMessage = null;
                                        _videoFile = null;
                                        _controller?.dispose();
                                        _controller = null;
                                        _segments = [];
                                      });
                                    },
                                    color: Colors.red,
                                    child: Text(
                                      "TRY AGAIN",
                                      style: AppTheme.buttonTextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_isProcessing || _isAnalyzingGemini)
                            NeoBox(
                              color: AppTheme.accent,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isProcessing
                                        ? "Processing Video..."
                                        : "Analyzing with AI...",
                                    style: AppTheme.buttonTextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_geminiReport == null)
                            NeoButton(
                              onPressed: _runAutismDetection,
                              color: Colors.green,
                              child: Text(
                                "RUN ANALYSIS",
                                style: AppTheme.buttonTextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),

                          if (_geminiReport != null) _buildGeminiReportCard(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeminiReportCard() {
    final report = _geminiReport!;
    final isHigh = report.percentage > 50;
    final statusColor = isHigh ? Colors.red : Colors.green;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: NeoBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      "${report.percentage}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Risk Assessment",
                        style: AppTheme.bodyStyle(fontSize: 12),
                      ),
                      Text(
                        report.riskLevel,
                        style: AppTheme.headlineStyle(
                          fontSize: 20,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 2, color: AppTheme.ink),

            Text("Clinical Analysis", style: AppTheme.buttonTextStyle()),
            const SizedBox(height: 8),
            ...report.analysisPoints.map((point) {
              final cleanPoint = point.replaceAll('*', '').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8, right: 8),
                      child: Icon(Icons.circle, size: 6, color: AppTheme.ink),
                    ),
                    Expanded(
                      child: Text(
                        cleanPoint,
                        style: AppTheme.bodyStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            Text("Observed Triggers", style: AppTheme.buttonTextStyle()),
            if (report.triggers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "No specific triggers detected.",
                  style: AppTheme.bodyStyle(color: Colors.grey),
                ),
              ),

            ...report.triggers.map(
              (t) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                title: Text(
                  t['timestamp'] ?? '',
                  style: AppTheme.buttonTextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  t['description']?.replaceAll('*', '').trim() ?? '',
                  style: AppTheme.bodyStyle(fontSize: 12),
                ),
              ),
            ),

            const SizedBox(height: 10),
            if (report.environments.isNotEmpty) ...[
              Text(
                "Triggering Environments",
                style: AppTheme.buttonTextStyle(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: report.environments
                    .map(
                      (e) => Chip(
                        label: Text(e.replaceAll('*', '').trim()),
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorCodedSeekBar() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox();
    }
    final duration = _controller!.value.duration.inMilliseconds.toDouble();
    return Stack(
      children: [
        VideoProgressIndicator(
          _controller!,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: Colors.blue,
            bufferedColor: Colors.blueGrey,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return const SizedBox();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class GeminiReport {
  final int percentage;
  final String riskLevel;
  final List<String> analysisPoints;
  final List<Map<String, String>> triggers;
  final List<String> environments;

  GeminiReport({
    required this.percentage,
    required this.riskLevel,
    required this.analysisPoints,
    required this.triggers,
    required this.environments,
  });

  factory GeminiReport.fromJson(Map<String, dynamic> json) {
    return GeminiReport(
      percentage: json['prediction_percentage'] ?? 0,
      riskLevel: json['risk_level'] ?? 'Unknown',
      analysisPoints:
          (json['analysis_points'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      triggers:
          (json['triggers'] as List?)
              ?.map(
                (e) => {
                  'timestamp': e['timestamp'].toString(),
                  'description': e['description'].toString(),
                },
              )
              .toList() ??
          [],
      environments:
          (json['environments'] as List?)?.map((e) => e.toString()).toList() ??
          [],
    );
  }
}

class SegmentedControlToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SegmentedControlToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NeoBox(
      padding: const EdgeInsets.all(4),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !value ? AppTheme.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Upload',
                  style: AppTheme.buttonTextStyle(
                    color: !value ? Colors.white : AppTheme.ink,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value ? AppTheme.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Record',
                  style: AppTheme.buttonTextStyle(
                    color: value ? Colors.white : AppTheme.ink,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentResult {
  final Duration start;
  final Duration end;
  final bool trigger;
  final List<String> env;

  SegmentResult({
    required this.start,
    required this.end,
    required this.trigger,
    required this.env,
  });
}
