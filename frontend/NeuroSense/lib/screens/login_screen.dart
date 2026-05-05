import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autism/services/auth_services.dart';
import '../theme/app_theme.dart'; // Import AppTheme

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Role selection removed
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signin(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful!', style: AppTheme.buttonTextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
            // Get role to decide navigation
            final role = await AuthService.getUserRole();
            if (role == 'teacher') {
                context.go('/teacher/upload'); // Teacher dashboard
            } else if (role == 'parent') {
                context.go('/home'); // Parent? Or student home with different tabs?
                // User said "for parents... new tab called students tab, remove activities".
                // Both parent and student go to /home (StudentScaffold) but the tabs differ.
            } else {
                context.go('/home');
            }
        }
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: AppTheme.buttonTextStyle(color: Colors.white)),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  NeoBox(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 100, // Circular
                    child: const Text('🧠', style: TextStyle(fontSize: 64)),
                  ).neoEntrance(),
                  
                  const SizedBox(height: 32),

                  Text(
                    'NeuroSense',
                    style: AppTheme.headlineStyle(fontSize: 40),
                  ).neoEntrance(delay: 100),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Welcome Back!',
                    style: AppTheme.bodyStyle(fontSize: 20),
                  ).neoEntrance(delay: 200),

                  const SizedBox(height: 40),

                  // Role Selection Removed
                  
                  const SizedBox(height: 32),

                  // Inputs
                  NeoInput(
                    label: 'Email',
                    controller: _emailController,
                    prefixIcon: const Icon(Icons.alternate_email, color: AppTheme.ink),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ).neoEntrance(delay: 400),
                  
                  const SizedBox(height: 20),

                  NeoInput(
                    label: 'Password',
                    controller: _passwordController,
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
                  ).neoEntrance(delay: 500),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Forgot password
                      },
                      child: Text(
                        'Forgot Password?',
                        style: AppTheme.bodyStyle(fontSize: 14, color: AppTheme.ink),
                      ),
                    ),
                  ).neoEntrance(delay: 600),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: NeoButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'LOGIN',
                              style: AppTheme.buttonTextStyle(color: Colors.white),
                            ),
                    ),
                  ).neoEntrance(delay: 700),

                  const SizedBox(height: 24),

                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: AppTheme.bodyStyle(),
                        children: [
                          TextSpan(
                            text: 'Register',
                            style: AppTheme.buttonTextStyle(color: AppTheme.accent),
                          ),
                        ],
                      ),
                    ),
                  ).neoEntrance(delay: 800),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
