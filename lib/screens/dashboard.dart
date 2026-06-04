// lib/screens/dashboard_screen.dart
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

// ── Theme constants ───────────────────────────────────────────────────────────
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
  String tr(String k) => TranslationService.t(k);

  Future<void> _disconnect() async {
    await widget.service.disconnect();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)),
      (_) => false,
    );
  }

  void _showDialog({
    required String title,
    required String content,
    required String btnText,
    required Color color,
    required VoidCallback onConfirm,
  }) =>
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'),
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); onConfirm(); },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
      position: RelativeRect.fromLTRB(
          overlay.size.width, off.dy + btn.size.height, 8, 0),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
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
      'edit_profile':    const EditProfileScreen(),
      'forgot_password': const ForgotPasswordScreen(),
    };
    if (routes.containsKey(result)) {
      Navigator.push(ctx, SlideRoute(page: routes[result]!));
    } else if (result == 'logout') {
      _showDialog(
        title: tr('logout'),
        content: tr('logout_confirmation'),
        btnText: tr('logout'),
        color: _blue,
        onConfirm: () => Navigator.pushAndRemoveUntil(
            ctx, SlideRoute(page: const LoginScreen()), (_) => false),
      );
    }
  }

  PopupMenuItem<String> _menuItem(
    String value, IconData icon, String text, {
    Color color = Colors.black87,
  }) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color)),
        ]),
      );

  Widget _metricRow(Widget a, Widget b) => IntrinsicHeight(
        child: Row(children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/dashboard', service: widget.service),
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        centerTitle: true,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Text(tr('dashboard'),
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          Builder(builder: (ctx) => IconButton(
            onPressed: () => _showMenu(ctx),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.more_vert, color: Colors.white),
            ),
          )),
        ],
      ),

      body: ListenableBuilder(
        listenable: widget.service,
        builder: (_, _) {
          final svc  = widget.service;
          // Primary source: 86-byte dashboard (0x52).
          // Falls back to legacy packet4 (0x51) if dashboard not yet received.
          final dash = svc.latestDashboard ?? svc.latestPacket4;

          // ── Byte 3–16  : Battery Serial (device header) ───────────────────
          // ── Byte 17–30 : Software Version ────────────────────────────────
          // ── Byte 31–44 : Hardware Version ────────────────────────────────
          // ── Byte 45–58 : SN Code ─────────────────────────────────────────
          final String deviceName = svc.batterySerial   ?? '–';
          final String swVersion  = svc.softwareVersion ?? '–';
          final String hwVersion  = svc.hardwareVersion ?? '–';
          final String snCode     = svc.snCode          ?? '–';

          // ── Byte 59  : SOC ────────────────────────────────────────────────
          final int soc = dash?.soc ?? 0;

          // ── Byte 60  : Battery Status ─────────────────────────────────────
          // 0x01 = Charging | 0x02 = Idle | 0x03 = Load Connected
          final String batteryStatus    = dash?.batteryStatusLabel ?? '–';
          final bool   isCharging       = dash?.batteryStatusCode == 0x01;
          final bool   isLoadConnected  = dash?.batteryStatusCode == 0x03;

          // ── Bytes 61–62 : Remaining Capacity ──────────────────────────────
          final String capacityDisplay = dash?.capacityDisplay ?? '– Ah';

          // ── Byte 63  : Health ─────────────────────────────────────────────
          // 0x01 = Good | 0x02 = Poor
          final String health     = dash?.healthLabel ?? '–';
          final bool   healthGood = dash?.healthCode == 0x01;

          // ── Bytes 64–65 : Total Voltage ───────────────────────────────────
          final String voltageDisplay = dash?.voltageDisplay ?? '– V';

          // ── Bytes 66–67 : Total Current ───────────────────────────────────
          // Positive = discharging, negative = charging
          final String currentDisplay = dash?.currentDisplay ?? '– A';
          // Show red dot only when discharging (positive current)
          final bool isDischarging = (dash?.totalCurrent ?? 0) > 0;

          // ── Bytes 68–69 : Temperature ─────────────────────────────────────
          final String tempDisplay = dash?.temperatureDisplay ?? '– °C';

          // ── Bytes 70–71 : Power in KW (stored as W internally) ────────────
          final String powerDisplay = dash?.powerDisplay ?? '– W';

          // ── Byte 72 : Total Cells ─────────────────────────────────────────
          final String cellCountLabel =
              dash?.totalCells != null ? '${dash!.totalCells}' : '–';

          // ── Bytes 73–74 : Charge/Discharge Cycles ─────────────────────────
          final String cyclesDisplay = dash?.chargeCyclesDisplay ?? '–';

          // ── Bytes 75–76 : Avg Cell Voltage ────────────────────────────────
          final String avgVoltage = dash?.avgCellVoltageDisplay ?? '– V';

          // ── Bytes 77–78 : Voltage Difference ─────────────────────────────
          final String voltDiff = dash?.voltageDiffDisplay ?? '– V';

          // ── Bytes 79–80 : Max Cell Voltage ────────────────────────────────
          final String maxVoltage    = dash?.maxCellVoltageDisplay ?? '– V';
          final double? maxVoltRaw   = dash?.maxCellVoltage;

          // ── Bytes 81–82 : Min Cell Voltage ────────────────────────────────
          final String minVoltage    = dash?.minCellVoltageDisplay ?? '– V';
          final double? minVoltRaw   = dash?.minCellVoltage;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [

              // ── Device Header (Bytes 3–58) ────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.battery_4_bar_rounded,
                      color: Colors.black54, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Battery Serial No — Bytes 3–16
                    Text(deviceName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    // Software Version — Bytes 17–30
                    Text('Software Version: $swVersion',
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    // Hardware Version — Bytes 31–44
                    Text('Hardware Version: $hwVersion',
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    // SN Code — Bytes 45–58
                    Text('SN Code: $snCode',
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(tr('connected'),
                          style: const TextStyle(
                              color: _green,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: _green, shape: BoxShape.circle)),
                    ]),
                  ],
                )),
                ElevatedButton(
                  onPressed: () => _showDialog(
                    title: tr('disconnect'),
                    content: tr('disconnect_confirmation'),
                    btnText: tr('disconnect'),
                    color: _orange,
                    onConfirm: _disconnect,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: Text(tr('disconnect')),
                ),
              ]),

              _gap16,

              // ── Battery Card (Bytes 59, 60, 61–62, 63) ───────────────────
              _BatteryCard(
                soc: soc,                     // Byte 59
                capacity: capacityDisplay,    // Bytes 61–62
                status: batteryStatus,        // Byte 60 decoded
                isCharging: isCharging,       // Byte 60 == 0x01
                health: health,               // Byte 63 decoded
                healthGood: healthGood,       // Byte 63 == 0x01
              ),

              _gap16,

              // ── Row 1: Voltage (64–65) / Current (66–67) ─────────────────
              _metricRow(
                _MetricCard(
                  label: tr('voltage'),
                  value: voltageDisplay,        // Bytes 64–65
                  iconLabel: 'V',
                ),
                _MetricCard(
                  label: tr('current'),
                  value: currentDisplay,        // Bytes 66–67
                  iconLabel: 'A',
                  // Badge shown only when battery status is Charging or Load Connected
                  chargingBadgeText: isCharging
                      ? 'Charging'
                      : isLoadConnected
                          ? 'Load'
                          : null,
                  // Red dot only when discharging (positive current = drain)
                  showRedDot: isDischarging,
                ),
              ),

              _gap12,

              // ── Row 2: Temperature (68–69) / Power (70–71) ───────────────
              _metricRow(
                _MetricCard(
                  label: tr('temperature'),
                  value: tempDisplay,           // Bytes 68–69
                  icon: Icons.thermostat_rounded,
                ),
                _MetricCard(
                  label: tr('power'),
                  value: powerDisplay,          // Bytes 70–71
                  icon: Icons.power_outlined,
                ),
              ),

              const SizedBox(height: 20),

              // ── Cell Summary (Bytes 72–82) ────────────────────────────────
              _CellSummary(
                cellCountLabel: cellCountLabel, // Byte 72
                avgVoltage:     avgVoltage,     // Bytes 75–76
                voltDiff:       voltDiff,       // Bytes 77–78
                cyclesDisplay:  cyclesDisplay,  // Bytes 73–74
                minVoltage:     minVoltage,     // Bytes 81–82
                maxVoltage:     maxVoltage,     // Bytes 79–80
                minVoltRaw:     minVoltRaw,
                maxVoltRaw:     maxVoltRaw,
                title:          tr('cell_summary'),
                minLabel:       tr('min_cell'),
                maxLabel:       tr('max_cell'),
                onViewMore: () => Navigator.push(context,
                    SlideRoute(page: CellsScreen(service: widget.service))),
              ),

              _gap16,

              // ── Alerts ───────────────────────────────────────────────────
              _AlertsCard(
                title:      tr('active_alerts'),
                normalText: tr('all_systems_normal'),
              ),

              _gap16,
            ]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Battery Card — Byte 59 (SOC) | 60 (Status) | 61–62 (Capacity) | 63 (Health)
// ─────────────────────────────────────────────────────────────────────────────
class _BatteryCard extends StatelessWidget {
  final int    soc;
  final String capacity;
  final String status;
  final bool   isCharging;
  final String health;
  final bool   healthGood;

  const _BatteryCard({
    required this.soc,
    required this.capacity,
    required this.status,
    required this.isCharging,
    required this.health,
    required this.healthGood,
  });

  Color get _socColor {
    if (soc <= 10) return Colors.red;
    if (soc <= 20) return Colors.orange;
    return Colors.green;
  }

  // Health shield color: green = Good (0x01), red = Poor (0x02)
  Color get _healthColor => healthGood ? Colors.green : Colors.red;

  Widget _infoRow(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _blue, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        // SOC ring — Byte 59
        SizedBox(width: 100, height: 100,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: soc / 100,
              strokeWidth: 10,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(_socColor),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$soc%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const Text('SOC',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Battery Status — Byte 60
            Row(children: [
              Expanded(child: _infoRow('Battery Status', status)),
              // Icon changes with charge state
              Icon(
                isCharging
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_full_rounded,
                color: Colors.greenAccent,
                size: 20,
              ),
            ]),
            const Divider(color: Colors.white24, height: 12),
            // Remaining Capacity — Bytes 61–62
            _infoRow('Remaining Capacity', capacity),
            const Divider(color: Colors.white24, height: 12),
            // Health — Byte 63
            Row(children: [
              Expanded(child: _infoRow('Health', health)),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: _healthColor, shape: BoxShape.circle),
                child: const Icon(Icons.verified_user_rounded,
                    color: Colors.white, size: 14),
              ),
            ]),
          ],
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Card  — generic card for Voltage / Current / Temp / Power
// ─────────────────────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData? icon;
  final String?   iconLabel;
  final String    label;
  final String    value;
  /// Non-null → show a small pill badge with this text (e.g. "Charging", "Load")
  final String?   chargingBadgeText;
  /// True → show red dot next to value (discharging indicator)
  final bool      showRedDot;

  const _MetricCard({
    this.icon,
    this.iconLabel,
    required this.label,
    required this.value,
    this.chargingBadgeText,
    this.showRedDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: Colors.transparent,
          child: iconLabel != null
              ? Text(iconLabel!,
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold))
              : Icon(icon, color: Colors.grey),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row — with optional badge
            Row(children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              if (chargingBadgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(chargingBadgeText!,
                      style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ),
              ],
            ]),
            // Value row — with optional red dot
            Row(children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              if (showRedDot) ...[
                const SizedBox(width: 6),
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle)),
              ],
            ]),
          ],
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell Summary — Bytes 72–82 all dynamic from packet
// ─────────────────────────────────────────────────────────────────────────────
class _CellSummary extends StatelessWidget {
  final String cellCountLabel; // Byte 72
  final String avgVoltage;     // Bytes 75–76
  final String voltDiff;       // Bytes 77–78
  final String cyclesDisplay;  // Bytes 73–74
  final String minVoltage;     // Bytes 81–82
  final String maxVoltage;     // Bytes 79–80
  final double? minVoltRaw;    // for bar chart scale
  final double? maxVoltRaw;    // for bar chart scale
  final String title, minLabel, maxLabel;
  final VoidCallback? onViewMore;

  const _CellSummary({
    required this.cellCountLabel,
    required this.avgVoltage,
    required this.voltDiff,
    required this.cyclesDisplay,
    required this.minVoltage,
    required this.maxVoltage,
    required this.minVoltRaw,
    required this.maxVoltRaw,
    required this.title,
    required this.minLabel,
    required this.maxLabel,
    this.onViewMore,
  });

  Widget _statRow(
    IconData icon,
    String label,
    String value, {
    IconData? trailIcon,
    String? trailLabel,
    String? trailValue,
  }) =>
      Row(children: [
        Icon(icon, size: 16, color: _green),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        if (trailLabel != null && trailValue != null) ...[
          const Spacer(),
          Icon(trailIcon ?? Icons.refresh_rounded, size: 16, color: _green),
          const SizedBox(width: 4),
          Text(trailLabel,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 6),
          Text(trailValue,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ]);

  Widget _cellLabel(String label, String v,
      {CrossAxisAlignment align = CrossAxisAlignment.start}) =>
      Column(
        crossAxisAlignment: align,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(v,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    // Build a simple 2-bar visual from min/max when data is available.
    // Full per-cell bars require the individual cell voltages from CellsScreen.
    final bool hasData = minVoltRaw != null && maxVoltRaw != null;
  

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // Byte 72 — Total Cells count
        Text('$title ($cellCountLabel Cells)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: onViewMore,
          child: const Text('View More >',
              style: TextStyle(fontSize: 13, color: _blue)),
        ),
      ]),
      const SizedBox(height: 10),
      // Bytes 75–76 — Average Voltage
      _statRow(Icons.flash_on_rounded, 'Average Voltage', avgVoltage),
      const SizedBox(height: 6),
      // Bytes 77–78 — Voltage Difference  |  Bytes 73–74 — Cycles
      _statRow(
        Icons.flash_on_rounded, 'Voltage Difference', voltDiff,
        trailIcon:  Icons.refresh_rounded,
        trailLabel: 'No of Cycles',
        trailValue: cyclesDisplay,
      ),
      const SizedBox(height: 14),
      // Min / bar / Max row
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Bytes 81–82 — Min Cell Voltage
        _cellLabel(minLabel, minVoltage),
        const SizedBox(width: 12),
       Expanded(
  child: hasData
      ? LayoutBuilder(
          builder: (context, constraints) {
            const int barCount = 10;
            const double maxBarHeight = 35;

            final double range =
                (maxVoltRaw! - minVoltRaw!).abs();

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(barCount, (index) {
                double value;

                if (range == 0) {
                  value = maxVoltRaw!;
                } else {
                  value = minVoltRaw! +
                      ((maxVoltRaw! - minVoltRaw!) *
                          index /
                          (barCount - 1));
                }

                final double normalized =
                    range == 0
                        ? 1
                        : (value - minVoltRaw!) / range;

                final double height =
                    12 + (normalized * maxBarHeight);

                return Container(
                  width: 8,
                  height: height,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            );
          },
        )
      : const SizedBox.shrink(),
),
        const SizedBox(width: 12),
        // Bytes 79–80 — Max Cell Voltage
        _cellLabel(maxLabel, maxVoltage, align: CrossAxisAlignment.end),
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
      decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.notifications_none_rounded),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ]),
          const Text('–',
              style: TextStyle(
                  fontSize: 20,
                  color: Colors.black54,
                  fontWeight: FontWeight.w300)),
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