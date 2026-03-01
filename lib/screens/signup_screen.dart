import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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

  Widget _requirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Password requirements list
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Password Requirements:',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _requirementRow('At least 8 characters', _hasMinLength),
                    _requirementRow('At least one uppercase letter', _hasUpperCase),
                    _requirementRow('At least one number', _hasNumber),
                    _requirementRow('At least one special character (!@#\$%...)',
                        _hasSpecial),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading || !_isPasswordValid ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
