import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/attention_service.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AttentionAnalyticsScreen extends StatefulWidget {
  const AttentionAnalyticsScreen({super.key});

  @override
  State<AttentionAnalyticsScreen> createState() =>
      _AttentionAnalyticsScreenState();
}

class _AttentionAnalyticsScreenState extends State<AttentionAnalyticsScreen> {
  String _studentId = 'default';
  bool _loading = true;
  String? _error;

  // Data
  List<dynamic> _sessions = [];
  List<dynamic> _stimulusBreakdown = [];
  Map<String, dynamic>? _bestData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fss = FlutterSecureStorage();
      final id = await fss.read(key: 'user_id');
      if (id != null && id.isNotEmpty) _studentId = id;

      final results = await Future.wait([
        AttentionService.analyticsByStudent(_studentId),
        AttentionService.analyticsStudentStimulus(_studentId),
        AttentionService.analyticsStudentBest(_studentId),
      ]);

      if (mounted) {
        setState(() {
          _sessions = results[0] as List;
          _stimulusBreakdown = results[1] as List;
          _bestData = results[2] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Attention Analytics',
          style: AppTheme.headlineStyle(fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.ink),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // ── Best Session Card ──
                      if (_bestData != null) ...[
                        _buildBestCard(),
                        const SizedBox(height: 20),
                      ],

                      // ── Stimulus Breakdown ──
                      if (_stimulusBreakdown.isNotEmpty) ...[
                        Text(
                          'Stimulus Breakdown',
                          style: AppTheme.headlineStyle(fontSize: 20),
                        ).neoEntrance(delay: 100),
                        const SizedBox(height: 12),
                        ..._stimulusBreakdown
                            .asMap()
                            .entries
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildStimulusCard(e.value, e.key),
                                )),
                        const SizedBox(height: 20),
                      ],

                      // ── Session History ──
                      Text(
                        'Session History',
                        style: AppTheme.headlineStyle(fontSize: 20),
                      ).neoEntrance(delay: 200),
                      const SizedBox(height: 12),
                      if (_sessions.isEmpty)
                        NeoBox(
                          color: Colors.grey[100],
                          child: Center(
                            child: Text(
                              'No sessions yet. Start an attention session!',
                              style: AppTheme.bodyStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ).neoEntrance(delay: 300)
                      else
                        ..._sessions
                            .take(20)
                            .toList()
                            .asMap()
                            .entries
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildSessionCard(e.value, e.key),
                                )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: AppTheme.headlineStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTheme.bodyStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            NeoButton(
              onPressed: _loadData,
              color: AppTheme.accent,
              child: Text(
                'RETRY',
                style: AppTheme.buttonTextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestCard() {
    final bestSession = _bestData?['best_session'];
    final bestStimulus = _bestData?['best_stimulus'];

    return NeoBox(
      color: const Color(0xFFE8F5E9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text('Best Performance', style: AppTheme.headlineStyle(fontSize: 18)),
            ],
          ),
          const Divider(height: 24, thickness: 2, color: AppTheme.ink),
          if (bestSession != null) ...[
            Text('Best Session', style: AppTheme.buttonTextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '${bestSession['stimulus_name'] ?? 'Unknown'} — ${((bestSession['avg_attention'] ?? 0) * 100).toStringAsFixed(1)}% attention',
              style: AppTheme.bodyStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          if (bestStimulus != null) ...[
            Text(
              'Best Stimulus',
              style: AppTheme.buttonTextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${bestStimulus['stimulus_name'] ?? 'Unknown'} — ${((bestStimulus['avg_attention'] ?? 0) * 100).toStringAsFixed(1)}% avg across ${bestStimulus['sessions'] ?? 0} sessions',
              style: AppTheme.bodyStyle(fontSize: 14),
            ),
          ],
          if (bestSession == null && bestStimulus == null)
            Text(
              'No data yet',
              style: AppTheme.bodyStyle(fontSize: 14, color: Colors.grey),
            ),
        ],
      ),
    ).neoEntrance();
  }

  Widget _buildStimulusCard(dynamic stim, int index) {
    final name = stim['stimulus_name'] ?? 'Unknown';
    final avgAtt = ((stim['avg_attention'] ?? 0) * 100);
    final sessions = stim['total_sessions'] ?? 0;
    final focusScore = stim['focus_score'] ?? 0;
    final color = avgAtt >= 70
        ? Colors.green
        : avgAtt >= 40
            ? Colors.orange
            : Colors.red;

    return NeoBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${avgAtt.toStringAsFixed(0)}%',
                    style: AppTheme.buttonTextStyle(fontSize: 12, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTheme.buttonTextStyle(fontSize: 14)),
                    Text(
                      '$sessions sessions · Focus: ${focusScore.toStringAsFixed(0)}%',
                      style: AppTheme.bodyStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stim['focus_distribution'] != null) ...[
            const SizedBox(height: 12),
            _buildDistributionBar(stim['focus_distribution']),
          ],
        ],
      ),
    ).neoEntrance(delay: 150 + (index * 50));
  }

  Widget _buildDistributionBar(Map<String, dynamic> dist) {
    final high = (dist['high'] ?? 0) as int;
    final medium = (dist['medium'] ?? 0) as int;
    final low = (dist['low'] ?? 0) as int;
    final total = high + medium + low;
    if (total == 0) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Focus Distribution', style: AppTheme.buttonTextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.ink, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                Expanded(
                  flex: high,
                  child: Container(color: Colors.green),
                ),
                Expanded(
                  flex: medium,
                  child: Container(color: Colors.orange),
                ),
                Expanded(
                  flex: low,
                  child: Container(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _legendDot('High', Colors.green),
            const SizedBox(width: 12),
            _legendDot('Med', Colors.orange),
            const SizedBox(width: 12),
            _legendDot('Low', Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTheme.bodyStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildSessionCard(dynamic session, int index) {
    final name = session['stimulus_name'] ?? 'Unknown';
    final avgAtt = ((session['avg_attention'] ?? 0) * 100);
    final frames = session['frames_collected'] ?? 0;
    final blinks = session['blink_count'] ?? 0;
    final color = avgAtt >= 70
        ? Colors.green
        : avgAtt >= 40
            ? Colors.orange
            : Colors.red;

    return NeoBox(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                '${avgAtt.toStringAsFixed(0)}%',
                style: AppTheme.buttonTextStyle(fontSize: 11, color: color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTheme.buttonTextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '$frames frames · $blinks blinks',
                  style: AppTheme.bodyStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    ).neoEntrance(delay: 250 + (index * 30));
  }
}
