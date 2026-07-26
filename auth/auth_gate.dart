import 'package:flutter/material.dart';
import 'package:ai_chatbot/auth/auth_service.dart';
import 'package:ai_chatbot/pages/sign_up_page.dart';
import 'package:ai_chatbot/chatbot_screen.dart';

class AuthGate extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  const AuthGate({super.key, required this.isDark, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final loggedIn = snapshot.data ?? false;
        return loggedIn
            ? ChatbotScreen(isDark: isDark, onThemeChanged: onThemeChanged)
            : SignUpPage(isDark: isDark, onThemeChanged: onThemeChanged);
      },
    );
  }
}