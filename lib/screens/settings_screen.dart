// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isConnected = true;
  bool isLocked = true;

  // Protection parameter values
  double chargeCutoffVoltage = 3.65;
  double dischargeCutoffVoltage = 2.80;
  int tempMin = -10;
  int tempMax = 60;
  int chargeCurrentLimit = 50;
  int dischargeCurrentLimit = 100;
  int shortCircuitDelay = 100;
  double cellBalancingVoltage = 0.03;

  void _showUnlockDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Settings'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() => isLocked = false);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings unlocked!')),
              );
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(
      String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5FA5),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _editDoubleParam(
      String title, double current, String unit, Function(double) onSave) {
    final controller =
        TextEditingController(text: current.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                onSave(val);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editIntParam(
      String title, int current, String unit, Function(int) onSave) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                onSave(val);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon:
                const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(activeRoute: '/settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Device Connection Card ──────────────────────────────
            _buildDeviceCard(),
            const SizedBox(height: 16),

            // ── Lock Banner ─────────────────────────────────────────
            if (isLocked) _buildLockBanner(),
            if (isLocked) const SizedBox(height: 16),

            // ── Protection Parameters ───────────────────────────────
            const Text(
              'Protection Parameters',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),

            _buildParameterCard(
              icon: Icons.battery_charging_full_rounded,
              title: 'Charge Cuttoff Voltage',
              subtitle:
                  'Stop charging when cell voltage reaches this value',
              value: '${chargeCutoffVoltage.toStringAsFixed(2)} V',
              onTap: isLocked
                  ? null
                  : () => _editDoubleParam(
                        'Charge Cuttoff Voltage',
                        chargeCutoffVoltage,
                        'V',
                        (v) => setState(() => chargeCutoffVoltage = v),
                      ),
            ),
            _buildParameterCard(
              icon: Icons.battery_alert_rounded,
              title: 'Discharge Cuttoff Voltage',
              subtitle:
                  'Stop discharging when cell voltage falls below this value',
              value: '${dischargeCutoffVoltage.toStringAsFixed(2)} V',
              onTap: isLocked
                  ? null
                  : () => _editDoubleParam(
                        'Discharge Cuttoff Voltage',
                        dischargeCutoffVoltage,
                        'V',
                        (v) => setState(() => dischargeCutoffVoltage = v),
                      ),
            ),
            _buildParameterCard(
              icon: Icons.thermostat_rounded,
              title: 'Temperature Limit',
              subtitle:
                  'Stop operation when temperature goes beyond this range',
              value: '$tempMin   $tempMax °C',
              onTap: isLocked ? null : () {},
            ),
            _buildParameterCard(
              icon: Icons.electric_bolt_rounded,
              title: 'Charge Current Limit',
              subtitle: 'Maximum charging current allowed',
              value: '$chargeCurrentLimit A',
              onTap: isLocked
                  ? null
                  : () => _editIntParam(
                        'Charge Current Limit',
                        chargeCurrentLimit,
                        'A',
                        (v) => setState(() => chargeCurrentLimit = v),
                      ),
            ),
            _buildParameterCard(
              icon: Icons.electric_bolt_outlined,
              title: 'Discharge Current Limit',
              subtitle: 'Maximum discharging current allowed',
              value: '$dischargeCurrentLimit A',
              onTap: isLocked
                  ? null
                  : () => _editIntParam(
                        'Discharge Current Limit',
                        dischargeCurrentLimit,
                        'A',
                        (v) =>
                            setState(() => dischargeCurrentLimit = v),
                      ),
            ),
            _buildParameterCard(
              icon: Icons.timer_rounded,
              title: 'Short Circuit Protection Delay',
              subtitle:
                  'Delay before short circuit protection activates',
              value: '$shortCircuitDelay ms',
              onTap: isLocked
                  ? null
                  : () => _editIntParam(
                        'Short Circuit Delay',
                        shortCircuitDelay,
                        'ms',
                        (v) => setState(() => shortCircuitDelay = v),
                      ),
            ),
            _buildParameterCard(
              icon: Icons.balance_rounded,
              title: 'Cell Balancing Start Voltage',
              subtitle: 'Voltage at which cell balancing starts',
              value: '${cellBalancingVoltage.toStringAsFixed(2)} V',
              onTap: isLocked
                  ? null
                  : () => _editDoubleParam(
                        'Cell Balancing Start Voltage',
                        cellBalancingVoltage,
                        'V',
                        (v) =>
                            setState(() => cellBalancingVoltage = v),
                      ),
            ),

            const SizedBox(height: 20),

            // ── Reset Options ───────────────────────────────────────
            const Text(
              'Reset Options',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildResetButton(
                    icon: Icons.refresh_rounded,
                    label: 'Reset Warnings',
                    sublabel: 'Clear all warnings',
                    onTap: () => _showResetConfirmation(
                      'Reset Warnings',
                      'This will clear all warnings. Are you sure?',
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Warnings cleared')),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildResetButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Reset Counters',
                    sublabel: 'Reset cycle & stats',
                    onTap: () => _showResetConfirmation(
                      'Reset Counters',
                      'This will reset all cycle counts and stats. Are you sure?',
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Counters reset')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 190,
              child: _buildResetButton(
                icon: Icons.settings_backup_restore_rounded,
                label: 'Factory Reset',
                sublabel: 'Reset default values',
                onTap: () => _showResetConfirmation(
                  'Factory Reset',
                  'This will restore all settings to factory defaults. This cannot be undone.',
                  () {
                    setState(() {
                      chargeCutoffVoltage = 3.65;
                      dischargeCutoffVoltage = 2.80;
                      tempMin = -10;
                      tempMax = 60;
                      chargeCurrentLimit = 50;
                      dischargeCurrentLimit = 100;
                      shortCircuitDelay = 100;
                      cellBalancingVoltage = 0.03;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Factory reset complete')),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Warning Note ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Changing these parameters may impact battery performance and safety. Modify only if you understand the settings.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Widget Builders ─────────────────────────────────────────────────

  Widget _buildDeviceCard() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.white,

    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.battery_full_rounded,
              size: 28, color: Colors.black54),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BMS_001',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            Row(
              children: [
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: isConnected
                        ? const Color(0xFF1B6B3A)
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.circle,
                    size: 8,
                    color: isConnected
                        ? const Color(0xFF1B6B3A)
                        : Colors.red),
              ],
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4621A), // 👈 consistent orange
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          onPressed: () {
            // 👈 show confirmation dialog instead of toggling
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text(
                  'Disconnect',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: const Text(
                  'Are you sure you want to disconnect from BMS_001?',
                  textAlign: TextAlign.center,
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.pushAndRemoveUntil(
                        context,
                        SlideRoute(page: const BluetoothDeviceScanPage()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4621A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            );
          },
          child: const Text(
            'DISCONNECT',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildLockBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B5FA5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Protection Settings are Locked',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 32),
            child: Text(
              'Enter password to view and modify protection parameters',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side:
                  const BorderSide(color: Colors.white, width: 1),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _showUnlockDialog,
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: const Text('Unlock Settings',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.grey.shade300, width: 1.5),
              ),
              child:
                  Icon(icon, size: 20, color: Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: onTap != null
                  ? Colors.black54
                  : Colors.grey.shade300,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2B5FA5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(sublabel,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}