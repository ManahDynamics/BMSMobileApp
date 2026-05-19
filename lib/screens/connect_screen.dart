// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/login_screen.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';

import 'package:bmsmobileapp/services/bluetooth_service.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'CONNECT',
          style: TextStyle(
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
            const Text(
              'Choose the Device option',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),

            // LOCAL
            _buildConnectionCard(
              context,
              title: 'Local Monitoring',
              subtitle: 'Bluetooth Device',
              icon: Icons.bluetooth_rounded,
              onTap: () => _handleLocalMonitoring(context),
            ),

            const SizedBox(height: 20),

            // REMOTE
            _buildConnectionCard(
              context,
              title: 'Remote Monitoring',
              subtitle: 'Wifi or 4G/5G Devices',
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
          title: const Text('Bluetooth Off'),
          content: const Text('Please enable Bluetooth to continue.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
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
      const SnackBar(
        content: Text('Remote monitoring coming soon!'),
        backgroundColor: Color(0xFF1B6B3A),
      ),
    );
  }

  // ============================
  void _showBluetoothNotSupportedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bluetooth Not Supported'),
        content: const Text('This device does not support Bluetooth.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
}