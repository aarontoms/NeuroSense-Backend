import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      // History is already included in the student object from /user/students
      print('📊 Student object: ${widget.student}');
      final history = widget.student['history'];
      print('📊 History data: $history');
      print('📊 History type: ${history.runtimeType}');

      if (history == null) {
        print('📊 No history found');
        setState(() {
          _history = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _history = history is List ? history : [];
        _isLoading = false;
        print('📊 Loaded ${_history.length} history items');
      });
    } catch (e) {
      print('📊 Error loading history: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getRiskColor(String? risk) {
    if (risk == null) return 'Unknown';
    final riskLower = risk.toLowerCase();
    if (riskLower.contains('high')) return 'High Risk';
    if (riskLower.contains('medium') || riskLower.contains('moderate')) {
      return 'Medium Risk';
    }
    if (riskLower.contains('low')) return 'Low Risk';
    return risk;
  }

  Color _getRiskBgColor(String? risk) {
    if (risk == null) return Colors.grey[300]!;
    final riskLower = risk.toLowerCase();
    if (riskLower.contains('high')) return Colors.red[100]!;
    if (riskLower.contains('medium') || riskLower.contains('moderate')) {
      return Colors.orange[100]!;
    }
    if (riskLower.contains('low')) return Colors.green[100]!;
    return Colors.grey[300]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.student['fullName'] ?? 'Student Details',
          style: AppTheme.headlineStyle(fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Detect which students list to go back to based on current path
            final currentPath = GoRouterState.of(context).uri.path;
            if (currentPath.contains('/parent/')) {
              context.go('/parent/students');
            } else if (currentPath.contains('/teacher/')) {
              context.go('/teacher/students');
            } else {
              // Fallback
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading history',
                    style: AppTheme.headlineStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error!,
                      style: AppTheme.bodyStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  NeoButton(
                    onPressed: _fetchHistory,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No Analysis History',
                    style: AppTheme.headlineStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This student hasn\'t completed\nany assessments yet.',
                    style: AppTheme.bodyStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  // Data is directly on the item, not nested in 'report'
                  final riskLevel = item['risk_level'];
                  final predictionPercentage = item['prediction_percentage'];
                  final analysisPoints = item['analysis_points'];
                  final environments = item['environments'];
                  final triggers = item['triggers'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: NeoBox(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header - Analysis #
                          Row(
                            children: [
                              const Icon(
                                Icons.assessment,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Analysis #${index + 1}',
                                  style: AppTheme.bodyStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              // Prediction percentage badge
                              if (predictionPercentage != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    '${predictionPercentage}%',
                                    style: AppTheme.buttonTextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Risk Assessment Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getRiskBgColor(riskLevel),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Text(
                              _getRiskColor(riskLevel),
                              style: AppTheme.buttonTextStyle(fontSize: 14),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Environments
                          if (environments != null &&
                              environments is List &&
                              environments.isNotEmpty) ...[
                            Text(
                              'Detected Environments',
                              style: AppTheme.buttonTextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                environments.length,
                                (i) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    environments[i].toString().replaceAll(
                                      '_',
                                      ' ',
                                    ),
                                    style: AppTheme.bodyStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Key Observations
                          if (analysisPoints != null &&
                              analysisPoints is List &&
                              analysisPoints.isNotEmpty) ...[
                            Text(
                              'Key Observations',
                              style: AppTheme.buttonTextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              analysisPoints.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 6,
                                  left: 8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        analysisPoints[i].toString(),
                                        style: AppTheme.bodyStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Triggers Timeline
                          if (triggers != null &&
                              triggers is List &&
                              triggers.isNotEmpty) ...[
                            Text(
                              'Trigger Timeline',
                              style: AppTheme.buttonTextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(triggers.length, (i) {
                              final trigger = triggers[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⏱️ ${trigger['timestamp'] ?? 'Unknown time'}',
                                        style: AppTheme.buttonTextStyle(
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        trigger['description']
                                                ?.toString()
                                                .replaceAll(', ', '\n• ') ??
                                            '',
                                        style: AppTheme.bodyStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ).neoEntrance(delay: index * 100),
                  );
                },
              ),
            ),
    );
  }
}
