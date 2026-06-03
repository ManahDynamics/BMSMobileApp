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
import 'package:bmsmobileapp/services/translation_service.dart';

// Shared theme constants
const _green  = Color(0xFF1B6B3A);
const _blue   = Color(0xFF3A6EAC);
const _orange = Color(0xFFD4621A);
const _gap12  = SizedBox(height: 12);
const _gap16  = SizedBox(height: 16);

class DashboardScreen extends StatefulWidget {
  final BMSBluetoothService service;
  const DashboardScreen({super.key, required this.service});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _cells = const [3.24, 3.28, 3.22, 3.29, 3.25, 3.27, 3.21, 3.30, 3.26, 3.23];

  String tr(String k) => TranslationService.t(k);

  // ── Request device info packets once the service is ready ─────────────────
  // Called inside initState. Sends 4 request packets so the BMS responds with
  // battery serial, software version, hardware version, and SN code.
  // void _requestDeviceInfo() {
  //   widget.service.sendCustom(0x59); // Battery Serial No
  //   widget.service.sendCustom(0x5A); // Software Version
  //   widget.service.sendCustom(0x5B); // Hardware Version
  //   widget.service.sendCustom(0x5C); // SN Code
  // }

  @override
  void initState() {
    super.initState();
    // _requestDeviceInfo(); // Uncomment when request format is ready
  }

  Future<void> _disconnect() async {
    await widget.service.disconnect();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)), (_) => false);
  }

  void _showDialog({
    required String title, required String content,
    required String btnText, required Color color, required VoidCallback onConfirm,
  }) =>
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); onConfirm(); },
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(btnText),
            ),
          ],
        ),
      );

  Future<void> _showMenu(BuildContext ctx) async {
    final btn     = ctx.findRenderObject() as RenderBox;
    final overlay = Navigator.of(ctx).overlay!.context.findRenderObject() as RenderBox;
    final off     = btn.localToGlobal(Offset.zero, ancestor: overlay);

    final result = await showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(overlay.size.width, off.dy + btn.size.height, 8, 0),
      color: Colors.white, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        _menuItem('edit_profile',    Icons.person_outline_rounded, tr('edit_profile')),
        const PopupMenuDivider(height: 1),
        _menuItem('forgot_password', Icons.lock_reset_rounded,     tr('forget_password')),
        const PopupMenuDivider(height: 1),
        _menuItem('logout',          Icons.logout_rounded,         tr('logout'), color: Colors.red),
      ],
    );

    final routes = {
      'edit_profile': const EditProfileScreen(),
      'forgot_password': const ForgotPasswordScreen(),
    };
    if (routes.containsKey(result)) {
      Navigator.push(ctx, SlideRoute(page: routes[result]!));
    } else if (result == 'logout') {
      _showDialog(
        title: tr('logout'), content: tr('logout_confirmation'),
        btnText: tr('logout'), color: _blue,
        onConfirm: () => Navigator.pushAndRemoveUntil(
            ctx, SlideRoute(page: const LoginScreen()), (_) => false),
      );
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text, {Color color = Colors.black87}) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color)),
        ]),
      );

  Widget _metricRow(Widget a, Widget b) => IntrinsicHeight(
        child: Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/dashboard', service: widget.service),
      appBar: AppBar(
        backgroundColor: _green, elevation: 0, centerTitle: true,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Text(tr('dashboard'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          Builder(builder: (ctx) => IconButton(
            onPressed: () => _showMenu(ctx),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.more_vert, color: Colors.white),
            ),
          )),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (_, _) {
          final svc = widget.service;
          final p4  = svc.latestPacket4;

          // Device info — live from service, falls back to '–' while loading
          final deviceName = svc.batterySerial   ?? '–';
          final swVersion  = svc.softwareVersion ?? '–';
          final hwVersion  = svc.hardwareVersion ?? '–';
          final sn         = svc.snCode          ?? '–';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Device Header ──────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.battery_4_bar_rounded, color: Colors.black54, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(deviceName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  for (final e in [
                    'Software Version: $swVersion',
                    'Hardware Version: $hwVersion',
                    'SN Code: $sn',
                  ])
                    Text(e, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(tr('connected'),
                        style: const TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                  ]),
                ])),
                ElevatedButton(
                  onPressed: () => _showDialog(
                    title: tr('disconnect'), content: tr('disconnect_confirmation'),
                    btnText: tr('disconnect'), color: _orange, onConfirm: _disconnect,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: Text(tr('disconnect')),
                ),
              ]),

              _gap16,

              // ── Battery Card ───────────────────────────────────────────
              _BatteryCard(
                soc: p4?.soc ?? 0,
                capacity: p4?.capacityDisplay ?? '– Ah',
                status: 'Charging..',
                health: 'Good',
              ),

              _gap16,

              _metricRow(
                _MetricCard(label: tr('voltage'), value: p4?.voltageDisplay ?? '– V', iconLabel: 'V'),
                _MetricCard(label: tr('current'), value: p4?.currentDisplay ?? '– A', iconLabel: 'A',
                    showChargingBadge: true, showRedDot: true),
              ),
              _gap12,
              _metricRow(
                _MetricCard(label: tr('temperature'), value: '32.0 °C', icon: Icons.thermostat_rounded),
                _MetricCard(label: tr('power'), value: p4?.totalPowerDisplay ?? '– KW', icon: Icons.power_outlined),
              ),

              const SizedBox(height: 20),

              // ── Cell Summary ───────────────────────────────────────────
              _CellSummary(
                values: _cells,
                minCell: 3.215, maxCell: 3.298,
                cellCount: 18, avgVoltage: 3.2, voltDiff: 0.083, cycles: 100005,
                title: tr('cell_summary'), minLabel: tr('min_cell'), maxLabel: tr('max_cell'),
                onViewMore: () => Navigator.push(context,
                    SlideRoute(page: CellsScreen(service: widget.service))),
              ),

              _gap16,

              // ── Alerts Card ────────────────────────────────────────────
              _AlertsCard(title: tr('active_alerts'), normalText: tr('all_systems_normal')),

              _gap16,
            ]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Battery Card
// ─────────────────────────────────────────────────────────────────────────────
class _BatteryCard extends StatelessWidget {
  final int soc;
  final String capacity, status, health;
  const _BatteryCard({required this.soc, required this.capacity, required this.status, required this.health});

  Color get _socColor {
    if (soc <= 10) return Colors.red;
    if (soc <= 20) return Colors.orange;
    return Colors.green;
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(value,  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
        ])),
      ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        SizedBox(width: 100, height: 100,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: soc / 100, strokeWidth: 10, backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(_socColor),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$soc%', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const Text('SOC', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('Battery Status', status,
              trailing: const Icon(Icons.battery_charging_full_rounded, color: Colors.greenAccent, size: 20)),
          const Divider(color: Colors.white24, height: 12),
          _infoRow('Remaining Capacity', capacity),
          const Divider(color: Colors.white24, height: 12),
          _infoRow('Health', health,
              trailing: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
              )),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Card
// ─────────────────────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData? icon;
  final String? iconLabel;
  final String label, value;
  final bool showChargingBadge, showRedDot;

  const _MetricCard({
    this.icon, this.iconLabel,
    required this.label, required this.value,
    this.showChargingBadge = false, this.showRedDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: Colors.transparent,
          child: iconLabel != null ? Text(iconLabel!) : Icon(icon, color: Colors.grey),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            if (showChargingBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20)),
                child: const Text('Charging', style: TextStyle(fontSize: 10, color: Colors.black54)),
              ),
            ],
          ]),
          Row(children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (showRedDot) ...[
              const SizedBox(width: 6),
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ],
          ]),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell Summary
// ─────────────────────────────────────────────────────────────────────────────
class _CellSummary extends StatelessWidget {
  final List<double> values;
  final double minCell, maxCell, avgVoltage, voltDiff;
  final int cellCount, cycles;
  final String title, minLabel, maxLabel;
  final VoidCallback? onViewMore;

  const _CellSummary({
    required this.values, required this.minCell, required this.maxCell,
    required this.cellCount, required this.avgVoltage, required this.voltDiff,
    required this.cycles, required this.title, required this.minLabel,
    required this.maxLabel, this.onViewMore,
  });

  Widget _statRow(IconData icon, String label, String value, {String? r1, String? r2}) =>
      Row(children: [
        Icon(icon, size: 16, color: _green), const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)), const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        if (r1 != null && r2 != null) ...[
          const Spacer(),
          Icon(Icons.refresh_rounded, size: 16, color: _green), const SizedBox(width: 4),
          Text(r1, style: const TextStyle(fontSize: 12, color: Colors.black54)), const SizedBox(width: 6),
          Text(r2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ]);

  Widget _cellLabel(String label, String v, {CrossAxisAlignment align = CrossAxisAlignment.start}) =>
      Column(crossAxisAlignment: align, mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(v,     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]);

  @override
  Widget build(BuildContext context) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final diff = (maxV - minV) == 0 ? 1.0 : maxV - minV;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$title ($cellCount Cells)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: onViewMore,
          child: const Text('View More >', style: TextStyle(fontSize: 13, color: _blue)),
        ),
      ]),
      const SizedBox(height: 10),
      _statRow(Icons.flash_on_rounded, 'Average Voltage', '$avgVoltage v'),
      const SizedBox(height: 6),
      _statRow(Icons.flash_on_rounded, 'Voltage Difference', '${voltDiff.toStringAsFixed(2)} v',
          r1: 'No of Cycles', r2: '$cycles'),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _cellLabel(minLabel, '$minCell v'),
        const SizedBox(width: 12),
        Expanded(child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final v in values)
              Container(
                width: 14, height: 20 + (((v - minV) / diff) * 40),
                decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(3)),
              ),
          ],
        )),
        const SizedBox(width: 12),
        _cellLabel(maxLabel, '$maxCell v', align: CrossAxisAlignment.end),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alerts Card
// ─────────────────────────────────────────────────────────────────────────────
class _AlertsCard extends StatelessWidget {
  final String title, normalText;
  const _AlertsCard({required this.title, required this.normalText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.notifications_none_rounded), const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          ]),
          const Text('–', style: TextStyle(fontSize: 20, color: Colors.black54, fontWeight: FontWeight.w300)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.check_circle_rounded, color: _green),
          const SizedBox(width: 10),
          Text(normalText),
        ]),
      ]),
    );
  }
}