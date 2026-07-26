import 'package:flutter/material.dart';
import 'package:ai_chatbot/db/chat_database.dart';
import 'package:ai_chatbot/auth/auth_service.dart';
import 'package:ai_chatbot/pages/sign_up_page.dart';
import 'package:ai_chatbot/chatbot_screen.dart';

class SignInPage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  const SignInPage({super.key, required this.isDark, required this.onThemeChanged});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = await ChatDatabase.instance.validateLogin(
      _identifierController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid username/email or password')));
      return;
    }

    await AuthService.saveSession(user['id'] as int, user['username'] as String);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChatbotScreen(isDark: widget.isDark, onThemeChanged: widget.onThemeChanged),
      ),
      (route) => false,
    );
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
                  Text('Welcome back',
                      style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _identifierController,
                    decoration: const InputDecoration(labelText: 'Username or email', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _signIn,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Sign in'),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => SignUpPage(isDark: widget.isDark, onThemeChanged: widget.onThemeChanged),
                        ),
                      );
                    },
                    child: const Text("Don't have an account? Sign up"),
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