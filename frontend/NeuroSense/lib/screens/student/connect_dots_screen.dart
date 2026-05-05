import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class ConnectDotsScreen extends StatefulWidget {
  const ConnectDotsScreen({super.key});

  @override
  State<ConnectDotsScreen> createState() => _ConnectDotsScreenState();
}

class _ConnectDotsScreenState extends State<ConnectDotsScreen>
    with SingleTickerProviderStateMixin {
  // Config - Always 3 dots
  final int _numberOfDots = 3;
  final bool _ordered = true;

  // Game State
  final List<Offset> _dots = [];
  final List<Offset> _currentPath = [];
  Offset? _currentDragPosition;

  // Use a List to maintain exact order of connection.
  final List<int> _connectedIndices = [];

  // Analysis State - Always unlocked
  bool _gameCompleted = false;
  double? _deviationScore;
  int _lastReachedIndex = -1;
  final List<List<Offset>> _recordedPaths = []; // Raw user paths

  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _generateDots();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _generateDots() {
    _dots.clear();
    _currentPath.clear();
    _connectedIndices.clear();
    _recordedPaths.clear();
    _gameCompleted = false;
    _deviationScore = null;
    _lastReachedIndex = -1;

    final random = Random();
    const double minDistance = 0.25; // Minimum relative distance between dots

    int totalAttempts = 0;
    while (_dots.length < _numberOfDots && totalAttempts < 100) {
      totalAttempts++;
      final candidate = Offset(
        0.1 + random.nextDouble() * 0.8,
        0.15 + random.nextDouble() * 0.55,
      );

      bool tooClose = false;
      for (final dot in _dots) {
        if ((dot - candidate).distance < minDistance) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        _dots.add(candidate);
      }
    }

    // Fallback filling if we couldn't fit them perfectly (rare for low dot count)
    while (_dots.length < _numberOfDots) {
      _dots.add(
        Offset(
          0.1 + random.nextDouble() * 0.8,
          0.2 + random.nextDouble() * 0.5,
        ),
      );
    }
  }

  void _onPanStart(DragStartDetails details, Size size) {
    if (_gameCompleted) return;
    final touch = _normalize(details.localPosition, size);

    int? touchedIndex;
    for (int i = 0; i < _dots.length; i++) {
      if ((_dots[i] - touch).distance < 0.08) {
        touchedIndex = i;
        break;
      }
    }

    if (touchedIndex != null) {
      if (_ordered) {
        final expectedStart = _lastReachedIndex == -1 ? 0 : _lastReachedIndex;
        if (touchedIndex == expectedStart) {
          _currentPath.clear();
          _currentPath.add(touch);
          _currentDragPosition = touch;
        }
      } else {
        if (_connectedIndices.isEmpty) {
          _currentPath.clear();
          _currentPath.add(touch);
          _currentDragPosition = touch;
        }
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_currentPath.isEmpty || _gameCompleted) return;

    final point = _normalize(details.localPosition, size);
    setState(() {
      _currentPath.add(point);
      _currentDragPosition = point;
    });

    for (int i = 0; i < _dots.length; i++) {
      if ((_dots[i] - point).distance < 0.08) {
        _handleDotHit(i);
        break;
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_gameCompleted && _currentPath.isNotEmpty) {
      setState(() {
        _currentPath.clear();
        _currentDragPosition = null;
      });
    }
  }

  void _handleDotHit(int hitIndex) {
    if (_ordered) {
      final start = _lastReachedIndex == -1 ? 0 : _lastReachedIndex;
      final target = start + 1;
      if (hitIndex == target) {
        _completeSegment(start, target);
      }
    } else {
      final startDot = _getClosestDot(_currentPath.first);
      if (startDot != null && startDot != hitIndex) {
        _completeSegment(startDot, hitIndex);
      }
    }
  }

  int? _getClosestDot(Offset p) {
    for (int i = 0; i < _dots.length; i++) {
      if ((_dots[i] - p).distance < 0.08) return i;
    }
    return null;
  }

  void _completeSegment(int startIndex, int endIndex) {
    final startP = _dots[startIndex];
    final endP = _dots[endIndex];
    final segmentDeviation = _calculateDeviation(_currentPath, startP, endP);

    setState(() {
      // Add indices
      if (_ordered) {
        if (!_connectedIndices.contains(startIndex))
          _connectedIndices.add(startIndex);
        if (!_connectedIndices.contains(endIndex))
          _connectedIndices.add(endIndex);
        _lastReachedIndex = endIndex;
      } else {
        if (!_connectedIndices.contains(startIndex))
          _connectedIndices.add(startIndex);
        if (!_connectedIndices.contains(endIndex))
          _connectedIndices.add(endIndex);
      }

      _recordedPaths.add(List.from(_currentPath));
      _currentPath.clear();
      _deviationScore = (_deviationScore ?? 0) + segmentDeviation;

      if (_ordered) {
        if (_lastReachedIndex == _numberOfDots - 1) {
          _finishGame();
        }
      } else {
        if (_connectedIndices.length >= 2) {
          _finishGame();
        }
      }
    });
  }

  void _finishGame() {
    _gameCompleted = true;
    int segments = _ordered ? (_numberOfDots - 1) : 1;
    _deviationScore = (_deviationScore ?? 0) / segments;
    _confettiController.forward(from: 0);
  }

  double _calculateDeviation(List<Offset> path, Offset a, Offset b) {
    if (path.isEmpty) return 0.0;
    double totalDist = 0;
    for (final p in path) {
      totalDist += _distancePointToLineSegment(p, a, b);
    }
    return (totalDist / path.length) *
        1.6; // Significantly increased sensitivity for wobbly lines
  }

  double _distancePointToLineSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0) return (p - v).distance;
    double t =
        ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
    t = max(0, min(1, t));
    final projection = Offset(
      v.dx + t * (w.dx - v.dx),
      v.dy + t * (w.dy - v.dy),
    );
    return (p - projection).distance;
  }

  Offset _normalize(Offset local, Size size) {
    return Offset(local.dx / size.width, local.dy / size.height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Connect The Dots"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _generateDots()),
          ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          context.go('/home');
        },
        child: Column(
          children: [
            // ...
            // 1. Game Area
            Expanded(
              flex: 3,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    onPanStart: (d) => _onPanStart(d, size),
                    onPanUpdate: (d) => _onPanUpdate(d, size),
                    onPanEnd: _onPanEnd,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // A. Straight Lines (Ideally what child sees)
                          CustomPaint(
                            size: size,
                            painter: LinePainter(
                              dots: _dots,
                              connectedIndices: _connectedIndices,
                              ordered: _ordered,
                              theme: theme,
                            ),
                          ),

                          // B. Current Dragging Path (Always visible while dragging)
                          if (_currentPath.isNotEmpty)
                            CustomPaint(
                              size: size,
                              painter: PathPainter(
                                _currentPath,
                                theme.colorScheme.primary,
                              ),
                            ),

                          // C. Analysis Overlay (Red RAW paths) - Always shown when completed
                          if (_gameCompleted) ...[
                            CustomPaint(
                              size: size,
                              painter: AnalysisPathPainter(_recordedPaths),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "🟢 Green = Optimal Path",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      "🔴 Red = Your Path",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // D. Dots
                          ...List.generate(_dots.length, (index) {
                            final dot = _dots[index];
                            final isConnected = _connectedIndices.contains(
                              index,
                            );
                            return Positioned(
                              left: dot.dx * size.width - 24,
                              top: dot.dy * size.height - 24,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isConnected
                                      ? theme.primaryColor
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isConnected
                                          ? Colors.white
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                          // E. Confetti / Success Animation
                          if (_gameCompleted)
                            Align(
                              alignment: Alignment.center,
                              child: IgnorePointer(
                                child:
                                    Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber.withOpacity(0.8),
                                          size: 100,
                                        )
                                        .animate(
                                          controller: _confettiController,
                                        )
                                        .scale()
                                        .fadeOut(delay: 1.seconds),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. Info / Results Area (Always on screen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_gameCompleted)
                    Text(
                      "Connect the dots in order!",
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    )
                  else ...[
                    // Results - Always shown
                    Text(
                      "Amazing Job! 🌟",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "You connected them all!",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Motor Skill Analysis - Always shown
                    Divider(color: theme.colorScheme.onSurface),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined),
                        const SizedBox(width: 8),
                        Text(
                          "Motor Skill Analysis",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricCard(
                      theme,
                      "Path Deviation",
                      "${(_deviationScore! * 1000).toInt()}",
                      _deviationScore! < 0.05
                          ? Colors.green
                          : (_deviationScore! < 0.1
                                ? Colors.orange
                                : Colors.red),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Text(
                        "Assessment: ${_getDeviationAssessment(_deviationScore!)}",
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _deviationScore! < 0.05
                              ? Colors.green
                              : (_deviationScore! < 0.1
                                    ? Colors.orange
                                    : Colors.red),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      "• Low deviation indicates steady hand control.\n• Green = optimal path, Red = your drawn path.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Finish Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/home'),
                        child: const Text("Finish"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDeviationAssessment(double score) {
    if (score < 0.05) return "Excellent Motor Control";
    if (score < 0.1) return "Good Consistency";
    return "Needs Practice";
  }

  Widget _buildMetricCard(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final List<Offset> pathPoints;
  final Color color;
  PathPainter(this.pathPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (pathPoints.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = pathPoints.first;
    path.moveTo(first.dx * size.width, first.dy * size.height);
    for (var i = 1; i < pathPoints.length; i++) {
      final p = pathPoints[i];
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LinePainter extends CustomPainter {
  final List<Offset> dots;
  final List<int> connectedIndices;
  final bool ordered;
  final ThemeData theme;

  LinePainter({
    required this.dots,
    required this.connectedIndices,
    required this.ordered,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (connectedIndices.length < 2) return;

    final paint = Paint()
      ..color = Colors.green.shade600.withOpacity(0.7)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    if (ordered) {
      final sorted = List.of(connectedIndices)..sort();
      for (int i = 0; i < sorted.length - 1; i++) {
        final p1 = dots[sorted[i]];
        final p2 = dots[sorted[i + 1]];
        canvas.drawLine(
          Offset(p1.dx * size.width, p1.dy * size.height),
          Offset(p2.dx * size.width, p2.dy * size.height),
          paint,
        );
      }
    } else {
      if (connectedIndices.length == 2) {
        final p1 = dots[connectedIndices[0]];
        final p2 = dots[connectedIndices[1]];
        canvas.drawLine(
          Offset(p1.dx * size.width, p1.dy * size.height),
          Offset(p2.dx * size.width, p2.dy * size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnalysisPathPainter extends CustomPainter {
  final List<List<Offset>> paths;
  AnalysisPathPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final points in paths) {
      if (points.isEmpty) continue;
      final path = Path();
      path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
