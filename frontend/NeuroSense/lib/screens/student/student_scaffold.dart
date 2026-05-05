import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autism/services/auth_services.dart';
import '../../theme/app_theme.dart';

class StudentScaffold extends StatefulWidget {
  final Widget child;
  const StudentScaffold({super.key, required this.child});

  @override
  State<StudentScaffold> createState() => _StudentScaffoldState();
}

class _StudentScaffoldState extends State<StudentScaffold> {
  String _role = 'student';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthService.getUserRole();
    if (mounted && role != null) {
      setState(() {
        _role = role;
      });
    }
  }

  List<String> get _tabRoutes {
    if (_role == 'student') {
      return ['/home', '/explore'];
    } else if (_role == 'teacher') {
      return ['/home', '/explore', '/teacher/students'];
    } else {
      // Parent
      return ['/home', '/explore', '/parent/students'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    int currentIndex = _tabRoutes.indexOf(currentPath);
    if (currentIndex == -1) currentIndex = 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Main Body
          widget.child,

          // Profile Button (Top Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: NeoButton(
              onPressed: () => context.go('/profile'),
              borderRadius: 30, // Circle
              color: AppTheme.accent,
              child: const Text('👤', style: TextStyle(fontSize: 24)),
            ).neoEntrance(delay: 500),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        color: Colors.transparent,
        child: NeoBox(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          borderRadius: 32,
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _role == 'student'
                ? [
                    _buildNavItem(context, 0, '🏠', 'Home', currentIndex),
                    _buildNavItem(context, 1, '🧭', 'Explore', currentIndex),
                    // _buildNavItem(context, 2, '🎓', 'Courses', currentIndex),
                  ]
                : [
                    _buildNavItem(context, 0, '🏠', 'Home', currentIndex),
                    _buildNavItem(context, 1, '🧭', 'Explore', currentIndex),
                    _buildNavItem(context, 2, '🎓', 'Students', currentIndex),
                  ],
          ),
        ).neoEntrance(delay: 300),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    String emoji,
    String label,
    int currentIndex,
  ) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () {
        if (index < _tabRoutes.length) {
          context.go(_tabRoutes[index]);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? AppTheme.neoBorder()
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: isSelected
              ? [AppTheme.hardShadow(offset: const Offset(2, 2))]
              : [],
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
