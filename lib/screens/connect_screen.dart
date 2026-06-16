import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/auth_service.dart';

// ignore_for_file: use_build_context_synchronously, deprecated_member_use

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const _primary = Color(0xFF1B6B3A);

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
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFF1B6B3A)),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B3A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true), // ✅ returns true
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Clear all stored tokens and user data
    await AuthService.clearTokens();

    if (!mounted) return;

    // Remove every route from the stack and navigate to login
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          tr('connect.title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
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
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),

            _card(
              context,
              title: tr('connect.local_monitoring'),
              subtitle: tr('connect.bluetooth_device'),
              icon: Icons.bluetooth_rounded,
              onTap: () => _localFlow(context),
            ),

            const SizedBox(height: 20),

            _card(
              context,
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
  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: _primary,
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _primary, size: 26),
      );

  Widget _text(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ],
      );

  // ================= LOCAL FLOW =================
  Future<void> _localFlow(BuildContext context) async {
    if (!await FlutterBluePlus.isSupported) {
      _dialog(context,
          title: tr('connect.bluetooth_not_supported'),
          msg: tr('connect.device_no_bluetooth'));
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
        page: BluetoothDeviceScanPage(service: BMSBluetoothService()),
      ),
    );
  }

  // ================= REMOTE FLOW =================
  void _remoteFlow(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('connect.remote_coming_soon')),
        backgroundColor: _primary,
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
              backgroundColor: _primary,
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

                if (newState == BluetoothAdapterState.on) {
                  Navigator.push(
                    context,
                    SlideRoute(
                      page: BluetoothDeviceScanPage(
                        service: BMSBluetoothService(),
                      ),
                    ),
                  );
                } else {
                  _dialog(context,
                      title: tr('connect.bluetooth_off'),
                      msg: tr('connect.enable_bluetooth'));
                }
              } catch (e) {
                _dialog(
                  context,
                  title: tr('connect.bluetooth_off'),
                  msg: tr('connect.enable_bluetooth_ios'),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= GENERIC INFO DIALOG =================
  void _dialog(BuildContext context,
      {required String title, required String msg}) {
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