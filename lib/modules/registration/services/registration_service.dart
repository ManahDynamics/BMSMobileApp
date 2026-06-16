// lib/modules/auth/services/register_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/registration_response.dart';
import '../models/registration_request.dart';

class RegisterService {
  static const String _baseUrl = 'http://15.207.26.224:3030';

  /// Calls the register API and returns a [RegisterResponse].
  /// Throws a descriptive [Exception] on network or timeout errors.
  static Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/auth/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

      print('📡 Register response status : ${response.statusCode}');
      print('📡 Register response body   : ${response.body}');

      final Map<String, dynamic> json = jsonDecode(response.body);
      final bool success =
          response.statusCode == 200 || response.statusCode == 201;

      return RegisterResponse.fromJson(json, success: success);
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on FormatException {
      throw Exception('Unexpected server response. Please contact support.');
    }
    // Other exceptions (timeout, etc.) bubble up as-is
  }
}