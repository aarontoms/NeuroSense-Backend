import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class SensorySlimeActivity extends StatefulWidget {
  const SensorySlimeActivity({super.key});

  @override
  State<SensorySlimeActivity> createState() => _SensorySlimeActivityState();
}

class _SensorySlimeActivityState extends State<SensorySlimeActivity>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final int _pointCount = 20;
  final double _radius = 120.0;
  final double _stiffness = 0.15;
  final double _damping = 0.85;

  List<Offset> _points = [];
  List<Offset> _velocities = [];
  Offset _center = Offset.zero;
  Offset? _touchPoint;
  bool _isSoundPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeBlob();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_updatePhysics);
  }

  void _initializeBlob() {
    _points.clear();
    _velocities.clear();
    for (int i = 0; i < _pointCount; i++) {
      double angle = (2 * pi * i) / _pointCount;
      double x = cos(angle) * _radius;
      double y = sin(angle) * _radius;
      _points.add(Offset(x, y));
      _velocities.add(Offset.zero);
    }
  }

  void _updatePhysics() {
    for (int i = 0; i < _pointCount; i++) {
      double angle = (2 * pi * i) / _pointCount;
      Offset target = Offset(cos(angle) * _radius, sin(angle) * _radius);

      Offset force = Offset.zero;
      if (_touchPoint != null) {
        Offset localTouch = _touchPoint! - _center;
        double dist = (localTouch - _points[i]).distance;

        if (dist < 80) {
          Offset dir = (_points[i] - localTouch);
          if (dist > 0) {
            force = (dir / dist) * 15.0;
          }
        }
      }

      Offset displacement = target - _points[i];
      Offset acceleration = (displacement * _stiffness) + force;

      _velocities[i] = (_velocities[i] + acceleration) * _damping;
      _points[i] += _velocities[i];
    }
    setState(() {});
  }

  void _handleTouch(Offset localPosition) {
    _touchPoint = localPosition;
    HapticFeedback.selectionClick();
    _playSquishSound();
  }

  Future<void> _playSquishSound() async {
    if (!_isSoundPlaying) {
      _isSoundPlaying = true;
      try {
        await _audioPlayer.play(AssetSource('sounds/slime-impact.mp3'));
      } catch (e) {
        SystemSound.play(SystemSoundType.click);
      }
      Future.delayed(const Duration(milliseconds: 100), () {
        _isSoundPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("Sensory Slime", style: AppTheme.headlineStyle(fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.ink),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Stack(
        children: [
          // Instructions Card
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: NeoBox(
              child: Text(
                "Touch and squish the slime! 👆",
                style: AppTheme.bodyStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ).neoEntrance(delay: 200),
          ),
          
          GestureDetector(
            onPanStart: (details) => _handleTouch(details.localPosition),
            onPanUpdate: (details) => _handleTouch(details.localPosition),
            onPanEnd: (details) {
              _touchPoint = null;
            },
            child: CustomPaint(
              painter: SlimePainter(_points, _center),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class SlimePainter extends CustomPainter {
  final List<Offset> points;
  final Offset center;

  SlimePainter(this.points, this.center);

  @override
  void paint(Canvas canvas, Size size) {
    // Neo-Brutalist Slime Color (Yellow/Green/Pink) - Let's use Yellow/Gold
    final Color slimeColor = const Color(0xFFFFD700); 
    
    Paint fillPaint = Paint()
      ..color = slimeColor
      ..style = PaintingStyle.fill;
      
    Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    Path path = Path();
    if (points.isNotEmpty) {
      Offset start = points[0] + center;
      path.moveTo(start.dx, start.dy);

      for (int i = 0; i < points.length; i++) {
        Offset p1 = points[i] + center;
        Offset p2 = points[(i + 1) % points.length] + center;

        Offset control = p1;
        Offset end = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

        path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      }
      path.close();
    }

    // Hard Shadow
    canvas.drawPath(path.shift(const Offset(4, 4)), Paint()..color = Colors.black);

    // Fill
    canvas.drawPath(path, fillPaint);
    
    // Border
    canvas.drawPath(path, borderPaint);

    // Shine (Geometric)
    Paint shinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(center + const Offset(-40, -40), 12, shinePaint);
    canvas.drawCircle(center + const Offset(-60, -25), 6, shinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
