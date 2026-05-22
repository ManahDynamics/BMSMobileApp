// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

import 'package:bmsmobileapp/screens/register_screen.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';

import 'package:bmsmobileapp/services/translation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool    _obscurePassword = true;
  bool    _isLoading       = false;
  String? _errorMessage;

  String _selectedLanguage = 'English';

  final _langCodeMap = {
    'English': 'en',
    'Telugu': 'te',
    'Hindi': 'hi',
  };

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  String tr(String key) {
    return TranslationService.t(key);
  }

  @override
  void dispose() {
    _removeOverlay();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Overlay helpers ────────────────────────────────────────────────────

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showLanguageOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 44),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  child: SizedBox(
                    width: 140,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _langCodeMap.keys.map((lang) {
                        final isSelected = lang == _selectedLanguage;
                        return InkWell(
                          onTap: () async {
                            setState(() => _selectedLanguage = lang);
                            await TranslationService.loadTranslations(
                              _langCodeMap[lang]!,
                            );
                            if (mounted) setState(() {});
                            _removeOverlay();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.grey.shade200
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              lang,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: isSelected
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
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // ── Language dropdown widget ───────────────────────────────────────────

  Widget _buildLanguageDropdown() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _showLanguageOverlay,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
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
              const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Device info ────────────────────────────────────────────────────────

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return {
        'deviceId'      : android.id,
        'devicePlatform': 'android',
        'deviceToken'   : android.id,
      };
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return {
        'deviceId'      : ios.identifierForVendor ?? 'unknown',
        'devicePlatform': 'ios',
        'deviceToken'   : ios.identifierForVendor ?? 'unknown',
      };
    }

    return {
      'deviceId'      : 'unknown',
      'devicePlatform': 'unknown',
      'deviceToken'   : 'unknown',
    };
  }

  // ── Login API ──────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading    = true;
    });

    try {
      final deviceInfo = await _getDeviceInfo();

      final Map<String, String> body = {
        'email'         : _emailController.text.trim(),
        'password'      : _passwordController.text,
        'deviceId'      : deviceInfo['deviceId']!,
        'devicePlatform': deviceInfo['devicePlatform']!,
        'deviceToken'   : deviceInfo['deviceToken']!,
      };

      final response = await http.post(
        Uri.parse('http://15.207.26.224:3030/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw Exception('Request timed out. Please try again.'),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final userData = data['data'] as Map<String, dynamic>?;
        final name = userData?['fullName'] ?? 'User';

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
        final serverMessage =
            data['message']?.toString() ??
            data['error']?.toString() ??
            'Login failed. Please try again.';
        setState(() => _errorMessage = serverMessage);
      }
    } on FormatException {
      setState(() =>
          _errorMessage = 'Unexpected server response. Please contact support.');
    } catch (e) {
      setState(() =>
          _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B6B3A),
      body: SafeArea(
        child: Stack(
          children: [

            // ── Background decorative circles ──────────────────────────
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),

            // ── Main content ───────────────────────────────────────────
            SingleChildScrollView(
              child: Column(
                children: [

                  const SizedBox(height: 20),

                  // ── Language dropdown (top-right) ──────────────────
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildLanguageDropdown(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Logo ─────────────────────────────────────────
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
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── App title ────────────────────────────────────
                  Text(
                    tr('login.app_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('login.app_subtitle'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── White card ───────────────────────────────────
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

                        // ── Email field ──────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: tr('login.email_or_phone'),
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.email_rounded,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Password field ───────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: tr('login.password'),
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_rounded,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Forgot password ──────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              tr('login.forgot_password'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Error banner ─────────────────────────
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
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

                        // ── Login button ─────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A6EAC),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF3A6EAC).withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
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

                        // ── Divider ──────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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

                        // ── Register link ────────────────────────
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
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            SlideRoute(
                                              page: const RegisterScreen(),
                                            ),
                                          ),
                                  child: Text(
                                    tr('login.register_here'),
                                    style: const TextStyle(
                                      color: Color(0xFF3A6EAC),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
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