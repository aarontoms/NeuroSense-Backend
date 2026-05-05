import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/attention_service.dart';
import '../../theme/app_theme.dart';

class AttentionMonitorScreen extends StatefulWidget {
  const AttentionMonitorScreen({super.key});

  @override
  State<AttentionMonitorScreen> createState() => _AttentionMonitorScreenState();
}

class _AttentionMonitorScreenState extends State<AttentionMonitorScreen> {
  static const _faceMeshChannel = MethodChannel('app/face_mesh');

  // ── Camera & Tracking ──
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _faceMeshReady = false;
  bool _processingFrame = false;
  String? _cameraError;

  // ── Session State ──
  bool _sessionActive = false;
  bool _sessionLoading = false;
  String _studentId = '';
  double? _liveAttention;

  // ── Settings ──
  int _stimulusSeconds = 30;
  bool _voiceOnLow = true;
  double _voiceThreshold = 0.4;

  // ── Stimulus ──
  String? _stimulusName;
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadStudentId();
    _initCamera();
  }

  Future<void> _loadStudentId() async {
    try {
      const fss = FlutterSecureStorage();
      final id = await fss.read(key: 'user_id');
      if (id != null && id.isNotEmpty && mounted) {
        setState(() => _studentId = id);
      }
    } catch (_) {}
  }

  // ── Camera Setup ──

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No cameras found');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera init failed: $e');
    }

    // Init face mesh separately
    try {
      await _faceMeshChannel.invokeMethod('initFaceMesh');
      if (mounted) setState(() => _faceMeshReady = true);
    } catch (_) {}
  }

  // ── Frame Processing (only during active session) ──

  void _startFrameProcessing() {
    if (!_cameraReady || !_faceMeshReady) return;
    try {
      _cameraController?.startImageStream(_onCameraFrame);
    } catch (_) {}
  }

  void _stopFrameProcessing() {
    try { _cameraController?.stopImageStream(); } catch (_) {}
  }

  void _onCameraFrame(CameraImage image) async {
    if (!_sessionActive || _processingFrame) return;
    _processingFrame = true;

    try {
      final result = await _faceMeshChannel.invokeMethod('processFrame', {
        'bytes': image.planes[0].bytes,
        'width': image.width,
        'height': image.height,
      });

      if (result != null && _sessionActive) {
        final landmarks = (result as List).map<Map<String, double>>((lm) {
          final m = lm as Map;
          return {
            'x': (m['x'] as num).toDouble(),
            'y': (m['y'] as num).toDouble(),
            'z': (m['z'] as num).toDouble(),
          };
        }).toList();

        final response = await AttentionService.sendFrame(
          studentId: _studentId,
          landmarks: landmarks,
          imageW: image.width,
          imageH: image.height,
        );

        if (mounted && response['smoothed_attention'] != null) {
          setState(() {
            _liveAttention = (response['smoothed_attention'] as num).toDouble();
          });
        }
      }
    } catch (_) {} finally {
      _processingFrame = false;
    }
  }

  // ── Session Control ──

  Future<void> _startSession() async {
    if (_sessionLoading || _studentId.isEmpty) return;

    setState(() {
      _sessionLoading = true;
    });

    try {
      final res = await AttentionService.startStimulus(
        studentId: _studentId,
        totalTime: _stimulusSeconds,
        voiceOnLow: _voiceOnLow,
        voiceThreshold: _voiceThreshold,
      );

      if (!mounted) return;

      setState(() {
        _sessionActive = true;
        _sessionLoading = false;
        _liveAttention = null;
      });

      _startFrameProcessing();
      _startPolling();
      _handleInstruction(res);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionLoading = false;
      });
      _showSnackBar('Failed to start: $e', Colors.red);
    }
  }

  Future<void> _stopSession({bool notifyServer = true}) async {
    _stopFrameProcessing();
    _pollTimer?.cancel();
    _pollTimer = null;

    if (notifyServer && _studentId.isNotEmpty) {
      try { await AttentionService.endStimulus(_studentId); } catch (_) {}
    }

    _videoController?.pause();
    _audioPlayer.stop();

    if (mounted) {
      setState(() {
        _sessionActive = false;
        _stimulusName = null;
        _liveAttention = null;
      });
    }
  }

  // ── Polling ──

  void _startPolling() {
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _pollNextInstruction(),
    );
  }

  Future<void> _pollNextInstruction() async {
    if (!_sessionActive) return;
    try {
      final res = await AttentionService.nextInstruction(_studentId);
      if (res['status'] == 'wait' || res['status'] == 'no_session') return;
      _handleInstruction(res);
    } catch (_) {}
  }

  void _handleInstruction(Map<String, dynamic> res) {
    if (res['action'] == 'play_voice') {
      if (res['voice_url'] != null) _playAudio(res['voice_url']);
    } else if (res['action'] == 'play_stimulus') {
      setState(() {
        _stimulusName = res['stimulus_name'] ?? 'Stimulus';
      });
      if (res['stimulus_url'] != null) _playStimulus(res['stimulus_url']);
      if (res['voice_url'] != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _playAudio(res['voice_url']);
        });
      }
    } else if (res['action'] == 'session_complete') {
      _onSessionComplete();
    }
  }

  void _onSessionComplete() async {
    await _stopSession(notifyServer: false);
    if (mounted) {
      // Navigate directly to analytics results
      context.push('/attention-analytics');
    }
  }

  // ── Media Playback ──

  void _playAudio(String url) async {
    try {
      await _audioPlayer.play(UrlSource(AttentionService.mediaUrl(url)));
    } catch (_) {}
  }

  void _playStimulus(String url) async {
    try {
      _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(AttentionService.mediaUrl(url)),
      );
      await _videoController!.initialize();
      _videoController!.addListener(() { if (mounted) setState(() {}); });
      await _videoController!.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _showSnackBar('Video load error', Colors.orange);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTheme.buttonTextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopFrameProcessing();
    _pollTimer?.cancel();
    _cameraController?.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    try { _faceMeshChannel.invokeMethod('disposeFaceMesh'); } catch (_) {}
    super.dispose();
  }

  // ══════════════════════════ UI ══════════════════════════

  @override
  Widget build(BuildContext context) {
    // During active session → show fullscreen stimulus view
    if (_sessionActive) return _buildSessionView();

    // Before session → show control panel
    return _buildControlPanel();
  }

  // ── Control Panel (Before Session) ──

  Widget _buildControlPanel() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Attention Monitor',
            style: AppTheme.headlineStyle(fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.ink),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: AppTheme.ink),
            onPressed: () => context.push('/attention-analytics'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── System Status ──
              _buildStatusCard(),
              const SizedBox(height: 20),

              // ── Session Settings ──
              _buildSettingsCard(),
              const SizedBox(height: 20),

              // ── Start Button ──
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return NeoBox(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Status',
              style: AppTheme.headlineStyle(fontSize: 18)),
          const SizedBox(height: 16),
          _statusRow(
            Icons.videocam,
            'Camera',
            _cameraReady,
            _cameraError ?? (_cameraReady ? 'Ready' : 'Initializing...'),
          ),
          const SizedBox(height: 10),
          _statusRow(
            Icons.face,
            'Face Tracking',
            _faceMeshReady,
            _faceMeshReady ? 'Ready' : 'Unavailable',
          ),
          const SizedBox(height: 10),
          _statusRow(
            Icons.person,
            'Student ID',
            _studentId.isNotEmpty,
            _studentId.isNotEmpty ? 'Logged in' : 'Not found — please login',
          ),
        ],
      ),
    ).neoEntrance();
  }

  Widget _statusRow(IconData icon, String label, bool ok, String detail) {
    return Row(
      children: [
        Icon(icon, size: 20, color: ok ? Colors.green : Colors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.buttonTextStyle(fontSize: 13)),
              Text(
                detail,
                style: AppTheme.bodyStyle(
                  fontSize: 12,
                  color: ok ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ],
          ),
        ),
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return NeoBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Settings',
              style: AppTheme.headlineStyle(fontSize: 18)),
          const SizedBox(height: 16),

          // Duration
          Text('STIMULUS DURATION',
              style: AppTheme.buttonTextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: AppTheme.neoBorder(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _stimulusSeconds,
                isExpanded: true,
                items: [10, 15, 20, 30, 45, 60]
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('$s seconds'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _stimulusSeconds = v!),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Voice on Low
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VOICE ON LOW ATTENTION',
                        style: AppTheme.buttonTextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      'Play voice prompt when attention drops',
                      style: AppTheme.bodyStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _voiceOnLow,
                onChanged: (v) => setState(() => _voiceOnLow = v),
                activeTrackColor: AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Threshold
          Text(
            'ATTENTION THRESHOLD: ${(_voiceThreshold * 100).toStringAsFixed(0)}%',
            style: AppTheme.buttonTextStyle(fontSize: 12),
          ),
          Slider(
            value: _voiceThreshold,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: AppTheme.accent,
            label: '${(_voiceThreshold * 100).toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _voiceThreshold = v),
          ),
        ],
      ),
    ).neoEntrance(delay: 100);
  }

  Widget _buildStartButton() {
    final canStart = _cameraReady && _studentId.isNotEmpty && !_sessionLoading;

    return NeoButton(
      onPressed: canStart ? _startSession : null,
      color: canStart ? Colors.green : Colors.grey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_sessionLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Text(
            _sessionLoading ? 'CONNECTING...' : 'START SESSION',
            style: AppTheme.buttonTextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    ).neoEntrance(delay: 200);
  }

  // ── Session View (During Active Session) ──

  Widget _buildSessionView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player (fullscreen)
          if (_videoController != null && _videoController!.value.isInitialized)
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          else
            const Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Waiting for stimulus...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Top overlay
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Stop button
                GestureDetector(
                  onTap: () async {
                    await _stopSession();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stop, color: Colors.white, size: 24),
                  ),
                ),

                // Stimulus name
                if (_stimulusName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _stimulusName!,
                      style: AppTheme.buttonTextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom attention bar
          if (_liveAttention != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: _buildLiveAttentionOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveAttentionOverlay() {
    final pct = (_liveAttention! * 100);
    final color = pct >= 70
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('Attention',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _liveAttention!.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
