import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class DeviceTokenService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _tokenKey = 'fcm_device_token';

  static Future<Map<String, String?>> getDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Step 1: Return cached token if already saved ──
      String? cachedToken = prefs.getString(_tokenKey);
      if (cachedToken != null && cachedToken.isNotEmpty) {
        debugPrint('[DeviceTokenService] Using cached token: $cachedToken');
        return {
          'deviceToken': cachedToken,
          'deviceId': await _getDeviceId(),
          'devicePlatform': _getPlatform(),
        };
      }

      // ── Step 2: Request permission ──
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return {
          'deviceToken': null,
          'deviceId': null,
          'devicePlatform': _getPlatform(),
        };
      }

      // ── Step 3: Fetch fresh token and cache it ──
      final token = await _messaging.getToken();
      if (token != null) {
        await prefs.setString(_tokenKey, token);
        debugPrint('[DeviceTokenService] New token saved: $token');
      }

      // ── Step 4: Listen for token refresh and update cache ──
      _messaging.onTokenRefresh.listen((newToken) async {
        final p = await SharedPreferences.getInstance();
        await p.setString(_tokenKey, newToken);
        debugPrint('[DeviceTokenService] Token refreshed & saved: $newToken');
        // TODO: Also send the new token to your backend here
      });

      return {
        'deviceToken': token,
        'deviceId': await _getDeviceId(),
        'devicePlatform': _getPlatform(),
      };
    } catch (e) {
      debugPrint('[DeviceTokenService] Error: $e');
      return {
        'deviceToken': null,
        'deviceId': null,
        'devicePlatform': _getPlatform(),
      };
    }
  }

  /// Call this on logout to clear the cached token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    debugPrint('[DeviceTokenService] Token cleared.');
  }

  static Future<String?> _getDeviceId() async {
    return 'device_${_getPlatform()}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}