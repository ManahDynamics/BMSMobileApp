// lib/screens/dashboard_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';
import '../../../modules/scanner/screens/BMS_scanner_screen.dart';
import '../../../modules/cells/screens/cell_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';

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
  final LocalAuthDB _localAuthDB = LocalAuthDB();

  // Tracks the last map we cached so we don't write on every rebuild
  Map<String, dynamic>? _lastCachedDash;
  Map<String, dynamic>? _lastCachedCell;

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

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width : 72, height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFFE0F2F1), shape: BoxShape.circle),
              child: const Icon(Icons.bluetooth, size: 40, color: Color(0xFF00796B)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Are you sure you want to disconnect the device?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(ctx); _disconnect(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAC5624),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Yes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Cache BMS data whenever the service notifies ──────────────────────────

  /// Converts dashboard model to a plain map and caches it.
  Future<void> _cacheDashboardIfNew() async {
    final dash = widget.service.latestDashboard;
    if (dash == null) return;

    // Build a comparable snapshot map from the dashboard model fields
    final map = <String, dynamic>{
      'soc'               : dash.soc,
      'batteryStatusCode' : dash.batteryStatusCode,
      'batteryStatusLabel': dash.batteryStatusLabel,
      'batteryType'       : dash.batteryType,
      'batterySerial'     : dash.batterySerial,
      'capacityDisplay'   : dash.capacityDisplay,
      'healthLabel'       : dash.healthLabel,
      'healthCode'        : dash.healthCode,
      'voltageDisplay'    : dash.voltageDisplay,
      'currentDisplay'    : dash.currentDisplay,
      'temperatureDisplay': dash.temperatureDisplay,
      'powerDisplay'      : dash.powerDisplay,
      'chargeCyclesDisplay': dash.chargeCyclesDisplay,
      'totalCells'        : dash.totalCells,
      'avgCellVoltageDisplay' : dash.avgCellVoltageDisplay,
      'voltageDiffDisplay'    : dash.voltageDiffDisplay,
      'minCellVoltageDisplay' : dash.minCellVoltageDisplay,
      'maxCellVoltageDisplay' : dash.maxCellVoltageDisplay,
      'temperature'       : dash.temperature,
      'voltageDiff'       : dash.voltageDiff,
    };

    // Only write if something changed
    if (map.toString() != _lastCachedDash.toString()) {
      _lastCachedDash = map;
      await _localAuthDB.saveDashboard(map);
    }
  }

  /// Converts cell voltage model to a plain map and caches it.
  Future<void> _cacheCellVoltageIfNew() async {
    final cell = widget.service.latestCellVoltage;
    if (cell == null) return;

    final map = <String, dynamic>{
      'cellVoltages'       : cell.cellVoltages,
      'cellTotalCells'     : cell.cellTotalCells,
      'cellMaxVoltage'     : cell.cellMaxVoltage,
      'cellMaxVoltageNo'   : cell.cellMaxVoltageNo,
      'cellMinVoltage'     : cell.cellMinVoltage,
      'cellMinVoltageNo'   : cell.cellMinVoltageNo,
      'cellAvgVoltage'     : cell.cellAvgVoltage,
      'cellBalancing'      : cell.cellBalancing,
      'cellBalancingActive': cell.cellBalancingActive,
    };

    if (map.toString() != _lastCachedCell.toString()) {
      _lastCachedCell = map;
      await _localAuthDB.saveCellVoltage(map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;

    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        // ── Cache in background whenever data arrives ──────────────────
        _cacheDashboardIfNew();
        _cacheCellVoltageIfNew();

        final dash = svc.latestDashboard;
        final cell = svc.latestCellVoltage;

        // ── Device Info ────────────────────────────────────────────────
        final String deviceName  = svc.bleName ?? svc.device?.name ?? 'BMS Device';
        final String batteryType = svc.batteryType ?? dash?.batteryType ?? '-';
        final String serialNo    = svc.batterySerial ?? dash?.batterySerial ?? '-';

        // ── Dashboard Data ─────────────────────────────────────────────
        final int    soc              = dash?.soc ?? 0;
        final String batteryStatus    = dash?.batteryStatusLabel ?? 'N/A';
        final bool   isCharging       = dash?.batteryStatusCode == 0x01;
        final String capacityDisplay  = dash?.capacityDisplay ?? '0.0 Ah';
        final String health           = dash?.healthLabel ?? 'N/A';
        final bool   healthGood       = dash?.healthCode == 0x01;

        final String voltageDisplay = dash?.voltageDisplay    ?? '0.0 V';
        final String currentDisplay = dash?.currentDisplay    ?? '0.0 A';
        final String tempDisplay    = dash?.temperatureDisplay ?? '0 °C';
        final String powerDisplay   = dash?.powerDisplay      ?? '0 Kw';
        final String cyclesDisplay  = dash?.chargeCyclesDisplay ?? '0';

        final int    cellCount   = dash?.totalCells ?? cell?.cellTotalCells ?? 0;
        final String avgVoltage  = dash?.avgCellVoltageDisplay   ?? '0.00 v';
        final String voltDiff    = dash?.voltageDiffDisplay      ?? '0.00 v';
        final String minVoltage  = dash?.minCellVoltageDisplay   ?? '0.000 V';
        final String maxVoltage  = dash?.maxCellVoltageDisplay   ?? '0.000 V';

        final List<double> cellVoltages = cell?.cellVoltages ?? [];
        final int? maxVoltageNo         = cell?.cellMaxVoltageNo;
        final int? minVoltageNo         = cell?.cellMinVoltageNo;

        // ── Build alerts from live BMS data ────────────────────────────
        List<_AlertItem> buildAlerts(
          double? temp,
          int? statusCode,
          int soc, [
          double? voltageDiff,
        ]) {
          final items = <_AlertItem>[];
          if (temp != null && temp > 45) {
            items.add(_AlertItem(title: 'Over Temperature', time: _nowTime()));
          }
          if (soc <= 10) {
            items.add(_AlertItem(title: 'Low Battery', time: _nowTime()));
          }
          if (temp != null && temp < 0) {
            items.add(_AlertItem(title: 'Under Temperature', time: _nowTime()));
          }
          if (voltageDiff != null && voltageDiff > 0.1) {
            items.add(_AlertItem(title: 'Cell Imbalance', time: _nowTime()));
          }
          return items;
        }

        final alerts = dash == null
            ? <_AlertItem>[]
            : buildAlerts(
                dash.temperature,
                dash.batteryStatusCode,
                soc,
                dash.voltageDiff,
              );

        // ── Cache alerts whenever they change ──────────────────────────
        if (alerts.isNotEmpty) {
          _localAuthDB.saveAlerts(
            alerts
                .map((a) => {'title': a.title, 'time': a.time})
                .toList(),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          drawer: AppDrawer(activeRoute: '/dashboard', service: widget.service),
          appBar: AppBar(
            backgroundColor: _green,
            elevation      : 0,
            centerTitle    : true,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon    : const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Column(
              children: [
                const Text('Dashboard',
                    style: TextStyle(
                        color     : Colors.white,
                        fontSize  : 18,
                        fontWeight: FontWeight.w500)),
                if (svc.bleName != null)
                  Text(svc.bleName!,
                      style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon     : const Icon(Icons.notifications_none_rounded,
                        color: Colors.white),
                    onPressed: () {},
                  ),
                  if (alerts.isNotEmpty)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding   : const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Text('${alerts.length}',
                            style: const TextStyle(
                                color     : Colors.white,
                                fontSize  : 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                icon : const Icon(Icons.more_vert, color: Colors.white),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onSelected: (value) {
                  if (value == 'logout') _showDisconnectDialog();
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit_profile',   child: Text('Edit Profile')),
                  PopupMenuItem(value: 'forget_password', child: Text('Forget Password')),
                  PopupMenuItem(value: 'logout',          child: Text('Logout')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _DeviceHeader(
                batteryType : batteryType,
                serialNo    : serialNo,
                onDisconnect: _showDisconnectDialog,
              ),

              if (svc.isBleNameLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Fetching device name…',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                )
              else if (svc.bleNameError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(svc.bleNameError!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.red.shade700)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color : const Color.fromARGB(255, 239, 242, 240),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _green, width: 2.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Connected',
                            style: TextStyle(
                                color     : _green,
                                fontWeight: FontWeight.w600,
                                fontSize  : 13)),
                        const SizedBox(width: 6),
                        Container(
                          width : 8, height: 8,
                          decoration: const BoxDecoration(
                              color: _green, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showDisconnectDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Disconnect',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              _gap16,

              if (svc.isDashboardLoading)
                const _LoadingSection(text: 'Loading dashboard data…')
              else if (svc.dashboardError != null)
                _ErrorSection(message: svc.dashboardError!)
              else if (svc.bleNameError != null)
                const _ErrorSection(
                    message:
                        'Dashboard data unavailable — BLE Name step failed.')
              else
                _BatteryCard(
                  soc        : soc,
                  statusCode : dash?.batteryStatusCode ?? 0x02,
                  capacity   : capacityDisplay,
                  status     : batteryStatus,
                  isCharging : isCharging,
                  health     : health,
                  healthGood : healthGood,
                  cycles     : cyclesDisplay,
                ),

              _gap16,

              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                        label: 'Voltage', value: voltageDisplay, iconLabel: 'V')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label     : 'Current',
                      value     : currentDisplay,
                      iconLabel : isCharging ? null : 'A',
                      isCharging: isCharging,
                    )),
                ],
              ),

              _gap12,

              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                        label: 'Temperature',
                        value: tempDisplay,
                        icon : Icons.thermostat_rounded)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                        label: 'Power',
                        value: powerDisplay,
                        icon : Icons.power_outlined)),
                ],
              ),

              const SizedBox(height: 20),

              if (svc.isCellVoltageLoading)
                const _LoadingSection(text: 'Loading cell voltage data…')
              else if (svc.cellVoltageError != null)
                _ErrorSection(message: svc.cellVoltageError!)
              else if (svc.dashboardError != null || svc.bleNameError != null)
                const _ErrorSection(
                    message: 'Cell voltage data unavailable.')
              else
                _CellSummary(
                  cellCount   : cellCount,
                  avgVoltage  : avgVoltage,
                  voltDiff    : voltDiff,
                  minVoltage  : minVoltage,
                  maxVoltage  : maxVoltage,
                  cellVoltages: cellVoltages,
                  maxVoltageNo: maxVoltageNo,
                  minVoltageNo: minVoltageNo,
                  onViewMore  : () => Navigator.push(context,
                      SlideRoute(
                          page: CellsScreen(service: widget.service))),
                ),

              _gap16,
              _AlertsCard(alerts: alerts),
            ],
          ),
        );
      },
    );
  }

  String _nowTime() {
    final now    = DateTime.now();
    final h      = now.hour > 12
        ? now.hour - 12
        : now.hour == 0 ? 12 : now.hour;
    final m      = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }
}

// ============================================================================
// All supporting widgets below are UNCHANGED from your original
// ============================================================================

class _DeviceHeader extends StatelessWidget {
  final String batteryType, serialNo;
  final VoidCallback onDisconnect;

  const _DeviceHeader({
    required this.batteryType,
    required this.serialNo,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Battery Type: $batteryType',
                  style: const TextStyle(
                      fontSize  : 17,
                      fontWeight: FontWeight.w600,
                      color     : Color(0xFF424242))),
              const SizedBox(height: 4),
              Text('Battery Serial No: $serialNo',
                  style: TextStyle(
                      fontSize  : 13,
                      fontWeight: FontWeight.w400,
                      color     : Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
}

class _BatteryCard extends StatefulWidget {
  final int    soc, statusCode;
  final String capacity, status, health, cycles;
  final bool   isCharging, healthGood;

  const _BatteryCard({
    required this.soc,
    required this.statusCode,
    required this.capacity,
    required this.status,
    required this.isCharging,
    required this.health,
    required this.healthGood,
    required this.cycles,
  });

  @override
  State<_BatteryCard> createState() => _BatteryCardState();
}

class _BatteryCardState extends State<_BatteryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double>   _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
        vsync   : this,
        duration: const Duration(milliseconds: 600));
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
        CurvedAnimation(
            parent: _blinkController, curve: Curves.easeInOut));
    _updateBlink();
  }

  void _updateBlink() {
    if (widget.soc <= 10) {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      _blinkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _BatteryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soc != widget.soc) _updateBlink();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Color get _socColor =>
      widget.soc > 20 ? Colors.green : Colors.red;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding    : const EdgeInsets.all(16),
      decoration : BoxDecoration(
          color       : const Color(0xFF3A6EAC),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
            width : 110, height: 110,
            child : AnimatedBuilder(
              animation: _blinkAnimation,
              builder  : (_, child) => Opacity(
                opacity: widget.soc <= 10 ? _blinkAnimation.value : 1.0,
                child  : child,
              ),
              child: CustomPaint(
                painter: _SocRingPainter(
                    soc: widget.soc, ringColor: _socColor),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${widget.soc}%',
                          style: const TextStyle(
                              fontSize  : 28,
                              fontWeight: FontWeight.bold,
                              color     : Colors.white)),
                      const Text('SOC',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Battery Status',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const Spacer(),
                    SizedBox(
                      width : 28, height: 28,
                      child : widget.statusCode == 0x01
                          ? Image.asset('assets/images/charging_icn_gif.gif',
                              fit: BoxFit.contain)
                          : widget.statusCode == 0x02
                              ? Image.asset('assets/images/idle-battery.png',
                                  fit: BoxFit.contain)
                              : Image.asset('assets/images/load_connect.png',
                                  fit: BoxFit.contain),
                    ),
                  ],
                ),
                Text(widget.status,
                    style: const TextStyle(
                        color     : Colors.white,
                        fontSize  : 15,
                        fontWeight: FontWeight.w600)),
                const Divider(color: Colors.white24, height: 14),
                const Text('Remaining Capacity',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(widget.capacity,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
                const Divider(color: Colors.white24, height: 14),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cycles',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(widget.cycles,
                            style: const TextStyle(
                                color     : Colors.white,
                                fontSize  : 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Spacer(),
                    Container(width: 1, color: Colors.white24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Health',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Row(
                          children: [
                            Text(widget.health,
                                style: const TextStyle(
                                    color     : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize  : 13)),
                            const SizedBox(width: 4),
                            Icon(
                              widget.healthGood
                                  ? Icons.verified_user_rounded
                                  : Icons.warning_rounded,
                              color: widget.healthGood
                                  ? Colors.green
                                  : Colors.orange,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocRingPainter extends CustomPainter {
  final int   soc;
  final Color ringColor;
  _SocRingPainter({required this.soc, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 14) / 2;
    canvas.drawCircle(
        center, radius,
        Paint()
          ..color      = Colors.white24
          ..style      = PaintingStyle.stroke
          ..strokeWidth= 10);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57, 6.28 * (soc / 100), false,
      Paint()
        ..color      = ringColor
        ..style      = PaintingStyle.stroke
        ..strokeWidth= 10
        ..strokeCap  = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MetricCard extends StatelessWidget {
  final String  label, value;
  final String? iconLabel;
  final IconData? icon;
  final String?   badge;
  final bool      isCharging;

  const _MetricCard({
    required this.label,
    required this.value,
    this.iconLabel,
    this.icon,
    this.badge,
    this.isCharging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
          color       : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius         : 18,
            backgroundColor: Colors.transparent,
            child: isCharging
                ? const Icon(Icons.bolt_rounded,
                    color: Colors.green, size: 26)
                : iconLabel != null
                    ? Text(iconLabel!,
                        style: const TextStyle(
                            fontSize  : 18,
                            fontWeight: FontWeight.bold,
                            color     : Colors.grey))
                    : Icon(icon, color: Colors.grey, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(value,
                          style: const TextStyle(
                              fontSize  : 17,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isCharging) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color : Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                size : 10,
                                color: Colors.green.shade600),
                            const SizedBox(width: 2),
                            Text('Charging',
                                style: TextStyle(
                                    fontSize  : 10,
                                    color     : Colors.green.shade700,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ] else if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color       : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CellSummary extends StatelessWidget {
  final int          cellCount;
  final String       avgVoltage, voltDiff, minVoltage, maxVoltage;
  final List<double> cellVoltages;
  final int?         maxVoltageNo, minVoltageNo;
  final VoidCallback? onViewMore;

  const _CellSummary({
    required this.cellCount,
    required this.avgVoltage,
    required this.voltDiff,
    required this.minVoltage,
    required this.maxVoltage,
    required this.cellVoltages,
    this.maxVoltageNo,
    this.minVoltageNo,
    this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cell Summary ($cellCount Cells)',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: onViewMore,
              child: const Row(
                children: [
                  Text('View More',
                      style: TextStyle(color: Color(0xFF3A6EAC), fontSize: 13)),
                  Icon(Icons.chevron_right,
                      color: Color(0xFF3A6EAC), size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Average Voltage',
                style: TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(width: 4),
            Text(avgVoltage,
                style: const TextStyle(
                    fontSize  : 13,
                    fontWeight: FontWeight.w700,
                    color     : Colors.black87)),
            const Spacer(),
            const Text('Volt Difference',
                style: TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(width: 4),
            Text(voltDiff,
                style: const TextStyle(
                    fontSize  : 13,
                    fontWeight: FontWeight.w700,
                    color     : Colors.black87)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          child: Column(
            children: [
              SizedBox(
                height: 130,
                width : double.infinity,
                child : Row(
                  children: [
                    const SizedBox(
                        width: 18,
                        child: Icon(Icons.chevron_left,
                            size: 18, color: Colors.grey)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          height: 150,
                          child : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(
                              cellVoltages.length,
                              (i) => _buildBar(i, cellVoltages,
                                  maxVoltageNo, minVoltageNo),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                        width: 18,
                        child: Icon(Icons.chevron_right,
                            size: 18, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Min. Volt $minVoltage',
                      style: const TextStyle(
                          fontSize  : 11,
                          color     : Colors.black54,
                          fontWeight: FontWeight.w500)),
                  Text('Max. Volt $maxVoltage',
                      style: const TextStyle(
                          fontSize  : 11,
                          color     : Colors.black54,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(int index, List<double> voltages, int? maxNo, int? minNo) {
    final double v      = voltages[index];
    final bool   isMax  = (index + 1) == maxNo;
    final bool   isMin  = (index + 1) == minNo;
    final double height =
        45 + ((v - 3.0) * 60).clamp(0.0, 40.0);
    final Color color   = isMax
        ? const Color(0xFF0B6645)
        : isMin
            ? Colors.orange
            : const Color(0xFF0B6645);

    return SizedBox(
      width : 28,
      child : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(v.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize  : 8,
                  color     : Colors.black54,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Container(
            width : 20, height: height,
            decoration: BoxDecoration(
                color       : color,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 20,
            child: Text(
              'C${(index + 1).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize  : 8,
                  fontWeight: FontWeight.w600,
                  color     : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  final String text;
  const _LoadingSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
          color       : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              strokeWidth: 2.5, color: Color(0xFF1B6B3A)),
          const SizedBox(height: 12),
          Text(text,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final String message;
  const _ErrorSection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color       : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }
}

class _AlertItem {
  final String title, time;
  const _AlertItem({required this.title, required this.time});
}

class _AlertsCard extends StatelessWidget {
  final List<_AlertItem> alerts;
  const _AlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_none_rounded, size: 20),
            const SizedBox(width: 8),
            const Text('Active Alerts',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(width: 6),
            if (alerts.isNotEmpty)
              Container(
                padding   : const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color : Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  alerts.length.toString().padLeft(2, '0'),
                  style: TextStyle(
                      fontSize  : 11,
                      color     : Colors.red.shade700,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (alerts.isEmpty)
          Container(
            padding   : const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color       : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF1B6B3A), size: 20),
                const SizedBox(width: 10),
                const Text('No Active Alerts',
                    style: TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color       : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: Colors.grey.shade200),
              boxShadow   : [
                BoxShadow(
                    color    : Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset   : const Offset(0, 2))
              ],
            ),
            child: Column(
              children: alerts.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width : 36, height: 36,
                            decoration: BoxDecoration(
                                color      : Colors.grey.shade100,
                                shape      : BoxShape.circle),
                            child: Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade600, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.title,
                                    style: const TextStyle(
                                        fontSize  : 13,
                                        fontWeight: FontWeight.w600,
                                        color     : Colors.black87)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(a.time,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color   : Colors.grey[500])),
                              const SizedBox(height: 4),
                              Icon(Icons.chevron_right,
                                  color: Colors.grey[400], size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (i < alerts.length - 1)
                      Divider(
                        height   : 1,
                        thickness: 1,
                        color    : Colors.grey.shade100,
                        indent   : 14,
                        endIndent: 14,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}