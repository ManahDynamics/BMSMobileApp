import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ApiClient {
  final String baseUrl;
  String? _token;
  bool _isNavigatingToServerDown = false;

  ApiClient({required this.baseUrl});

  Map<String, String> _getHeaders() {
    final headers = {"Content-Type": "application/json"};
    if (_token != null && _token!.isNotEmpty) {
      headers["Authorization"] = "Bearer $_token";
    }
    return headers;
  }

  void _goToServerDown() {
    if (_isNavigatingToServerDown) return;
    _isNavigatingToServerDown = true;
    navigatorKey.currentState?.pushReplacementNamed('/server_down');
    Future.delayed(const Duration(seconds: 2), () {
      _isNavigatingToServerDown = false;
    });
  }

  bool _isServerError(Exception e) {
    final msg = e.toString();
    return !msg.contains('API Error');
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders())
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on TimeoutException {
      _goToServerDown();
      rethrow;
    } on Exception catch (e) {
      if (_isServerError(e)) _goToServerDown();
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, dynamic data) async {
    try {
      final response = await http
          .post(Uri.parse(endpoint),
              body: jsonEncode(data), headers: _getHeaders())
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on TimeoutException {
      _goToServerDown();
      rethrow;
    } on Exception catch (e) {
      if (_isServerError(e)) _goToServerDown();
      rethrow;
    }
  }

  Future<dynamic> put(String endpoint, dynamic data) async {
    try {
      final response = await http
          .put(Uri.parse(endpoint),
              body: jsonEncode(data), headers: _getHeaders())
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on TimeoutException {
      _goToServerDown();
      rethrow;
    } on Exception catch (e) {
      if (_isServerError(e)) _goToServerDown();
      rethrow;
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders())
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on TimeoutException {
      _goToServerDown();
      rethrow;
    } on Exception catch (e) {
      if (_isServerError(e)) _goToServerDown();
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 502 || response.statusCode == 503) {
      _goToServerDown();
      throw Exception('Server is currently unavailable.');
    } else {
      throw Exception('API Error: ${response.body}');
    }
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("accessToken", token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("accessToken");
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString("accessToken");
  }
}
