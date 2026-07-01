// lib/screens/login_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bmsmobileapp/core/theme/app_colors.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/token_service.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';
import 'package:bmsmobileapp/modules/auth/models/login_request.dart';
import 'package:bmsmobileapp/modules/auth/models/login_response.dart';
import 'package:bmsmobileapp/modules/registration/screens/registration_screen.dart';
import 'package:bmsmobileapp/modules/forgotPassword/screens/forgot_password_screen.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/services/google_auth_service.dart';


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

  // ── Remember Me state ─────────────────────────────────────────────────────
  bool _rememberMe = true;

  static const _kRememberMeKey = 'remember_me';
  static const _kRememberedEmailKey = 'remembered_email';
  static const _kRememberedPasswordKey = 'remembered_password';

  String _selectedLanguage = 'English';

  final _langCodeMap = {
    'English': 'en',
    'Telugu':  'te',
    'Hindi':   'hi',
  };

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  final TokenService  _tokenService  = TokenService();
  final LocalAuthDB   _localAuthDB   = LocalAuthDB();
 final GoogleAuthService _googleAuthService = GoogleAuthService();
  @override
  void initState() {
    super.initState();
    _updateLanguageDisplay();
    TranslationService.instance.addListener(_onTranslationsChanged);
    _checkAlreadyLoggedIn();
    _loadRememberedCredentials();
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
    if (mounted) setState(_updateLanguageDisplay);
  }

  Future<void> _checkAlreadyLoggedIn() async {
    final isLoggedIn = await _tokenService.isLoggedIn();
    if (isLoggedIn && mounted) {
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.pushReplacementNamed(context, '/connect');
      });
    }
  }

  // ── Remember Me helpers ───────────────────────────────────────────────────

  /// Loads previously remembered credentials (if any) and pre-fills the form.
  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    final remembered = prefs.getBool(_kRememberMeKey) ?? true;
    final savedEmail    = prefs.getString(_kRememberedEmailKey) ?? '';
    final savedPassword = prefs.getString(_kRememberedPasswordKey) ?? '';

    if (!mounted) return;

    setState(() {
      _rememberMe = remembered;
      if (remembered) {
        _emailController.text    = savedEmail;
        _passwordController.text = savedPassword;
      }
    });
  }

  /// Persists or clears the remembered credentials based on [_rememberMe].
  Future<void> _persistRememberedCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_kRememberMeKey, _rememberMe);

    if (_rememberMe) {
      await prefs.setString(_kRememberedEmailKey, email);
      await prefs.setString(_kRememberedPasswordKey, password);
    } else {
      await prefs.remove(_kRememberedEmailKey);
      await prefs.remove(_kRememberedPasswordKey);
    }
  }

Future<void> _handleGoogleLogin() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final googleResult = await _googleAuthService.signIn();

    if (googleResult == null) {
      return;
    }

    final deviceInfo = await _getDeviceInfo();

    final response = await http.post(
      Uri.parse('http://15.207.26.224:3030/api/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        "loginType": "google",
        "googleIdToken": googleResult.firebaseIdToken,
        "deviceId": deviceInfo["deviceId"],
        "devicePlatform": deviceInfo["devicePlatform"],
        "deviceToken": deviceInfo["deviceToken"],
      }),
    );

    final Map<String, dynamic> rawJson = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final loginResponse = LoginResponse.fromJson(rawJson);

      final name = loginResponse.name ?? "User";
      final email = loginResponse.email ?? "";
      final userId = loginResponse.userId ?? "";

      if (loginResponse.accessToken != null &&
          loginResponse.accessToken!.isNotEmpty) {
        await _tokenService.saveToken(loginResponse.accessToken!);

        await _tokenService.saveUserEmail(email);

        await _tokenService.saveUserName(name);

        if (userId.isNotEmpty) {
          await _tokenService.saveUserId(userId);
        }

        if (loginResponse.refreshToken != null &&
            loginResponse.refreshToken!.isNotEmpty) {
          await _tokenService.saveRefreshToken(
            loginResponse.refreshToken!,
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Welcome back, $name!"),
          backgroundColor: const Color(0xFF5E93D4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacementNamed(context, '/connect');
    } else {
      setState(() {
        _errorMessage =
            rawJson["message"] ?? rawJson["error"] ?? "Google login failed";
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

void _continueAsGuest() {
  Navigator.pushReplacementNamed(context, '/connect');
}
  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
           result.contains(ConnectivityResult.wifi);
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

  // ── Language overlay (unchanged) ──────────────────────────────────────────

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
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                color: AppColors.overlayBackground,
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
                              _langCodeMap[lang]!);
                          _removeOverlay();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          color: isSelected
                              ? Colors.grey.shade100
                              : Colors.white,
                          child: Text(lang,
                              style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
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
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(_selectedLanguage,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Device info (unchanged) ───────────────────────────────────────────────

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission();
    }
    final deviceToken =
        await FirebaseMessaging.instance.getToken() ?? 'unknown';

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return {
        'deviceId'      : android.id,
        'devicePlatform': 'android',
        'deviceToken'   : deviceToken,
      };
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return {
        'deviceId'      : ios.identifierForVendor ?? 'unknown',
        'devicePlatform': 'ios',
        'deviceToken'   : deviceToken,
      };
    }
    return {
      'deviceId'      : 'unknown',
      'devicePlatform': 'unknown',
      'deviceToken'   : deviceToken,
    };
  }

  // ── Login handler ─────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading    = true;
    });

    try {
      final isOnline = await _isOnline();
      if (isOnline) {
        await _loginOnline(email, password);
      } else {
        await _loginOffline(email, password);
      }
    } on SocketException {
      // Network available but unreachable server — fall back to offline
      setState(() =>
          _errorMessage = 'Server unreachable. Trying offline login…');
      await _loginOffline(email, password);
    } catch (e) {
      setState(() =>
          _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Online login ──────────────────────────────────────────────────────────

  Future<void> _loginOnline(String email, String password) async {
    final deviceInfo = await _getDeviceInfo();

    final loginRequest = LoginRequest(
      email          : email,
      password       : password,
      deviceId       : deviceInfo['deviceId']!,
      devicePlatform : deviceInfo['devicePlatform']!,
      deviceToken    : deviceInfo['deviceToken']!,
    );

    final response = await http
        .post(
          Uri.parse('http://15.207.26.224:3030/api/auth/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept'       : 'application/json',
          },
          body: jsonEncode(loginRequest.toJson()),
        )
        .timeout(const Duration(seconds: 30));

    final Map<String, dynamic> rawJson = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final loginResponse = LoginResponse.fromJson(rawJson);

      final name         = loginResponse.name         ?? 'User';
      final userEmail    = loginResponse.email        ?? email;
      final userId       = loginResponse.userId       ?? '';
      final accessToken  = loginResponse.accessToken;
      final refreshToken = loginResponse.refreshToken;

      if (accessToken != null && accessToken.isNotEmpty) {
        await _tokenService.saveToken(accessToken);
        await _tokenService.saveUserEmail(userEmail);
        await _tokenService.saveUserName(name);
        if (userId.isNotEmpty) await _tokenService.saveUserId(userId);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _tokenService.saveRefreshToken(refreshToken);
        }
      }

      // ── Save credentials for future offline logins ──────────────────
      await _localAuthDB.saveUser(
        email    : userEmail,
        password : password,
        name     : name,
        userId   : userId,
      );

      // ── Remember Me: persist or clear locally stored credentials ─────
      await _persistRememberedCredentials(email: userEmail, password: password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content         : Text('Welcome back, $name!'),
          backgroundColor : const Color(0xFF5E93D4),
          behavior        : SnackBarBehavior.floating,
        ),
      );

      // Navigate — no offline banner needed
      Navigator.pushReplacementNamed(context, '/connect');
    } else {
      final msg = rawJson['message'] ?? rawJson['error'] ?? 'Login failed';
      setState(() => _errorMessage = msg.toString());
    }
  }

  // ── Offline login ─────────────────────────────────────────────────────────

  Future<void> _loginOffline(String email, String password) async {
    final user = await _localAuthDB.loginOffline(email, password);

    if (user != null) {
      // Restore user identity tokens so the rest of the app works
      await _tokenService.saveUserEmail(email);
      await _tokenService.saveUserName(user['name'] ?? 'User');
      if (user['user_id'] != null) {
        await _tokenService.saveUserId(user['user_id']);
      }

      // ── Remember Me: persist or clear locally stored credentials ─────
      await _persistRememberedCredentials(email: email, password: password);

      // Check whether we have BMS data cached
      final hasBMSData = await _localAuthDB.hasBMSCache();
      final syncTime   = await _localAuthDB.getLastSyncTime();

      if (!mounted) return;

      // Show offline snackbar with last-sync info
      final syncLabel = _formatSyncTime(syncTime);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasBMSData
                      ? 'Offline mode — showing data from $syncLabel'
                      : 'Offline mode — no BMS data cached yet',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor : Colors.orange.shade700,
          behavior        : SnackBarBehavior.floating,
          duration        : const Duration(seconds: 4),
        ),
      );

      Navigator.pushReplacementNamed(context, '/connect');
    } else {
      setState(() =>
          _errorMessage = 'Invalid email or password (offline mode)');
    }
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return 'unknown time';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inHours   < 1)  return '${diff.inMinutes}m ago';
    if (diff.inDays    < 1)  return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Input field builder (unchanged) ──────────────────────────────────────

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText             = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool isLastField             = false,
  }) {
    return Container(
      decoration: BoxDecoration(
          color            : AppColors.inputBackground,
          borderRadius     : BorderRadius.circular(10)),
      child: TextField(
        controller       : controller,
        obscureText      : obscureText,
        keyboardType     : keyboardType,
        textInputAction  : isLastField
            ? TextInputAction.done
            : TextInputAction.next,
        onSubmitted      : isLastField ? (_) => _handleLogin() : null,
        decoration       : InputDecoration(
          hintText   : hint,
          prefixIcon : Icon(icon, color: Colors.grey[600], size: 20),
          suffixIcon : suffixIcon,
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width  : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color        : Colors.red.shade50,
        borderRadius : BorderRadius.circular(10),
        border       : Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!,
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Remember Me + Forgot Password row ─────────────────────────────────────

  Widget _buildRememberMeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: _isLoading
              ? null
              : () => setState(() => _rememberMe = !_rememberMe),
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width : 20,
                height: 20,
                child : Checkbox(
                  value           : _rememberMe,
                  onChanged       : _isLoading
                      ? null
                      : (value) =>
                          setState(() => _rememberMe = value ?? true),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity   : VisualDensity.compact,
                  activeColor     : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                TranslationService.t('login.remember_me'),
                style: TextStyle(
                    color   : Colors.grey[700],
                    fontSize: 13),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _isLoading
              ? null
              : () => Navigator.push(
                  context,
                  SlideRoute(page: const ForgotPasswordScreen())),
          child: Text(
            TranslationService.t('login.forgot_password'),
            style: TextStyle(
                color      : AppColors.primaryBlue,
                fontSize   : 13,
                fontWeight : FontWeight.w600),
          ),
        ),
      ],
    );
  }

 Widget _buildDivider() {
  return Row(
    children: [
      Expanded(
        child: Divider(
          color: Colors.grey.shade300,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          TranslationService.t('login.or'),
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Divider(
          color: Colors.grey.shade300,
        ),
      ),
    ],
  );
}
Widget _buildGoogleButton() {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: _isLoading ? null : _handleGoogleLogin,
      icon: Image.asset(
        'assets/images/google_logo.png',
        width: 22,
      ),
      label: Text(
        TranslationService.t('login.continue_with_google'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
Widget _buildGuestButton() {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: _isLoading ? null : _continueAsGuest,
      icon: const Icon(Icons.person_outline),
      label: Text(
        TranslationService.t('login.continue_as_guest'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
Widget _buildRegister() {
  return Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TranslationService.t('login.no_account_prefix'),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _isLoading
              ? null
              : () => Navigator.push(
                    context,
                    SlideRoute(
                      page: const RegisterScreen(),
                    ),
                  ),
          child: Text(
            TranslationService.t('login.register_here'),
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
                top: -60, right: -60,
                child: Container(
                    width: 360, height: 360,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07)))),
            Positioned(
                bottom: 80, left: -80,
                child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06)))),

            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildLanguageDropdown()),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color        : Colors.white,
                      borderRadius : BorderRadius.circular(22),
                      boxShadow    : [
                        BoxShadow(
                          color     : Colors.black.withOpacity(0.18),
                          blurRadius: 20,
                          offset    : const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset('assets/images/logo.svg',
                            width: 120),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),
                  Text(TranslationService.t('login.app_title'),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: AppColors.textLight)),
                  const SizedBox(height: 6),
                  Text(TranslationService.t('login.app_subtitle'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textLightSecondary)),
                  const SizedBox(height: 36),

                  Container(
                    margin : const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color        : AppColors.cardBackground,
                      borderRadius : BorderRadius.circular(15),
                      boxShadow    : [
                        BoxShadow(
                          color     : Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                          offset    : const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          controller  : _emailController,
                          hint        : TranslationService.t('login.email_or_phone'),
                          icon        : Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller : _passwordController,
                          hint       : TranslationService.t('login.password'),
                          icon       : Icons.lock_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon : IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          isLastField: true,
                        ),
                        const SizedBox(height: 8),
                        _buildRememberMeRow(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _buildErrorMessage(),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width : double.infinity,
                          height: 52,
                          child : ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    width : 24,
                                    height: 24,
                                    child : CircularProgressIndicator(
                                        color      : Colors.white,
                                        strokeWidth: 2.5),
                                  )
                                : Text(TranslationService.t('login.login')),
                          ),
                        ),
                        const SizedBox(height: 20),

_buildDivider(),

const SizedBox(height: 20),

_buildGoogleButton(),

const SizedBox(height: 12),

_buildGuestButton(),

const SizedBox(height: 20),

_buildRegister(),
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