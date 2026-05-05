import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autism/services/auth_services.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _selectedRole = 'Parent';
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _descriptionController = TextEditingController(); // Student only
  final _dobController = TextEditingController(); // Student only
  final _institutionController = TextEditingController(); // Student and teacher only
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields', style: AppTheme.buttonTextStyle(color: Colors.white)),
          backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String successMessage = '';

      switch (_selectedRole.toLowerCase()) {
        case 'student':
          successMessage = await AuthService.studentSignup(
            _fullNameController.text,
            _emailController.text,
            _descriptionController.text,
            _passwordController.text,
            _dobController.text,
            _institutionController.text,
          );
          break;
        case 'parent':
          successMessage = await AuthService.parentSignup(
            _fullNameController.text,
            _emailController.text,
            _passwordController.text,
          );
          break;
        case 'teacher':
          successMessage = await AuthService.teacherSignup(
            _fullNameController.text,
            _emailController.text,
            _passwordController.text,
            _institutionController.text,
          );
          break;
        default:
          throw Exception('Unknown role: $_selectedRole');
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage, style: AppTheme.buttonTextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: ${e.toString()}', style: AppTheme.buttonTextStyle(color: Colors.white)),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isStudent = _selectedRole == 'Student';
    bool isTeacher = _selectedRole == 'Teacher';
    bool needsInstitution = isStudent || isTeacher;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center( // Center the content
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children
                children: [
                   Center(
                     child: NeoBox(
                       padding: const EdgeInsets.all(20),
                       borderRadius: 100,
                       child: const Text('✨', style: TextStyle(fontSize: 48)),
                     ).neoEntrance(),
                   ),
                  
                  const SizedBox(height: 24),
                  
                  Center(
                    child: Text(
                      'Create Account',
                      style: AppTheme.headlineStyle(fontSize: 32),
                    ).neoEntrance(delay: 100),
                  ),

                  const SizedBox(height: 32),

                  // Roles
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['Student', 'Parent', 'Teacher'].map((role) {
                        final isSelected = _selectedRole == role;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = role),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.accent : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: AppTheme.neoBorder(),
                                boxShadow: isSelected 
                                    ? [] 
                                    : [AppTheme.hardShadow(offset: const Offset(2, 2))],
                              ),
                              child: Text(
                                role,
                                style: AppTheme.buttonTextStyle(
                                  color: isSelected ? Colors.white : AppTheme.ink,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ).neoEntrance(delay: 200),

                  const SizedBox(height: 32),

                  NeoInput(
                    controller: _fullNameController,
                    label: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline, color: AppTheme.ink),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ).neoEntrance(delay: 300),
                  
                  const SizedBox(height: 16),
                  
                  NeoInput(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.ink),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ).neoEntrance(delay: 400),

                  if (isStudent) ...[
                    const SizedBox(height: 16),
                    NeoInput(
                      controller: _descriptionController,
                      label: 'Description',
                      maxLines: 2,
                      prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.ink),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ).neoEntrance(delay: 500),
                    
                    const SizedBox(height: 16),
                    
                    NeoInput(
                      controller: _dobController,
                      label: 'Date of Birth (YYYY-MM-DD)',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppTheme.ink),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ).neoEntrance(delay: 550),
                  ],

                  if (needsInstitution) ...[
                    const SizedBox(height: 16),
                    NeoInput(
                      controller: _institutionController,
                      label: 'Institution',
                      prefixIcon: const Icon(Icons.school_outlined, color: AppTheme.ink),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ).neoEntrance(delay: isStudent ? 600 : 500),
                  ],

                  const SizedBox(height: 16),
                  
                  NeoInput(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.ink),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.ink,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ).neoEntrance(delay: 700), // Adjusted delay

                  const SizedBox(height: 40),

                  NeoButton(
                    onPressed: _isLoading ? null : _signup,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('SIGN UP', style: AppTheme.buttonTextStyle(color: Colors.white)),
                  ).neoEntrance(delay: 800),

                  const SizedBox(height: 24),
                  
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: AppTheme.bodyStyle(),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: AppTheme.buttonTextStyle(color: AppTheme.accent),
                            ),
                          ],
                        ),
                      ),
                    ).neoEntrance(delay: 900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
