// lib/screens/dashboard_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/screens/cells_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';

const _green = Color(0xFF1B6B3A);
const _blue = Color(0xFF3A6EAC);
const _orange = Color(0xFFD4621A);
const _gap12 = SizedBox(height: 12);
const _gap16 = SizedBox(height: 16);

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

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Disconnect', textAlign: TextAlign.center),
        content: const Text('Are you sure you want to disconnect?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _disconnect();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final dash = svc.latestDashboard;
    final cell = svc.latestCellVoltage;

    // Device Info
    final String deviceName = svc.bleName ?? svc.device?.name ?? 'BMS Device';
    final String swVersion = svc.softwareVersion ?? dash?.softwareVersion ?? '-';
    final String hwVersion = svc.hardwareVersion ?? dash?.hardwareVersion ?? '-';
    final String serialNo = svc.batterySerial ?? dash?.batterySerial ?? '-';
    const String batteryType = 'LiPo';

    // Dashboard Data
    final int soc = dash?.soc ?? 9;
    final String batteryStatus = dash?.batteryStatusLabel ?? 'N/A';
    final bool isCharging = dash?.batteryStatusCode == 0x01;
    final String capacityDisplay = dash?.capacityDisplay ?? '0.0 Ah';
    final String health = dash?.healthLabel ?? 'N/A';

    final String voltageDisplay = dash?.voltageDisplay ?? '0.0 V';
    final String currentDisplay = dash?.currentDisplay ?? '0.0 A';
    final String tempDisplay = dash?.temperatureDisplay ?? '0.0 °C';
    final String powerDisplay = dash?.powerDisplay ?? '0 W';

    final int cellCount = dash?.totalCells ?? cell?.cellTotalCells ?? 0;
    final String cellCountLabel = cellCount.toString();
    final String cyclesDisplay = dash?.chargeCyclesDisplay ?? '0';
    final String avgVoltage = dash?.avgCellVoltageDisplay ?? '0.00 V';
    final String voltDiff = dash?.voltageDiffDisplay ?? '0.00 V';
    final String minVoltage = dash?.minCellVoltageDisplay ?? '0.00 V';
    final String maxVoltage = dash?.maxCellVoltageDisplay ?? '0.00 V';

    final List<double> cellVoltages = cell?.cellVoltages ?? [];
    final int? maxVoltageNo = cell?.cellMaxVoltageNo;
    final int? minVoltageNo = cell?.cellMinVoltageNo;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/dashboard', service: widget.service),
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(deviceName,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // Device Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Software Version', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(swVersion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('Hardware Version', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(hwVersion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Battery Serial No.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(serialNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        const TextSpan(text: 'Battery Type: ', style: TextStyle(color: Colors.grey)),
                        TextSpan(text: batteryType, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _showDisconnectDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('DISCONNECT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Connected', style: TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 8),
              Container(width: 9, height: 9, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
            ],
          ),

          _gap16,

          _BatteryCard(
            soc: soc,
            capacity: capacityDisplay,
            status: batteryStatus,
            isCharging: isCharging,
            health: health,
            healthGood: true,
          ),

          _gap16,

          Row(
            children: [
              Expanded(child: _MetricCard(label: 'Voltage', value: voltageDisplay, iconLabel: 'V')),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(label: 'Current', value: currentDisplay, iconLabel: 'A', badge: isCharging ? 'charging' : null)),
            ],
          ),

          _gap12,

          Row(
            children: [
              Expanded(child: _MetricCard(label: 'Temperature', value: tempDisplay, icon: Icons.thermostat_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(label: 'Power', value: powerDisplay, icon: Icons.power_outlined)),
            ],
          ),

          const SizedBox(height: 24),

          _CellSummary(
            cellCount: cellCount,
            cellCountLabel: cellCountLabel,
            avgVoltage: avgVoltage,
            voltDiff: voltDiff,
            cyclesDisplay: cyclesDisplay,
            minVoltage: minVoltage,
            maxVoltage: maxVoltage,
            cellVoltages: cellVoltages,
            maxVoltageNo: maxVoltageNo,
            minVoltageNo: minVoltageNo,
            onViewMore: () => Navigator.push(context, SlideRoute(page: CellsScreen(service: widget.service))),
          ),

          _gap16,

          _AlertsCard(title: 'Active Alerts', normalText: 'All Systems Normal'),
        ],
      ),
    );
  }
}

// ==================== BATTERY CARD WITH BLINKING SOC ====================
class _BatteryCard extends StatefulWidget {
  final int soc;
  final String capacity, status, health;
  final bool isCharging, healthGood;

  const _BatteryCard({
    required this.soc,
    required this.capacity,
    required this.status,
    required this.isCharging,
    required this.health,
    required this.healthGood,
  });

  @override
  State<_BatteryCard> createState() => _BatteryCardState();
}

class _BatteryCardState extends State<_BatteryCard> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut));
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

  Color get _socColor => widget.soc > 20 ? Colors.green : Colors.red;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (_, child) => Opacity(
                opacity: widget.soc <= 10 ? _blinkAnimation.value : 1.0,
                child: child,
              ),
              child: CustomPaint(
                painter: _SocRingPainter(soc: widget.soc, ringColor: _socColor),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${widget.soc}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('SOC', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Text('Battery Status', style: TextStyle(color: Colors.white70, fontSize: 13)), const Spacer(), Icon(widget.isCharging ? Icons.battery_charging_full : Icons.battery_full, color: Colors.greenAccent)]),
                Text(widget.status, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const Divider(color: Colors.white24, height: 20),
                const Text('Remaining Capacity', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(widget.capacity, style: const TextStyle(color: Colors.white, fontSize: 15)),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  children: [
                    const Text('Health', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Text(widget.health, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Icon(Icons.verified_user_rounded, color: Colors.green, size: 18),
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
  final int soc;
  final Color ringColor;
  _SocRingPainter({required this.soc, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 14) / 2;

    canvas.drawCircle(center, radius, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 12);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.57, 6.28 * (soc / 100), false, Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==================== METRIC CARD ====================
class _MetricCard extends StatelessWidget {
  final String label, value;
  final String? iconLabel;
  final IconData? icon;
  final String? badge;

  const _MetricCard({required this.label, required this.value, this.iconLabel, this.icon, this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.transparent, child: iconLabel != null ? Text(iconLabel!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)) : Icon(icon, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), if (badge != null) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)), child: Text(badge!, style: const TextStyle(fontSize: 11)))]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CELL SUMMARY (Red if < 3.01V + Border) ====================
class _CellSummary extends StatelessWidget {
  final int cellCount;
  final String cellCountLabel, avgVoltage, voltDiff, cyclesDisplay, minVoltage, maxVoltage;
  final List<double> cellVoltages;
  final int? maxVoltageNo, minVoltageNo;
  final VoidCallback? onViewMore;

  const _CellSummary({
    required this.cellCount,
    required this.cellCountLabel,
    required this.avgVoltage,
    required this.voltDiff,
    required this.cyclesDisplay,
    required this.minVoltage,
    required this.maxVoltage,
    required this.cellVoltages,
    this.maxVoltageNo,
    this.minVoltageNo,
    this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    final bool isScrollable = cellCount > 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cell Summary ($cellCountLabel Cells)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            GestureDetector(onTap: onViewMore, child: Row(children: const [Text('View More', style: TextStyle(color: _blue, fontSize: 13)), Icon(Icons.chevron_right, color: _blue, size: 18)])),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Icon(Icons.flash_on_rounded, size: 18, color: _green),
            const SizedBox(width: 6),
            Text('Average Voltage $avgVoltage', style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Icon(Icons.refresh_rounded, size: 18, color: _green),
            const SizedBox(width: 6),
            Text('No of Cycles $cyclesDisplay', style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Voltage Difference $voltDiff', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Min. Cell $minVoltage', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
                  Text('Max. Cell $maxVoltage', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 110,
                child: isScrollable
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(cellVoltages.length, (i) => _buildBar(i, cellVoltages, maxVoltageNo, minVoltageNo)),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          cellVoltages.length,
                          (i) => Expanded(child: _buildBar(i, cellVoltages, maxVoltageNo, minVoltageNo, isExpanded: true)),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(int index, List<double> voltages, int? maxNo, int? minNo, {bool isExpanded = false}) {
    final double v = voltages[index];
    final bool isMax = (index + 1) == maxNo;
    final bool isLow = v < 3.01;
    final double height = 35 + ((v - 3.0) * 75).clamp(0.0, 80.0);

    final Color barColor = isLow ? Colors.red.shade400 : isMax ? _green : _green.withOpacity(0.85);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 4 : 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 9, color: Colors.black54)),
          const SizedBox(height: 4),
          Container(
            width: isExpanded ? null : 16,
            height: height,
            decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 4),
          Text('C${(index + 1).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 9, color: Colors.black45)),
        ],
      ),
    );
  }
}

// ==================== ALERTS CARD ====================
class _AlertsCard extends StatelessWidget {
  final String title, normalText;
  const _AlertsCard({required this.title, required this.normalText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [const Icon(Icons.notifications_none_rounded), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w500))]),
              const Text('–', style: TextStyle(fontSize: 22, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.check_circle_rounded, color: _green), const SizedBox(width: 10), Text(normalText)]),
        ],
      ),
    );
  }
}