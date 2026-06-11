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
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); onConfirm(); },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
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
        title: tr('logout'), content: tr('logout_confirmation'),
        btnText: tr('logout'), color: _blue,
        onConfirm: () => Navigator.pushAndRemoveUntil(
            ctx, SlideRoute(page: const LoginScreen()), (_) => false),
      );
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text,
      {Color color = Colors.black87}) =>
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
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
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
          final dash = svc.latestDashboard;
          final cell = svc.latestCellVoltage;

          final String deviceName  = svc.bleName ?? '-';
          final String swVersion   = svc.softwareVersion ?? '-';
          final String hwVersion   = svc.hardwareVersion ?? '-';
          final String serialNo    = svc.batterySerial ?? '-';
          const String batteryType = 'LiPo';

          final int    soc             = dash?.soc ?? 0;
          final String batteryStatus   = dash?.batteryStatusLabel ?? '–';
          final bool   isCharging      = dash?.batteryStatusCode == 0x01;
          final bool   isLoadConnected = dash?.batteryStatusCode == 0x03;
          final String capacityDisplay = dash?.capacityDisplay ?? '– Ah';
          final String health          = dash?.healthLabel ?? '–';
          final bool   healthGood      = dash?.healthCode == 0x01;
          final String voltageDisplay  = dash?.voltageDisplay ?? '– V';
          final String currentDisplay  = dash?.currentDisplay ?? '– A';
          final bool   isDischarging   = (dash?.totalCurrent ?? 0) > 0;
          final String tempDisplay     = dash?.temperatureDisplay ?? '– °C';
          final String powerDisplay    = dash?.powerDisplay ?? '– W';

          // Cell Summary — Bytes 72–82
          final String cellCountLabel = dash?.totalCells != null ? '${dash!.totalCells}' : '–';
          final String cyclesDisplay  = dash?.chargeCyclesDisplay ?? '–';
          final String avgVoltage     = dash?.avgCellVoltageDisplay ?? '– V';
          final String voltDiff       = dash?.voltageDiffDisplay ?? '– V';
          final String maxVoltage     = dash?.maxCellVoltageDisplay ?? '– V';
          final String minVoltage     = dash?.minCellVoltageDisplay ?? '– V';
          final double? minVoltRaw    = dash?.minCellVoltage;
          final double? maxVoltRaw    = dash?.maxCellVoltage;

          // Per-cell voltages from 0x53 — for the scrollable bar graph
          final List<double>? cellVoltages = cell?.cellVoltages;
          final int? maxVoltageNo          = cell?.cellMaxVoltageNo;
          final int? minVoltageNo          = cell?.cellMinVoltageNo;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [

              // Device Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(deviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('Battery Serial Number', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(serialNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        const Text('Battery Type', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(batteryType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Text(tr('software_version'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(swVersion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Text(tr('hardware_version'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(hwVersion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Text(tr('connected'), style: const TextStyle(
                              color: _green, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8,
                              decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                        ]),
                      ]),
                    ),
                    ElevatedButton(
                      onPressed: () => _showDialog(
                        title: tr('disconnect'), content: tr('disconnect_confirmation'),
                        btnText: tr('disconnect'), color: _orange, onConfirm: _disconnect,
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _orange, foregroundColor: Colors.white, elevation: 0),
                      child: Text(tr('disconnect')),
                    ),
                  ],
                ),
              ),

              _gap16,

              _BatteryCard(
                soc: soc, capacity: capacityDisplay, status: batteryStatus,
                isCharging: isCharging, health: health, healthGood: healthGood,
              ),

              _gap16,

              _metricRow(
                _MetricCard(label: tr('voltage'), value: voltageDisplay, iconLabel: 'V'),
                _MetricCard(
                  label: tr('current'), value: currentDisplay, iconLabel: 'A',
                  chargingBadgeText: isCharging ? tr('charging') : isLoadConnected ? tr('load') : null,
                  showRedDot: isDischarging,
                ),
              ),

              _gap12,

              _metricRow(
                _MetricCard(label: tr('temperature'), value: tempDisplay, icon: Icons.thermostat_rounded),
                _MetricCard(label: tr('power'), value: powerDisplay, icon: Icons.power_outlined),
              ),

              const SizedBox(height: 20),

              // Cell Summary with real per-cell scrollable graph
              _CellSummary(
                cellCountLabel: cellCountLabel,
                avgVoltage:     avgVoltage,
                voltDiff:       voltDiff,
                cyclesDisplay:  cyclesDisplay,
                minVoltage:     minVoltage,
                maxVoltage:     maxVoltage,
                minVoltRaw:     minVoltRaw,
                maxVoltRaw:     maxVoltRaw,
                cellVoltages:   cellVoltages,
                maxVoltageNo:   maxVoltageNo,
                minVoltageNo:   minVoltageNo,
                title:          tr('cell_summary'),
                minLabel:       tr('min_cell'),
                maxLabel:       tr('max_cell'),
                onViewMore: () => Navigator.push(context,
                    SlideRoute(page: CellsScreen(service: widget.service))),
              ),

              _gap16,

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
// SOC colour rules:
//   > 20 %  → green  (solid)
//   ≤ 20 %  → red    (solid)
//   ≤ 10 %  → red    (blinking — repeating fade in/out)
// ─────────────────────────────────────────────────────────────────────────────
class _BatteryCard extends StatefulWidget {
  final int soc; final String capacity, status, health;
  final bool isCharging, healthGood;
  const _BatteryCard({required this.soc, required this.capacity, required this.status,
      required this.isCharging, required this.health, required this.healthGood});

  @override
  State<_BatteryCard> createState() => _BatteryCardState();
}

class _BatteryCardState extends State<_BatteryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  late Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _blinkAnim = Tween<double>(begin: 1.0, end: 0.15).animate(
      CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut),
    );
    _updateBlink();
  }

  @override
  void didUpdateWidget(_BatteryCard old) {
    super.didUpdateWidget(old);
    if (old.soc != widget.soc) _updateBlink();
  }

  void _updateBlink() {
    if (widget.soc <= 10) {
      if (!_blinkCtrl.isAnimating) _blinkCtrl.repeat(reverse: true);
    } else {
      _blinkCtrl.stop();
      _blinkCtrl.value = 1.0; // fully visible
    }
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  // > 20% → green | ≤ 20% or ≤ 10% → red
  Color get _socColor => widget.soc > 20 ? Colors.green : Colors.red;

  Color get _healthColor => widget.healthGood ? Colors.green : Colors.red;

  Widget _infoRow(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        SizedBox(width: 100, height: 100,
          child: Stack(alignment: Alignment.center, children: [
            // Blink wrapper — opacity animates only when SOC ≤ 10%
            AnimatedBuilder(
              animation: _blinkAnim,
              builder: (_, child) => Opacity(
                opacity: widget.soc <= 10 ? _blinkAnim.value : 1.0,
                child: child,
              ),
              child: CircularProgressIndicator(
                value: widget.soc / 100,
                strokeWidth: 10,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(_socColor),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${widget.soc}%', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const Text('SOC', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _infoRow('Battery Status', widget.status)),
            Icon(widget.isCharging ? Icons.battery_charging_full_rounded : Icons.battery_full_rounded,
                color: Colors.greenAccent, size: 20),
          ]),
          const Divider(color: Colors.white24, height: 12),
          _infoRow('Remaining Capacity', widget.capacity),
          const Divider(color: Colors.white24, height: 12),
          Row(children: [
            Expanded(child: _infoRow('Health', widget.health)),
            Container(padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: _healthColor, shape: BoxShape.circle),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14)),
          ]),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Card
// ─────────────────────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData? icon; final String? iconLabel;
  final String label, value;
  final String? chargingBadgeText; final bool showRedDot;
  const _MetricCard({this.icon, this.iconLabel, required this.label, required this.value,
      this.chargingBadgeText, this.showRedDot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: Colors.transparent,
          child: iconLabel != null
              ? Text(iconLabel!, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
              : Icon(icon, color: Colors.grey),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            if (chargingBadgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20)),
                child: Text(chargingBadgeText!, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ),
            ],
          ]),
          Row(children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (showRedDot) ...[
              const SizedBox(width: 6),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ],
          ]),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell Summary — Bytes 72–82 + real per-cell scrollable graph from 0x53
// ─────────────────────────────────────────────────────────────────────────────
class _CellSummary extends StatelessWidget {
  final String  cellCountLabel, avgVoltage, voltDiff, cyclesDisplay;
  final String  minVoltage, maxVoltage;
  final double? minVoltRaw, maxVoltRaw;
  // Real per-cell data from 0x53 response
  final List<double>? cellVoltages;
  final int?    maxVoltageNo, minVoltageNo;
  final String  title, minLabel, maxLabel;
  final VoidCallback? onViewMore;

  const _CellSummary({
    required this.cellCountLabel, required this.avgVoltage,
    required this.voltDiff,       required this.cyclesDisplay,
    required this.minVoltage,     required this.maxVoltage,
    required this.minVoltRaw,     required this.maxVoltRaw,
    required this.cellVoltages,
    required this.maxVoltageNo,   required this.minVoltageNo,
    required this.title,          required this.minLabel,
    required this.maxLabel,       this.onViewMore,
  });

  Widget _statRow(IconData icon, String label, String value,
      {IconData? trailIcon, String? trailLabel, String? trailValue}) =>
      Row(children: [
        Icon(icon, size: 16, color: _green),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        if (trailLabel != null && trailValue != null) ...[
          const Spacer(),
          Icon(trailIcon ?? Icons.refresh_rounded, size: 16, color: _green),
          const SizedBox(width: 4),
          Text(trailLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 6),
          Text(trailValue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ]);

  // ── Scrollable per-cell bar graph ─────────────────────────────────────────
  // Uses real voltages from 0x53 when available (6–24 cells).
  // Falls back to interpolated preview bars until first cell packet arrives.
  Widget _buildGraph() {
    final voltages = cellVoltages;

    if (voltages == null || voltages.isEmpty) {
      return _buildFallback();
    }

    final double minV  = voltages.reduce((a, b) => a < b ? a : b);
    final double maxV  = voltages.reduce((a, b) => a > b ? a : b);
    final double range = (maxV - minV).abs();

    // Bar dimensions — tuned to match the screenshot style
    const double barW    = 14.0;
    const double barGap  = 5.0;
    const double maxBarH    = 42.0;
    const double minBarH    = 8.0;
    const double labelH     = 14.0; // voltage text above bar
    const double cellLabelH = 14.0; // cell number text below bar (C01…C24)
    const double totalH     = labelH + maxBarH + cellLabelH + 4.0;

    return SizedBox(
      height: totalH,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: barGap),
            ...List.generate(voltages.length, (i) {
              final double v     = voltages[i];
              final double norm  = range > 0 ? (v - minV) / range : 1.0;
              final double barH  = minBarH + norm * (maxBarH - minBarH);
              final bool   isMax = (i + 1) == maxVoltageNo;
              final bool   isMin = (i + 1) == minVoltageNo;

              final Color barColor = isMax
                  ? _green
                  : isMin
                      ? Colors.red.shade400
                      : _green.withOpacity(0.72);

              return Padding(
                padding: const EdgeInsets.only(right: barGap),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Voltage label above bar
                    Text(
                      v.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 7, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 1),
                    // Bar
                    Container(
                      width: barW,
                      height: barH,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Cell number below bar — C01, C02 … C24
                    Text(
                      'C${(i + 1).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 7, color: Colors.black45, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(width: barGap),
          ],
        ),
      ),
    );
  }

  // Fallback interpolated bars shown before 0x53 packet arrives
  Widget _buildFallback() {
    if (minVoltRaw == null || maxVoltRaw == null) return const SizedBox(height: 58);
    const int    barCount = 10;
    const double maxBarH  = 42.0;
    final double range    = (maxVoltRaw! - minVoltRaw!).abs();
    return SizedBox(
      height: 58,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          final double norm = range == 0 ? 1.0 : i / (barCount - 1).toDouble();
          final double h    = 8 + norm * maxBarH;
          return Container(
            width: 8, height: h,
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$title ($cellCountLabel Cells)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: onViewMore,
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Text('View More', style: TextStyle(fontSize: 13, color: _blue)),
            SizedBox(width: 2),
            Icon(Icons.chevron_right, color: _blue, size: 16),
          ]),
        ),
      ]),

      const SizedBox(height: 10),
      _statRow(Icons.flash_on_rounded, 'Average Voltage', avgVoltage),
      const SizedBox(height: 6),
      _statRow(Icons.flash_on_rounded, 'Voltage Difference', voltDiff,
          trailIcon: Icons.refresh_rounded,
          trailLabel: 'No of Cycles', trailValue: cyclesDisplay),
      const SizedBox(height: 12),

      // Min label  |  scrollable graph  |  Max label
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Min Volt (left)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(minLabel, style: const TextStyle(fontSize: 10, color: Colors.black45)),
            Text(minVoltage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(width: 8),

        // Graph — expands to fill available width, scrollable inside
        Expanded(child: _buildGraph()),

        const SizedBox(width: 8),
        // Max Volt (right)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(maxLabel, style: const TextStyle(fontSize: 10, color: Colors.black45)),
            Text(maxVoltage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
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
            const Icon(Icons.notifications_none_rounded),
            const SizedBox(width: 10),
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