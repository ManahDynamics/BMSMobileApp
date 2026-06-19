// lib/screens/connect_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:bmsmobileapp/core/theme/app_colors.dart';
// import 'package:bmsmobileapp/core/theme/app_spacing.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/auth_service.dart';
import 'package:bmsmobileapp/services/token_service.dart';
import 'package:bmsmobileapp/core/api/routes/app_router.dart';

// ignore_for_file: use_build_context_synchronously

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
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
    super.dispose();
  }

  // ================= LOGOUT =================
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(tr('logout.title')),
          ],
        ),
        content: Text(tr('logout.confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              tr('logout.cancel'),
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('logout.confirm_button')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Forcefully terminate Bluetooth sessions
      await AppRouter.bmsService.disconnect().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      // Clear all tokens
      await AuthService.clearTokens();
      await TokenService().clearAll();

      await Future.delayed(const Duration(milliseconds: 250));
    } catch (e) {
      if (kDebugMode) print('Logout error: $e');
    }

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          tr('connect.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white),
            tooltip: tr('logout.title'),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 36),
            Text(
              tr('connect.choose_device'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),

            _card(
              title: tr('connect.local_monitoring'),
              subtitle: tr('connect.bluetooth_device'),
              icon: Icons.bluetooth_rounded,
              onTap: () => _localFlow(context),
            ),

            const SizedBox(height: 20),

            _card(
              title: tr('connect.remote_monitoring'),
              subtitle: tr('connect.wifi_devices'),
              icon: Icons.router_rounded,
              onTap: () => _remoteFlow(context),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI CARD =================
  Widget _card({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            _icon(icon),
            const SizedBox(width: 12),
            _text(title, subtitle),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _icon(IconData icon) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryGreen, size: 28),
      );

  Widget _text(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      );

  // ================= LOCAL FLOW =================
  Future<void> _localFlow(BuildContext context) async {
    if (!await FlutterBluePlus.isSupported) {
      _dialog(
        context,
        title: tr('connect.bluetooth_not_supported'),
        msg: tr('connect.device_no_bluetooth'),
      );
      return;
    }

    final state = await FlutterBluePlus.adapterState.first;

    if (state == BluetoothAdapterState.off) {
      _bluetoothOffDialog(context);
      return;
    }

    Navigator.push(
      context,
      SlideRoute(
        page: BluetoothDeviceScanPage(service: AppRouter.bmsService),
      ),
    );
  }

  // ================= REMOTE FLOW =================
  void _remoteFlow(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('connect.remote_coming_soon')),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================= BLUETOOTH OFF DIALOG =================
  void _bluetoothOffDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bluetooth_disabled_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(tr('connect.bluetooth_off')),
          ],
        ),
        content: Text(tr('connect.enable_bluetooth')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              tr('connect.cancel'),
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.bluetooth_rounded, size: 18),
            label: Text(tr('connect.enable')),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FlutterBluePlus.turnOn();

                final newState = await FlutterBluePlus.adapterState
                    .firstWhere((s) => s == BluetoothAdapterState.on)
                    .timeout(
                      const Duration(seconds: 10),
                      onTimeout: () => BluetoothAdapterState.off,
                    );

                if (newState == BluetoothAdapterState.on && mounted) {
                  Navigator.push(
                    context,
                    SlideRoute(
                      page: BluetoothDeviceScanPage(
                        service: AppRouter.bmsService,
                      ),
                    ),
                  );
                } else if (mounted) {
                  _dialog(
                    context,
                    title: tr('connect.bluetooth_off'),
                    msg: tr('connect.enable_bluetooth'),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _dialog(
                    context,
                    title: tr('connect.bluetooth_off'),
                    msg: tr('connect.enable_bluetooth_ios'),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= GENERIC INFO DIALOG =================
  void _dialog(BuildContext context, {required String title, required String msg}) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('connect.ok')),
          ),
        ],
      ),
    );
  }
}