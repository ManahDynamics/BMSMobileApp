// lib/modules/registration/services/registration_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/registration_response.dart';
import '../models/registration_request.dart';

class RegisterService {
  static const String _baseUrl = 'http://15.207.26.224:3030';

  static Future<RegisterResponse> register(RegisterRequest request) async {
    final uri = Uri.parse('$_baseUrl/api/auth/register');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final isSuccess = response.statusCode == 200 || response.statusCode == 201;

    if (!isSuccess) {
      throw Exception(
        json['message']?.toString() ??
        json['error']?.toString() ??
        'Registration failed.',
      );
    }

    return RegisterResponse.fromJson(json, success: true);
  }
}