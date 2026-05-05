import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this import
import 'router.dart';
import 'theme/app_theme.dart'; // Import AppTheme

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestCameraPermission();
  runApp(const MyApp());
}

Future<void> _requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isDenied) {
    debugPrint('Camera permission denied');
  } else if (status.isPermanentlyDenied) {
    await openAppSettings();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NeuroSense',
      debugShowCheckedModeBanner: false, // Clean look
      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.background, // Neo-Brutalist background
        primaryColor: AppTheme.accent,
        textTheme: GoogleFonts.outfitTextTheme( // Default to Outfit
          Theme.of(context).textTheme,
        ).apply(
          bodyColor: AppTheme.ink,
          displayColor: AppTheme.ink,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.accent,
          primary: AppTheme.accent,
          background: AppTheme.background,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
