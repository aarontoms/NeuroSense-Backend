import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final fss = const FlutterSecureStorage();
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _getProfile();
  }

  Future<Map<String, dynamic>> _getProfile() async {
    final String? value = await fss.read(key: 'user_profile');
    if (value == null) return {};
    return jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> _logout(BuildContext context) async {
    await fss.deleteAll();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.ink),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Profile',
          style: AppTheme.headlineStyle(fontSize: 24),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final profile = snapshot.data ?? {};
          final name = profile["name"] ?? "Unknown User";

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Avatar
                NeoBox(
                  width: 140,
                  height: 140,
                  borderRadius: 70, // Circle
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: const Text('👤', style: TextStyle(fontSize: 80)),
                ).neoEntrance(),
                
                const SizedBox(height: 20),
                
                Text(
                  name,
                  style: AppTheme.headlineStyle(fontSize: 28),
                ).neoEntrance(delay: 100),
                
                const SizedBox(height: 40),

                _buildInfoTile(
                  emoji: '🏫',
                  title: profile['institution'] ?? 'Maplewood Elementary',
                  delay: 200,
                ),
                _buildInfoTile(
                  emoji: '📧',
                  title: profile['email'] ?? 'No Email',
                  subtitle: 'Email',
                  delay: 300,
                ),
                _buildInfoTile(
                  emoji: '📅',
                  title: profile['dateOfRegistration'] ?? 'Unknown Date',
                  subtitle: 'Joined',
                  delay: 400,
                ),

                const SizedBox(height: 60),

                SizedBox(
                  width: double.infinity,
                  child: NeoButton(
                    onPressed: () => _logout(context),
                    color: AppTheme.accent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'LOG OUT',
                          style: AppTheme.buttonTextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ).neoEntrance(delay: 500),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile({
    required String emoji,
    required String title,
    String? subtitle,
    required int delay,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeoBox(
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.buttonTextStyle(fontSize: 16),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodyStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ).neoEntrance(delay: delay),
    );
  }
}
