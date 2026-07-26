import 'package:flutter/material.dart';
import 'package:ai_chatbot/auth/auth_gate.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 1. Define theme state (defaults to dark for initial launch)
  ThemeMode _themeMode = ThemeMode.dark;

  // 2. Function to toggle the state from anywhere
  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // 3. Define the AURA CHAT Color Palette
  static const Color kDarkNavy = Color(0xFF0D1B2A);
  static const Color kTextGrey = Color(0xFF7F8C8D);
  static const LinearGradient kPrimaryGradient = LinearGradient(
    colors: [Color(0xFF4A90E2), Color(0xFFF5A623)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA CHAT',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode, // 4. Apply the state

      // 5. Light Mode Theme definition
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.light(
          primary: kPrimaryGradient.colors[0], // Blue for icons/borders
          background: Color(0xFFFDFDFD), // Light paper background
          surface: Color(0xFFF9FAFB),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFF9FAFB),
          foregroundColor: kDarkNavy, // Navy title in light mode
        ),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: kTextGrey,
              displayColor: kDarkNavy,
            ),
      ),

      // 6. Dark Mode Theme definition
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: kPrimaryGradient.colors[0],
          background: Color(0xFF121212), // Dark paper background
          surface: Color(0xFF1A1A1A),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white70, // Light title in dark mode
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white70,
              displayColor: Colors.white,
            ),
      ),

      // 7. Pass state and callback function down to the screen
      home: AuthGate(
        isDark: _themeMode == ThemeMode.dark,
        onThemeChanged: toggleTheme,
      ),
    );
  }
}