import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autism/services/auth_services.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();

    Timer(const Duration(seconds: 2), () async {
      final loggedIn = await AuthService.isLoggedIn();
      if (loggedIn) {
        final role = await AuthService.getUserRole();
        if (role != null && role.toLowerCase() == 'teacher') {
          context.go('/teacher/upload');
        } else {
          context.go('/home');
        }
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  // Logo Container
                  NeoBox(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 40,
                    color: Colors.white,
                    child: Image.asset(
                      'assets/image-removebg-preview (2).png',
                      width: 100,
                      height: 100,
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'NeuroSense',
                    style: AppTheme.headlineStyle(
                      fontSize: 42,
                      color: AppTheme.accent,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Skeletal-based autism trigger monitoring',
                    style: AppTheme.bodyStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // Styled Progress Indicator
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    backgroundColor: AppTheme.ink.withOpacity(0.1),
                    color: AppTheme.accent,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LOADING...',
                    style: AppTheme.buttonTextStyle(
                      fontSize: 14,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ).neoEntrance(delay: 500),
          ],
        ),
      ),
    );
  }
}
