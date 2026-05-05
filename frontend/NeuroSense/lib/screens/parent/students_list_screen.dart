import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_services.dart';
import '../../theme/app_theme.dart';

class ParentStudentsListScreen extends StatefulWidget {
  const ParentStudentsListScreen({super.key});

  @override
  State<ParentStudentsListScreen> createState() =>
      _ParentStudentsListScreenState();
}

class _ParentStudentsListScreenState extends State<ParentStudentsListScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      final students = await AuthService.getStudents();
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('My Students', style: AppTheme.headlineStyle(fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: AppTheme.bodyStyle(color: Colors.red),
              ),
            )
          : _students.isEmpty
          ? Center(
              child: Text(
                'No students linked yet.',
                style: AppTheme.bodyStyle(),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to student detail screen
                      context.go('/parent/student-detail', extra: student);
                    },
                    child: NeoBox(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          NeoBox(
                            width: 50,
                            height: 50,
                            borderRadius: 25,
                            color: Colors.blue[100],
                            alignment: Alignment.center,
                            child: const Text(
                              '🎓',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['fullName'] ?? 'Unknown Student',
                                  style: AppTheme.buttonTextStyle(fontSize: 18),
                                ),
                                if (student['email'] != null)
                                  Text(
                                    student['email'],
                                    style: AppTheme.bodyStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ).neoEntrance(delay: index * 100),
                  ),
                );
              },
            ),
    );
  }
}
