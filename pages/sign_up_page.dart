import 'package:flutter/material.dart';
import 'package:ai_chatbot/db/chat_database.dart';
import 'package:ai_chatbot/auth/auth_service.dart';
import 'package:ai_chatbot/pages/sign_in_page.dart';
import 'package:ai_chatbot/chatbot_screen.dart';

class SignUpPage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  const SignUpPage({super.key, required this.isDark, required this.onThemeChanged});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (await ChatDatabase.instance.usernameExists(username)) {
      _showError('Username already taken');
      setState(() => _isLoading = false);
      return;
    }
    if (await ChatDatabase.instance.emailExists(email)) {
      _showError('Email already registered');
      setState(() => _isLoading = false);
      return;
    }

    final userId = await ChatDatabase.instance.createUser(username, email, password);
    await AuthService.saveSession(userId, username);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChatbotScreen(isDark: widget.isDark, onThemeChanged: widget.onThemeChanged),
      ),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.bolt_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Create your account',
                      style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Username must be at least 3 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v.trim())) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Sign up'),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => SignInPage(isDark: widget.isDark, onThemeChanged: widget.onThemeChanged),
                        ),
                      );
                    },
                    child: const Text('Already have an account? Sign in'),
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