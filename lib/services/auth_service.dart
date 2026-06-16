// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';

  static String? accessToken;
  static String? refreshToken;
  static String? userId;

  /// Load tokens from storage when app starts
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_keyAccessToken);
    refreshToken = prefs.getString(_keyRefreshToken);
    userId = prefs.getString(_keyUserId);
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyUserId, userId);

    AuthService.accessToken = accessToken;
    AuthService.refreshToken = refreshToken;
    AuthService.userId = userId;
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);

    accessToken = null;
    refreshToken = null;
    userId = null;
  }

  static bool get isLoggedIn =>
      accessToken != null && accessToken!.isNotEmpty;
}