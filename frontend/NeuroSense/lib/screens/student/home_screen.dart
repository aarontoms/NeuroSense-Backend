import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final fss = FlutterSecureStorage();
  late Future<Map<String, String>> _userDetailsFuture;

  @override
  void initState() {
    super.initState();
    _userDetailsFuture = _getUserDetails();
  }

  Future<Map<String, String>> _getUserDetails() async {
    final name = await fss.read(key: 'user_name') ?? 'Friend';
    final role = await fss.read(key: 'user_role') ?? 'student';
    return {'name': name, 'role': role};
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  final List<Map<String, dynamic>> recommended = const [
    {
      'title': 'Attention Monitor',
      'subtitle': 'Tool',
      'emoji': '👁️',
      'color': Color(0xFFE8F5E9),
    },
    {
      'title': 'Connect Dots',
      'subtitle': 'Game',
      'emoji': '🎯',
      'color': Color(0xFFE3F2FD),
    },
    {
      'title': 'Face Monitor',
      'subtitle': 'tool',
      'emoji': '📸',
      'color': Color(0xFFF3E5F5),
    },
    {
      'title': 'Coloring Fun',
      'subtitle': 'Game',
      'emoji': '🎨',
      'color': Color(0xFFFCE4EC),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Transparent to show Scaffold background
      body: FutureBuilder<Map<String, String>>(
        future: _userDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final name = _capitalize(
            snapshot.data?['name'] ?? 'Friend',
          ); // Capitalize first letter
          final role = (snapshot.data?['role'] ?? 'student').toUpperCase();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 20,
                  ), // Less space, dashboard tag at top
                  // Dashboard Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '$role DASHBOARD',
                      style: AppTheme.buttonTextStyle(
                        fontSize: 12,
                        color: AppTheme.accent,
                      ),
                    ),
                  ).neoEntrance(),

                  const SizedBox(height: 16),

                  Text(
                    'Hi, $name',
                    style: AppTheme.headlineStyle(fontSize: 32),
                  ).neoEntrance(delay: 50),

                  const SizedBox(height: 8),

                  Text(
                    "Let's play and learn today!",
                    style: AppTheme.bodyStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ).neoEntrance(delay: 100),

                  const SizedBox(height: 32),

                  // Last Session card removed
                  const SizedBox(height: 24),

                  NeoButton(
                    onPressed: () => context.push('/autism-detection'),
                    color: AppTheme.accent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('▶️', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          'START TEST SESSION',
                          style: AppTheme.buttonTextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ).neoEntrance(delay: 300),

                  const SizedBox(height: 32),

                  Text(
                    'Recommended for You',
                    style: AppTheme.headlineStyle(fontSize: 22),
                  ).neoEntrance(delay: 400),

                  const SizedBox(height: 16),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: recommended.length,
                    itemBuilder: (context, i) {
                      final tile = recommended[i];
                      return GestureDetector(
                        onTap: () {
                          if (tile['title'] == 'Attention Monitor') {
                            context.push('/attention-monitor');
                          } else if (tile['title'] == 'Coloring Fun') {
                            context.push('/sensory-slime');
                          } else if (tile['title'] == 'Connect Dots') {
                            context.push('/connect-dots');
                          } else if (tile['title'] == 'Face Monitor') {
                            context.push('/iframe-activity');
                          } else {
                            context.go('/explore');
                          }
                        },
                        child: NeoBox(
                          color: tile['color'],
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tile['emoji'],
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tile['title'],
                                style: AppTheme.buttonTextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tile['subtitle'],
                                style: AppTheme.bodyStyle(
                                  fontSize: 12,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ).neoEntrance(delay: 500 + (i * 100)),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
