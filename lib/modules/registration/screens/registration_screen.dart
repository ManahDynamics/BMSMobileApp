// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:bmsmobileapp/core/theme/app_colors.dart';
import 'package:bmsmobileapp/core/theme/app_spacing.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/device_token_service.dart'; // ← NEW
import 'package:bmsmobileapp/modules/registration/models/registration_request.dart';
import 'package:bmsmobileapp/modules/registration/services/registration_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onTranslationsChanged);
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    _fullNameController.dispose();
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  bool _isPhone(String value) =>
      RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value);

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Register Handler ─────────────────────────────────────────────────────

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim();
    final input = _emailOrPhoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty || input.isEmpty ||
        password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(tr('register.all_fields_required'));
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar(tr('register.passwords_do_not_match'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bool isPhone = _isPhone(input);

      // ─── Fetch real-time device info (token, id, platform) ───
      final deviceInfo = await DeviceTokenService.getDeviceInfo();

      final request = RegisterRequest(
        fullName: fullName,
        password: password,
        email: isPhone ? null : input,
        mobileNo: isPhone ? input : null,
        deviceToken: deviceInfo['deviceToken'],     // ← Real-time FCM token
        deviceId: deviceInfo['deviceId'],           // ← Device ID
        devicePlatform: deviceInfo['devicePlatform'], // ← android / ios / web
      );

      final response = await RegisterService.register(request);

      if (response.success) {
        _showSnackBar(response.message, isError: false);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.pop(context);
      } else {
        _showSnackBar(response.message);
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
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
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),

            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Logo
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
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

                  const SizedBox(height: 20),

                  Text(
                    tr('login.app_title'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('login.app_subtitle'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLightSecondary,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Form card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          tr('register.title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF4F4F4F),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Full Name
                        _buildInputField(
                          controller: _fullNameController,
                          hint: tr('register.full_name'),
                          icon: Icons.person_rounded,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Email or Phone
                        _buildInputField(
                          controller: _emailOrPhoneController,
                          hint: tr('register.email_or_phone'),
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Password
                        _buildPasswordField(
                          controller: _passwordController,
                          hint: tr('register.password'),
                          obscure: _obscurePassword,
                          onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Confirm Password
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          hint: tr('register.confirm_password'),
                          obscure: _obscureConfirmPassword,
                          onToggle: () => setState(() =>
                              _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
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

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr('register.already_have_account'),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              child: Text(
                                tr('register.login'),
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
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

  // ─── Reusable Input Field ───────────────────────────────────────────────

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
        ),
      ),
    );
  }

  // ─── Reusable Password Field ───────────────────────────────────────────

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_rounded,
              color: Colors.grey, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}