// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/login_screen.dart';
import 'package:bmsmobileapp/screens/editprofile_screen.dart';
import 'package:bmsmobileapp/screens/forgotpassword_screen.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/screens/cells_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/parsed_packet.dart';
import 'package:bmsmobileapp/services/translation_service.dart';

class DashboardScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const DashboardScreen({super.key, required this.service});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const green = Color(0xFF1B6B3A);
  static const blue = Color(0xFF3A6EAC);
  static const orange = Color(0xFFD4621A);

  static const gap12 = SizedBox(height: 12);
  static const gap16 = SizedBox(height: 16);

  final deviceName = 'BMS_001';
  final batteryStatus = 'Discharging';
  final remainingTime = '04h 35m';
  final temperature = 32.0;
  final minCell = 3.215;
  final maxCell = 3.298;

  final cellValues = [
    3.24,
    3.28,
    3.22,
    3.29,
    3.25,
    3.27,
    3.21,
    3.30,
    3.26,
    3.23
  ];

  String tr(String key) => TranslationService.t(key);

  Future<void> _disconnect() async {
    await widget.service.disconnect();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)),
      (_) => false,
    );
  }

  void _showDialogBox({
    required String title,
    required String content,
    required String buttonText,
    required Color color,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          content,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              tr('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) async {
    final button = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final offset = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        overlay.size.width,
        offset.dy + button.size.height,
        8,
        0,
      ),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      items: [
        _popupItem(
          'edit_profile',
          Icons.person_outline_rounded,
          tr('edit_profile'),
        ),
        const PopupMenuDivider(height: 1),
        _popupItem(
          'forgot_password',
          Icons.lock_reset_rounded,
          tr('forget_password'),
        ),
        const PopupMenuDivider(height: 1),
        _popupItem(
          'logout',
          Icons.logout_rounded,
          tr('logout'),
          color: Colors.red,
        ),
      ],
    );

    final routes = {
      'edit_profile': const EditProfileScreen(),
      'forgot_password': const ForgotPasswordScreen(),
    };

    if (routes.containsKey(result)) {
      Navigator.push(
        context,
        SlideRoute(page: routes[result]!),
      );
    }

    if (result == 'logout') {
      _showDialogBox(
        title: tr('logout'),
        content: tr('logout_confirmation'),
        buttonText: tr('logout'),
        color: blue,
        onConfirm: () {
          Navigator.pushAndRemoveUntil(
            context,
            SlideRoute(page: const LoginScreen()),
            (_) => false,
          );
        },
      );
    }
  }

  PopupMenuItem<String> _popupItem(
    String value,
    IconData icon,
    String text, {
    Color color = Colors.black87,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _metricRow(Widget a, Widget b) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: green,
      elevation: 0,
      centerTitle: true,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(
        tr('dashboard'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        Builder(
          builder: (ctx) => IconButton(
            onPressed: () => _showMenu(ctx),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _deviceHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.battery_4_bar_rounded,
            color: Colors.black54,
            size: 32,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  tr('connected'),
                  style: const TextStyle(
                    color: green,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            _showDialogBox(
              title: tr('disconnect'),
              content: tr('disconnect_confirmation'),
              buttonText: tr('disconnect'),
              color: orange,
              onConfirm: _disconnect,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: Text(tr('disconnect')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(
        activeRoute: '/dashboard',
        service: widget.service,
      ),
      appBar: _appBar(),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (_, _) {
          final BMSParsedPacket? p4 = widget.service.latestPacket4;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _deviceHeader(),
                gap16,

                _BatteryStatusCard(
                  soc: p4?.soc ?? 0,
                  capacity: p4?.capacityDisplay ?? '– Ah',
                  batteryStatus: batteryStatus,
                  remainingTime: remainingTime,
                ),

                gap16,

                _metricRow(
                  _MetricCard(
                    label: tr('voltage'),
                    value: p4?.voltageDisplay ?? '– V',
                    iconLabel: 'V',
                  ),
                  _MetricCard(
                    label: tr('current'),
                    value: p4?.currentDisplay ?? '– A',
                    subtitle: tr('discharging'),
                    iconLabel: 'A',
                  ),
                ),

                gap12,

                _metricRow(
                  _MetricCard(
                    label: tr('temperature'),
                    value: '$temperature °C',
                    icon: Icons.thermostat_rounded,
                  ),
                  _MetricCard(
                    label: tr('power'),
                    value: p4?.totalPowerDisplay ?? '– KW',
                    icon: Icons.power_outlined,
                  ),
                ),

                const SizedBox(height: 20),

                _CellSummaryChart(
                  values: cellValues,
                  minCell: minCell,
                  maxCell: maxCell,
                  title: tr('cell_summary'),
                  minLabel: tr('min_cell'),
                  maxLabel: tr('max_cell'),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        SlideRoute(
                          page: CellsScreen(service: widget.service),
                        ),
                      );
                    },
                    child: Text(tr('view_cell_details')),
                  ),
                ),

                gap16,

                _AlertsCard(
                  title: tr('active_alerts'),
                  noAlerts: tr('no_active_alerts'),
                  normalText: tr('all_systems_normal'),
                ),

                gap16,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BatteryStatusCard extends StatelessWidget {
  final int soc;
  final String capacity;
  final String batteryStatus;
  final String remainingTime;

  const _BatteryStatusCard({
    required this.soc,
    required this.capacity,
    required this.batteryStatus,
    required this.remainingTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _DashboardScreenState.blue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: soc / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$soc%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'SOC',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _info('Battery Status', batteryStatus),
                const Divider(color: Colors.white24),
                _info('Remaining Time', remainingTime),
                const Divider(color: Colors.white24),
                _info('Remaining Capacity', capacity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData? icon;
  final String? iconLabel;
  final String label;
  final String value;
  final String? subtitle;

  const _MetricCard({
    this.icon,
    this.iconLabel,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.transparent,
            child: iconLabel != null
                ? Text(iconLabel!)
                : Icon(icon, color: Colors.grey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) Text(subtitle!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CellSummaryChart extends StatelessWidget {
  final List<double> values;
  final double minCell;
  final double maxCell;
  final String title;
  final String minLabel;
  final String maxLabel;

  const _CellSummaryChart({
    required this.values,
    required this.minCell,
    required this.maxCell,
    required this.title,
    required this.minLabel,
    required this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final diff = (max - min) == 0 ? 1 : (max - min);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$minLabel\n$minCell v'),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final v in values)
                    Container(
                      width: 14,
                      height: 20 + (((v - min) / diff) * 40),
                      decoration: BoxDecoration(
                        color: _DashboardScreenState.green,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$maxLabel\n$maxCell v'),
          ],
        ),
      ],
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final String title;
  final String noAlerts;
  final String normalText;

  const _AlertsCard({
    required this.title,
    required this.noAlerts,
    required this.normalText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  const SizedBox(width: 10),
                  Text(title),
                ],
              ),
              Text(noAlerts),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: _DashboardScreenState.green,
              ),
              const SizedBox(width: 10),
              Text(normalText),
            ],
          ),
        ],
      ),
    );
  }
}