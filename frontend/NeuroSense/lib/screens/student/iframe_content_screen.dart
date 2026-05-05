import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
// Import for Android-specific WebView features
import 'package:webview_flutter_android/webview_flutter_android.dart';

class IframeContentScreen extends StatefulWidget {
  final String url;
  final String title;

  const IframeContentScreen({
    super.key,
    // [ENTRY POINT] Default URL - Replace with your iframe source URL
    this.url =
        'https://mv1z79jg-5173.inc1.devtunnels.ms/', //this is for the face trigger detection of the student for autism detection.
    this.title = 'Face Analysis',
  });

  @override
  State<IframeContentScreen> createState() => _IframeContentScreenState();
}

class _IframeContentScreenState extends State<IframeContentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();

    if (await Permission.camera.status != PermissionStatus.granted ||
        await Permission.microphone.status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera and Microphone permissions are required for face detection',
            ),
          ),
        );
      }
    } else {
      // Load the URL only after permissions are granted
      if (mounted) {
        _controller.loadRequest(Uri.parse(widget.url));
      }
    }
  }

  // [ENTRY POINT] Initialize the iframe/webview controller
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );

    // Enable camera/microphone permissions on Android
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final AndroidWebViewController androidController =
          _controller.platform as AndroidWebViewController;

      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnPlatformPermissionRequest((
        PlatformWebViewPermissionRequest request,
      ) {
        request.grant();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,

      // Top Navigation Bar - Matching Connect Dots Style
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),

      body: Column(
        children: [
          // INSTRUCTION HEADER
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: AppTheme.neoBorder(),
              boxShadow: [AppTheme.hardShadow(offset: const Offset(2, 2))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Face Trigger Detection",
                        style: AppTheme.buttonTextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Monitoring facial cues for sensory triggers",
                        style: AppTheme.bodyStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black),
                  ),
                  child: const Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 1. Iframe / WebView Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              // Neo-Brutalism Style Container
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: AppTheme.neoBorder(), // Thick border
                boxShadow: [
                  // Hard shadow for "pop" effect
                  BoxShadow(
                    color: Colors.black12,
                    offset: const Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              clipBehavior:
                  Clip.hardEdge, // Ensure content stays inside rounded corners
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),

                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                        strokeWidth: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Info / Action Area (Optional - mirrors Connect Dots layout)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Analysis Controls",
                  style: AppTheme.headlineStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  "Monitor the real-time analysis stream for sensory triggers.",
                  style: AppTheme.bodyStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Finish Button
                SizedBox(
                  width: double.infinity,
                  child: NeoButton(
                    onPressed: () => context.go('/home'),
                    child: const Text("End Session"),
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
