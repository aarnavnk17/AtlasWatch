import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/sleek_animation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String _password = '';

  // Password requirements state
  bool get _hasMinLength => _password.length >= 8;
  bool get _hasUpperCase => _password.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _password.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  bool get _isPasswordValid =>
      _hasMinLength && _hasUpperCase && _hasNumber && _hasSpecial;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() {
        _password = _passwordController.text;
      });
    });
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please satisfy all password requirements'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final auth = AuthService();
      final error = await auth.register(
        email: email,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      if (error == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Signup successful')));
        Navigator.pop(context); // Return to login screen
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      debugPrint("Signup Error: $e");
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SleekAnimation(
                delay: Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join AtlasWatch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Protect yourself and your loved ones worldwide.',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // --- EMAIL FIELD ---
              SleekAnimation(
                delay: const Duration(milliseconds: 400),
                type: SleekAnimationType.slide,
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Email Address', Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // --- PASSWORD FIELD ---
              SleekAnimation(
                delay: const Duration(milliseconds: 500),
                type: SleekAnimationType.slide,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Secure Password', Icons.lock_outline_rounded),
                  onChanged: (val) => setState(() => _password = val),
                ),
              ),
              const SizedBox(height: 16),

              // --- PASSWORD REQUIREMENTS ---
              SleekAnimation(
                delay: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Security Requirements',
                        style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      _requirementRow('At least 8 characters', _hasMinLength),
                      _requirementRow('One uppercase letter', _hasUpperCase),
                      _requirementRow('One numeric digit', _hasNumber),
                      _requirementRow('One special character', _hasSpecial),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // --- SUBMIT BUTTON ---
              SleekAnimation(
                delay: const Duration(milliseconds: 800),
                type: SleekAnimationType.slide,
                slideOffset: const Offset(0, 0.1),
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _loading || !_isPasswordValid ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade900,
                      disabledForegroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: Colors.black45,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              SleekAnimation(
                delay: const Duration(milliseconds: 1000),
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Already have an account? Sign In",
                      style: TextStyle(color: Colors.blue.shade400, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
            size: 18,
            color: isMet ? Colors.green.shade400 : Colors.grey.shade700,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isMet ? Colors.white : Colors.grey.shade600,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      prefixIconColor: WidgetStateColor.resolveWith((states) => 
        states.contains(WidgetState.focused) ? Colors.blue.shade400 : Colors.grey.shade600
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }
}
