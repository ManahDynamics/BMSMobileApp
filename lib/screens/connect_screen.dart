// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/login_screen.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  String tr(String key) => TranslationService.t(key);

  static const _primary = Color(0xFF1B6B3A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(tr('connect.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              SlideRoute(page: const LoginScreen()),
              (_) => false,
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 36),
            Text(tr('connect.choose_device'),
                style: const TextStyle(color: Colors.black54)),
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
      _dialog(context,
          title: tr('connect.bluetooth_off'),
          msg: tr('connect.enable_bluetooth'));
      return;
    }

    Navigator.push(
      context,
      SlideRoute(
        page: BluetoothDeviceScanPage(
          service: BMSBluetoothService(),
        ),
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
  // ================= DIALOG =================
  void _dialog(BuildContext context,
      {required String title, required String msg}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
         TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('connect.ok')),
          )
        ],
      ),
    );
  }
}