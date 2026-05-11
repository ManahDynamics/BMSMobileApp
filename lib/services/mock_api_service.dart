// lib/services/mock_api_service.dart

import 'dart:async';

/// Simulates a backend API using hardcoded JSON data.
/// Replace this with real HTTP calls (e.g. via `http` or `dio`) later.
class MockApiService {
  MockApiService._();
  static final MockApiService instance = MockApiService._();

  // ── Hardcoded "database" ────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _users = [
    {
      'id': 1,
      'name': 'Admin',
      'email': 'admin@manah.com',
      'phone': '9000000001',
      'password': 'Manah@123',
      'role': 'admin',
    },
    {
      'id': 2,
      'name': 'user',
      'email': 'user@manah.com',
      'phone': '9000000002',
      'password': 'Manah@123',
      'role': 'user',
    },
   
  ];

  int _nextId = 4;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Simulates network latency.
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 800));

  Map<String, dynamic>? _findUser(String emailOrPhone) {
    final query = emailOrPhone.trim().toLowerCase();
    try {
      return _users.firstWhere(
        (u) =>
            u['email'].toString().toLowerCase() == query ||
            u['phone'].toString() == query,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Login with email/phone + password.
  /// Returns the user map on success, throws [ApiException] on failure.
  Future<Map<String, dynamic>> login({
    required String emailOrPhone,
    required String password,
  }) async {
    await _delay();

    final user = _findUser(emailOrPhone);

    if (user == null) {
      throw ApiException('No account found with that email or phone number.');
    }

    if (user['password'] != password) {
      throw ApiException('Incorrect password. Please try again.');
    }

    // Return a safe copy without the password
    return Map<String, dynamic>.from(user)..remove('password');
  }

  /// Register a new user.
  /// Returns the created user on success, throws [ApiException] on failure.
  Future<Map<String, dynamic>> register({
    required String name,
    required String emailOrPhone,
    required String password,
  }) async {
    await _delay();

    if (name.trim().isEmpty) {
      throw ApiException('Name cannot be empty.');
    }

    if (emailOrPhone.trim().isEmpty) {
      throw ApiException('Email or phone number cannot be empty.');
    }

    if (password.length < 6) {
      throw ApiException('Password must be at least 6 characters.');
    }

    if (_findUser(emailOrPhone) != null) {
      throw ApiException('An account with this email or phone already exists.');
    }

    final newUser = {
      'id': _nextId++,
      'name': name.trim(),
      'email': emailOrPhone.contains('@') ? emailOrPhone.trim() : '',
      'phone': emailOrPhone.contains('@') ? '' : emailOrPhone.trim(),
      'password': password,
      'role': 'user',
    };

    _users.add(newUser);

    return Map<String, dynamic>.from(newUser)..remove('password');
  }
}

// ── Exception type ───────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}