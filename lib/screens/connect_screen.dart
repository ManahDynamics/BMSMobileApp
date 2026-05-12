import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_device_scan_page.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7D4F),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CONNECT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Refresh functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Choose Connection Type',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E7D4F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select how you want to connect to your BMS',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            
            // Local Monitoring Card
            _buildConnectionCard(
              context,
              title: 'Local Monitoring',
              subtitle: 'Bluetooth Device',
              icon: Icons.bluetooth,
              onTap: () => _handleLocalMonitoring(context),
            ),
            
            const SizedBox(height: 20),
            
            // Remote Monitoring Card
            _buildConnectionCard(
              context,
              title: 'Remote Monitoring',
              subtitle: 'Wifi or 4G/5G Devices',
              icon: Icons.wifi,
              onTap: () => _handleRemoteMonitoring(context),
            ),
          ],
        ),
      ),
    );
  }

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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1E7D4F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1E7D4F),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E7D4F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _handleLocalMonitoring(BuildContext context) async {
    // Check if Bluetooth is enabled
    if (!await FlutterBluePlus.isSupported) {
      _showBluetoothNotSupportedDialog(context);
      return;
    }

    // Check Bluetooth adapter state
    var adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState == BluetoothAdapterState.off) {
      // Show simple alert when Bluetooth is off
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Alert'),
            content: const Text('Your Bluetooth is off'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    // If Bluetooth is on, navigate to Bluetooth Device Scan page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BluetoothDeviceScanPage(),
      ),
    );
  }

  void _handleRemoteMonitoring(BuildContext context) {
    // TODO: Implement remote monitoring
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Remote monitoring coming soon!'),
        backgroundColor: Color(0xFF1E7D4F),
      ),
    );
  }

  
  
  void _showBluetoothNotSupportedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth Not Supported'),
          content: const Text(
            'This device does not support Bluetooth.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
