import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_theme.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  final List<Map<String, dynamic>> activities = const [
    {
      'title': 'Mindful Breathing',
      'duration': '5 min calm down',
      'emoji': '🧘',
      'color': Color(0xFFE8F5E9),
    },
    {
      'title': 'Calm Music',
      'duration': '10 min listening',
      'emoji': '🎵',
      'color': Color(0xFFE3F2FD),
      'webUrl': 'https://attention1.vercel.app/',
    },
  ];

  final List<Map<String, dynamic>> games = const [
    {
      'title': 'Puzzle Time',
      'subtitle': 'Logic',
      'emoji': '🧩',
      'color': Color(0xFFFFF3E0),
    },
    {
      'title': 'Color Match',
      'subtitle': 'Creativity',
      'emoji': '🎨',
      'color': Color(0xFFFCE4EC),
    },
  ];

  final List<Map<String, dynamic>> courses = const [
    {
      'title': 'Understanding Emotions',
      'subtitle': 'Learn to identify and express feelings.',
      'tag': 'NEW',
      'emoji': '😊',
      'color': Color(0xFFFFF3E0),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Scaffold provided by parent or handle here? Inherited usually.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore',
                style: AppTheme.headlineStyle(fontSize: 32),
              ).neoEntrance(),
              
              Text(
                'Find new things to learn and do!',
                style: AppTheme.bodyStyle(fontSize: 18, color: Colors.grey[700]),
              ).neoEntrance(delay: 100),
              
              const SizedBox(height: 32),

              // Activities Section
              Text(
                'Activities',
                style: AppTheme.headlineStyle(fontSize: 24),
              ).neoEntrance(delay: 200),
              
              const SizedBox(height: 16),
              ...activities.asMap().entries.map((entry) {
                int idx = entry.key;
                var activity = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildActivityCard(activity, context).neoEntrance(delay: 300 + (idx * 100)),
                );
              }),
              
              const SizedBox(height: 32),

              // Games Section
              Text(
                'Games',
                style: AppTheme.headlineStyle(fontSize: 24),
              ).neoEntrance(delay: 400),
              
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.9, // Taller items
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: games.length,
                itemBuilder: (context, i) {
                  final game = games[i];
                  return GestureDetector(
                    onTap: () {
                      // Navigate to game detail later
                    },
                    child: NeoBox(
                      color: game['color'],
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(game['emoji'], style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            game['title'],
                            textAlign: TextAlign.center,
                            style: AppTheme.buttonTextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            game['subtitle'],
                            style: AppTheme.bodyStyle(fontSize: 12, color: AppTheme.ink.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ).neoEntrance(delay: 500 + (i * 100)),
                  );
                },
              ),
              
              const SizedBox(height: 32),

              // Courses Section
              Text(
                'Courses',
                style: AppTheme.headlineStyle(fontSize: 24),
              ).neoEntrance(delay: 600),
              
              const SizedBox(height: 16),
              ...courses.map((course) => _buildCourseCard(course, context).neoEntrance(delay: 700)),

              const SizedBox(height: 100), // Space for bottom navbar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, BuildContext context) {
    return NeoBox(
      color: activity['color'],
      child: Row(
        children: [
          Text(activity['emoji'], style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: AppTheme.buttonTextStyle(fontSize: 18),
                ),
                Text(
                  activity['duration'],
                  style: AppTheme.bodyStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: AppTheme.ink, size: 20),
            onPressed: () {
              if (activity['webUrl'] != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _WebEmbedScreen(url: activity['webUrl']),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, BuildContext context) {
    return NeoBox(
      color: course['color'],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(course['emoji'], style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    course['tag'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  course['title'],
                  style: AppTheme.buttonTextStyle(fontSize: 18),
                ),
                Text(
                  course['subtitle'],
                  style: AppTheme.bodyStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: NeoButton(
                    onPressed: () => context.push('/content-list'),
                    color: AppTheme.accent,
                    child: Text(
                      'START LEARNING',
                      style: AppTheme.buttonTextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebEmbedScreen extends StatefulWidget {
  final String url;
  const _WebEmbedScreen({required this.url});

  @override
  State<_WebEmbedScreen> createState() => _WebEmbedScreenState();
}

class _WebEmbedScreenState extends State<_WebEmbedScreen> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Activity', style: AppTheme.headlineStyle(fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: NeoBox(
         margin: const EdgeInsets.all(16),
         padding: EdgeInsets.zero,
         child: ClipRRect(
           borderRadius: BorderRadius.circular(22), // slightly less than box radius
           child: WebViewWidget(controller: controller),
         ),
      ),
    );
  }
}
