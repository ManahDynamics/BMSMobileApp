// lib/screens/login_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bmsmobileapp/screens/forgotpassword_screen.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/token_service.dart';
import 'package:bmsmobileapp/modules/auth/models/login_request.dart';
import 'package:bmsmobileapp/modules/auth/models/login_response.dart';
import 'package:bmsmobileapp/modules/registration/screens/registration_screen.dart';
// import 'package:bmsmobileapp/screens/connect_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedLanguage = 'English';

  final _langCodeMap = {
    'English': 'en',
    'Telugu': 'te',
    'Hindi': 'hi',
  };

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  final TokenService _tokenService = TokenService();

  @override
  void initState() {
    super.initState();
    _updateLanguageDisplay();
    TranslationService.instance.addListener(_onTranslationsChanged);
    _checkAlreadyLoggedIn();
  }

  void _updateLanguageDisplay() {
    final currentCode = TranslationService.language;
    final entry = _langCodeMap.entries.firstWhere(
      (e) => e.value == currentCode,
      orElse: () => _langCodeMap.entries.first,
    );
    _selectedLanguage = entry.key;
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() => _updateLanguageDisplay());
  }

  Future<void> _checkAlreadyLoggedIn() async {
    final isLoggedIn = await _tokenService.isLoggedIn();
    if (isLoggedIn && mounted) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      });
    }
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    _removeOverlay();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
              const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Device Info ───────────────────────────────────────────────────────────

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return {
        'deviceId': android.id,
        'devicePlatform': 'android',
        'deviceToken': android.id,
      };
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return {
        'deviceId': ios.identifierForVendor ?? 'unknown',
        'devicePlatform': 'ios',
        'deviceToken': ios.identifierForVendor ?? 'unknown',
      };
    }

    return {
      'deviceId': 'unknown',
      'devicePlatform': 'unknown',
      'deviceToken': 'unknown',
    };
  }

  // ─── Login Handler ─────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final deviceInfo = await _getDeviceInfo();

      // ── Build typed request model ──────────────────────────────────────────
      final loginRequest = LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        deviceId: deviceInfo['deviceId']!,
        devicePlatform: deviceInfo['devicePlatform']!,
        deviceToken: deviceInfo['deviceToken']!,
      );

      print('📡 Login request: ${loginRequest.toJson()}');

      final response = await http.post(
        Uri.parse('http://15.207.26.224:3030/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(loginRequest.toJson()),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw Exception('Request timed out. Please try again.'),
      );

      print('📡 Login response status: ${response.statusCode}');
      print('📡 Login response body: ${response.body}');

      final Map<String, dynamic> rawJson = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ── Parse into typed response model ─────────────────────────────────
        final loginResponse = LoginResponse.fromJson(rawJson);

        final name = loginResponse.name ?? 'User';
        final email =
            loginResponse.email ?? _emailController.text.trim();
        final userId = loginResponse.userId ?? '';
        final accessToken = loginResponse.accessToken;
        final refreshToken = loginResponse.refreshToken;

        // ── Persist session data ─────────────────────────────────────────────
        if (accessToken != null && accessToken.isNotEmpty) {
          await _tokenService.saveToken(accessToken);
          await _tokenService.saveUserEmail(email);
          await _tokenService.saveUserName(name);
          if (userId.isNotEmpty) await _tokenService.saveUserId(userId);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await _tokenService.saveRefreshToken(refreshToken);
          }
          print('✅ Token and user data saved successfully');
          print('✅ User: $name ($email)');
        } else {
          print('⚠️ No token received from server');
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, $name!'),
            backgroundColor: const Color(0xFF5E93D4),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        final serverMessage = rawJson['message']?.toString() ??
            rawJson['error']?.toString() ??
            'Login failed. Please try again.';
        setState(() => _errorMessage = serverMessage);
      }
    } on SocketException {
      setState(() =>
          _errorMessage = 'No internet connection. Please check your network.');
    } on FormatException {
      setState(() => _errorMessage =
          'Unexpected server response. Please contact support.');
    } catch (e) {
      setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B6B3A),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative circles
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

            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Language dropdown
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildLanguageDropdown(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Logo
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
                        child: SvgPicture.asset(
                          'assets/images/logo.svg',
                          width: 120,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // App title
                  Text(
                    TranslationService.t('login.app_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    TranslationService.t('login.app_subtitle'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Login form card
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
                        // Email field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: TranslationService.t(
                                  'login.email_or_phone'),
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

                        // Password field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              hintText:
                                  TranslationService.t('login.password'),
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

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        SlideRoute(
                                          page: const ForgotPasswordScreen(),
                                        ),
                                      ),
                              child: Text(
                                TranslationService.t('login.forgot_password'),
                                style: const TextStyle(
                                  color: Color(0xFF3A6EAC),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Error message
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
                              border:
                                  Border.all(color: Colors.red.shade200),
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

                        // Login button
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
                                    TranslationService.t('login.login'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Divider
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

                        // Register link
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                TranslationService.t(
                                    'login.no_account_prefix'),
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
                                    TranslationService.t(
                                        'login.register_here'),
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