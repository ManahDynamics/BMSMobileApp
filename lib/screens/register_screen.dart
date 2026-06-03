// ignore_for_file: unnecessary_const, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:bmsmobileapp/services/translation_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _green = Color(0xFF1B6B3A);
  static const _blue = Color(0xFF3A6EAC);
  static const _fieldBg = Color(0xFFF0F0F0);

  final _fullNameController = TextEditingController();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true,
      _obscureConfirmPassword = true,
      _isLoading = false;

  String tr(String key) => TranslationService.t(key);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isPhone(String value) =>
      RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value);

  void _showSnackBar(String msg, {bool error = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ───────────────── REGISTER API ─────────────────

  Future<void> _register() async {
    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final input = _emailOrPhoneController.text.trim();
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if ([fullName, input, password, confirmPassword]
          .any((e) => e.isEmpty)) {
        _showSnackBar('All fields are required');
        return;
      }

      if (password != confirmPassword) {
        _showSnackBar('Passwords do not match');
        return;
      }

      final isPhone = _isPhone(input);

      final response = await http
          .post(
            Uri.parse('http://15.207.26.224:3030/api/auth/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              "fullName": fullName,
              "password": password,
              "email": isPhone ? null : input,
              "mobileNo": isPhone ? input : null,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          data['message'] ?? 'Registration successful!',
          error: false,
        );

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) Navigator.pop(context);
      } else {
        _showSnackBar(
          data['message'] ??
              data['error'] ??
              'Registration failed. Please try again.',
        );
      }
    } on FormatException {
      _showSnackBar('Unexpected server response.');
    } catch (e) {
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────── COMMON WIDGETS ─────────────────

  Widget _bgCircle({
    required double size,
    required double opacity,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.grey[600],
            size: 20,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return _inputField(
      controller: controller,
      hint: hint,
      icon: Icons.lock_rounded,
      obscure: obscure,
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  // ───────────────── BUILD ─────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green,
      body: SafeArea(
        child: Stack(
          children: [
            _bgCircle(
              size: 360,
              opacity: 0.07,
              top: -60,
              right: -60,
            ),
            _bgCircle(
              size: 220,
              opacity: 0.06,
              bottom: 60,
              left: -80,
            ),

            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // ───────────────── LOGO ─────────────────

                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    tr('login.app_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    tr('login.app_subtitle'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ───────────────── FORM CARD ─────────────────

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          tr('register.title'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F4F4F),
                          ),
                        ),

                        const SizedBox(height: 20),

                        _inputField(
                          controller: _fullNameController,
                          hint: tr('register.full_name'),
                          icon: Icons.person_rounded,
                        ),

                        const SizedBox(height: 14),

                        _inputField(
                          controller: _emailOrPhoneController,
                          hint: tr('register.email_or_phone'),
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 14),

                        _passwordField(
                          controller: _passwordController,
                          hint: tr('register.password'),
                          obscure: _obscurePassword,
                          onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _passwordField(
                          controller: _confirmPasswordController,
                          hint: tr('register.confirm_password'),
                          obscure: _obscureConfirmPassword,
                          onToggle: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ───────────────── REGISTER BUTTON ─────────────────

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _blue.withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    tr('register.register'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr('register.already_have_account'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text(
                                ' Login',
                                style: TextStyle(
                                  color: _blue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}