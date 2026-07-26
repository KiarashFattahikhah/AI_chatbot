import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyUserId = 'currentUserId';
  static const _keyUsername = 'currentUsername';

  static Future<void> saveSession(int userId, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUsername, username);
  }

  static Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  static Future<bool> isLoggedIn() async {
    return (await getCurrentUserId()) != null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
  }
}