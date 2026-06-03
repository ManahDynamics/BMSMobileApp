// lib/screens/login_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

import 'package:bmsmobileapp/screens/register_screen.dart';
import 'package:bmsmobileapp/screens/forgotpassword_screen.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/services/translation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _green = Color(0xFF1B6B3A);
  static const _blue = Color(0xFF3A6EAC);
  static const _light = Color(0xFFF0F0F0);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true, _isLoading = false;
  String? _errorMessage;

  String _selectedLanguage = 'English';

  final Map<String, String> _langCodeMap = {
    'English': 'en',
    'Telugu': 'te',
    'Hindi': 'hi',
  };

  OverlayEntry? _overlayEntry;
  final _layerLink = LayerLink();

  String tr(String key) => TranslationService.t(key);

  @override
  void dispose() {
    _overlayEntry?.remove();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ───────────────── LANGUAGE ─────────────────

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _changeLanguage(String lang) async {
    setState(() => _selectedLanguage = lang);
    await TranslationService.loadTranslations(_langCodeMap[lang]!);
    if (mounted) setState(() {});
    _removeOverlay();
  }

  void _showLanguageOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              offset: const Offset(0, 44),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _langCodeMap.keys.map((lang) {
                      final selected = lang == _selectedLanguage;

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _changeLanguage(lang),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.grey.shade200
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            lang,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildLanguageDropdown() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _showLanguageOverlay,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                _selectedLanguage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── DEVICE INFO ─────────────────

  Future<Map<String, String>> _getDeviceInfo() async {
    final info = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return {
        'deviceId': android.id,
        'devicePlatform': 'android',
        'deviceToken': android.id,
      };
    }

    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      final id = ios.identifierForVendor ?? 'unknown';

      return {
        'deviceId': id,
        'devicePlatform': 'ios',
        'deviceToken': id,
      };
    }

    return {
      'deviceId': 'unknown',
      'devicePlatform': 'unknown',
      'deviceToken': 'unknown',
    };
  }

  // ───────────────── LOGIN API ─────────────────

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final device = await _getDeviceInfo();

      final response = await http
          .post(
            Uri.parse('http://15.207.26.224:3030/api/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
              ...device,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
              'Request timed out. Please try again.',
            ),
          );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final name = data['data']?['fullName'] ?? 'User';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, $name!'),
            backgroundColor: const Color(0xFF5E93D4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacementNamed(context, '/connect');
      } else {
        setState(() {
          _errorMessage =
              data['message']?.toString() ??
              data['error']?.toString() ??
              'Login failed. Please try again.';
        });
      }
    } on FormatException {
      setState(() {
        _errorMessage =
            'Unexpected server response. Please contact support.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
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
    TextInputType? type,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _light,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _textButton(String text, VoidCallback? onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: const TextStyle(
            color: _blue,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
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
            _bgCircle(size: 360, opacity: 0.07, top: -60, right: -60),
            _bgCircle(size: 220, opacity: 0.06, bottom: 80, left: -80),

            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildLanguageDropdown(),
                    ),
                  ),

                  const SizedBox(height: 28),

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
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

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

                  const SizedBox(height: 36),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputField(
                          controller: _emailController,
                          hint: tr('login.email_or_phone'),
                          icon: Icons.email_rounded,
                          type: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 16),

                        _inputField(
                          controller: _passwordController,
                          hint: tr('login.password'),
                          icon: Icons.lock_rounded,
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Align(
                          alignment: Alignment.centerRight,
                          child: _textButton(
                            tr('login.forgot_password'),
                            _isLoading
                                ? null
                                : () => Navigator.push(
                                      context,
                                      SlideRoute(
                                        page:
                                            const ForgotPasswordScreen(),
                                      ),
                                    ),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade400,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
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
                                    tr('login.login'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr('login.no_account_prefix'),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              _textButton(
                                tr('login.register_here'),
                                _isLoading
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          SlideRoute(
                                            page:
                                                const RegisterScreen(),
                                          ),
                                        ),
                              ),
                            ],
                          ),
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