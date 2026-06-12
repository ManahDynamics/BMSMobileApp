// lib/services/token_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class TokenService {
  static const String _tokenKey = 'auth_token';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';
  static const String _refreshTokenKey = 'refresh_token';
  
  // Correct way to initialize FlutterSecureStorage
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // If you need platform-specific options, use this approach:
  // final FlutterSecureStorage _storage = FlutterSecureStorage(
  //   aOptions: AndroidOptions(
  //     encryptedSharedPreferences: true,
  //   ),
  //   iOptions: IOSOptions(
  //     accessibility: KeychainAccessibility.first_unlock,
  //   ),
  // );

  // Save token after login
  Future<bool> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      if (kDebugMode) {
        print('✅ Token saved successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving token: $e');
      }
      return false;
    }
  }

  // Get stored token
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error reading token: $e');
      }
      return null;
    }
  }

  // Save refresh token
  Future<bool> saveRefreshToken(String refreshToken) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      if (kDebugMode) {
        print('✅ Refresh token saved successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving refresh token: $e');
      }
      return false;
    }
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error reading refresh token: $e');
      }
      return null;
    }
  }

  // Save user email
  Future<bool> saveUserEmail(String email) async {
    try {
      await _storage.write(key: _userEmailKey, value: email);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error saving email: $e');
      return false;
    }
  }

  // Get user email
  Future<String?> getUserEmail() async {
    try {
      return await _storage.read(key: _userEmailKey);
    } catch (e) {
      if (kDebugMode) print('❌ Error reading email: $e');
      return null;
    }
  }

  // Save user name
  Future<bool> saveUserName(String name) async {
    try {
      await _storage.write(key: _userNameKey, value: name);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error saving name: $e');
      return false;
    }
  }

  // Get user name
  Future<String?> getUserName() async {
    try {
      return await _storage.read(key: _userNameKey);
    } catch (e) {
      if (kDebugMode) print('❌ Error reading name: $e');
      return null;
    }
  }

  // Save user ID
  Future<bool> saveUserId(String userId) async {
    try {
      await _storage.write(key: _userIdKey, value: userId);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error saving user ID: $e');
      return false;
    }
  }

  // Get user ID
  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _userIdKey);
    } catch (e) {
      if (kDebugMode) print('❌ Error reading user ID: $e');
      return null;
    }
  }

  // Save all user data at once
  Future<void> saveUserData({
    required String token,
    required String email,
    required String name,
    String? userId,
    String? refreshToken,
  }) async {
    await saveToken(token);
    await saveUserEmail(email);
    await saveUserName(name);
    if (userId != null) await saveUserId(userId);
    if (refreshToken != null) await saveRefreshToken(refreshToken);
  }

  // Clear all stored data (logout)
  Future<bool> clearAll() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userEmailKey);
      await _storage.delete(key: _userNameKey);
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _refreshTokenKey);
      
      if (kDebugMode) {
        print('✅ All user data cleared successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing data: $e');
      }
      return false;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await getToken();
      final isValid = token != null && token.isNotEmpty;
      if (kDebugMode) {
        print('🔐 Login status: $isValid');
      }
      return isValid;
    } catch (e) {
      return false;
    }
  }

  // Get all stored data (for debugging)
  Future<Map<String, String?>> getAllData() async {
    try {
      final token = await getToken();
      final email = await getUserEmail();
      final name = await getUserName();
      final userId = await getUserId();
      final refreshToken = await getRefreshToken();
      
      return {
        'token': token,
        'email': email,
        'name': name,
        'userId': userId,
        'refreshToken': refreshToken,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting all data: $e');
      }
      return {};
    }
  }

  // Check if token is expired (basic check - you can enhance this)
  Future<bool> isTokenExpired() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return true;
      
      // You can implement JWT token expiration check here
      // For now, we'll just check if token exists
      return false;
    } catch (e) {
      return true;
    }
  }
}