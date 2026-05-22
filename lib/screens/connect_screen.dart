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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          tr('connect.title'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                SlideRoute(page: const LoginScreen()),
                (route) => false,
              );
            },
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),

            // LOCAL
            _buildConnectionCard(
              context,
              title: tr('connect.local_monitoring'),
              subtitle: tr('connect.bluetooth_device'),
              icon: Icons.bluetooth_rounded,
              onTap: () => _handleLocalMonitoring(context),
            ),

            const SizedBox(height: 20),

            // REMOTE
            _buildConnectionCard(
              context,
              title: tr('connect.remote_monitoring'),
              subtitle: tr('connect.wifi_devices'),
              icon: Icons.router_rounded,
              onTap: () => _handleRemoteMonitoring(context),
            ),
          ],
        ),
      ),
    );
  }

  // UI CARD
  Widget _buildConnectionCard(
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
          color: const Color(0xFF1B6B3A),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: const Color(0xFF1B6B3A), size: 26),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // 🔵 LOCAL MONITORING FLOW
  // ============================
  void _handleLocalMonitoring(BuildContext context) async {
    if (!await FlutterBluePlus.isSupported) {
      _showBluetoothNotSupportedDialog(context);
      return;
    }

    final state = await FlutterBluePlus.adapterState.first;

    if (state == BluetoothAdapterState.off) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('connect.bluetooth_off')),
          content: Text(tr('connect.enable_bluetooth')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('connect.ok')),
            )
          ],
        ),
      );
      return;
    }

    // 🔥 IMPORTANT: CREATE SERVICE HERE OR USE PROVIDER
    final BMSBluetoothService service = BMSBluetoothService();

    // 🚀 GO TO SCAN SCREEN (ONLY SCREEN YOU NEED)
    Navigator.push(
      context,
      SlideRoute(
        page: BluetoothDeviceScanPage(service: service),
      ),
    );
  }

  // ============================
  void _handleRemoteMonitoring(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('connect.remote_coming_soon')),
        backgroundColor: const Color(0xFF1B6B3A),
      ),
    );
  }

  // ============================
  void _showBluetoothNotSupportedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('connect.bluetooth_not_supported')),
        content: Text(tr('connect.device_no_bluetooth')),
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