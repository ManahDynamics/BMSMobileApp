// modules/auth/services/auth_service.dart

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final ApiClient apiClient;
  
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
        // encryptedSharedPreferences: true,
    ),
  );

  AuthService(this.apiClient);

  static String? accessToken;
  static String? refreshToken;
  static String? userId;

  /// Load tokens from secure storage when app starts
  static Future<void> init() async {
    try {
      accessToken = await _secureStorage.read(key: "accessToken");
      refreshToken = await _secureStorage.read(key: "refreshToken");
      userId = await _secureStorage.read(key: "userId");
    } catch (e) {
      // print("Error initializing auth service: $e");
    }
  }

  /// Validate token with API
  static Future<bool> validateTokenWithApi() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) return false;
      return true;
    } catch (e) {
      // print("Error validating token: $e");
      return false;
    }
  }

  // 🔥 LOGIN
  Future<LoginResponse> login(LoginRequest request) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      request.toJson(),
    );
    if (response["success"] == true) {
      final loginRes = LoginResponse.fromJson(response);

      // ✅ Save tokens securely
      await saveTokens(loginRes);

      // ✅ Set token in API client
      if (loginRes.accessToken != null) {
        await apiClient.setToken(loginRes.accessToken!);
      }

      return loginRes;
    } else {
      throw Exception(response["message"] ?? "Login failed");
    }
  }

  // 🔐 Save tokens securely
  Future<void> saveTokens(LoginResponse res) async {
    try {
      await _secureStorage.write(key: "accessToken", value: res.accessToken ?? "");
      await _secureStorage.write(key: "refreshToken", value: res.refreshToken ?? "");
      await _secureStorage.write(key: "userId", value: res.userId ?? "");
      
      accessToken = res.accessToken;
      refreshToken = res.refreshToken;
      userId = res.userId;
    } catch (e) {
      // print("Error saving tokens: $e");
      throw Exception("Failed to save authentication tokens");
    }
  }

  // 🔓 Logout
  Future<void> logout() async {
    try {
      // print("Logging out user: $userId");
      await clearTokens();
      await apiClient.clearToken();
    } catch (e) {
      // print("Error during logout: $e");
    }
  }

  // Clear all tokens
  static Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: "accessToken");
      await _secureStorage.delete(key: "refreshToken");
      await _secureStorage.delete(key: "userId");
      
      accessToken = null;
      refreshToken = null;
      userId = null;
    } catch (e) {
      // print("Error clearing tokens: $e");
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      // Step 1: Check in-memory token first (instant, no I/O)
      if (accessToken != null && accessToken!.isNotEmpty) {
        return true;
      }

      // Step 2: Memory token absent (cold start / process restart) —
      // fall back to secure storage
      final storedToken = await _secureStorage.read(key: "accessToken");
      if (storedToken == null || storedToken.isEmpty) return false;

      // Sync in-memory token from storage so future calls skip storage
      accessToken = storedToken;
      return true;
    } catch (e) {
      // print("Error checking login status: $e");
      return false;
    }
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: "accessToken");
    } catch (e) {
      // print("Error getting access token: $e");
      return null;
    }
  }

  // Get user ID
  static Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: "userId");
    } catch (e) {
      // print("Error getting user ID: $e");
      return null;
    }
  }

  // static Future<Object?> isTokenExpired(String token) async {}
}