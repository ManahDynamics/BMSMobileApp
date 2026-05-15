// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';

class CellsScreen extends StatefulWidget {
  const CellsScreen({super.key});

  @override
  State<CellsScreen> createState() => _CellsScreenState();
}

class _CellsScreenState extends State<CellsScreen> {
  final String deviceName = 'BMS_001';
  final int totalCells = 16;
  final double maxCellVoltage = 3.298;
  final int maxCellNo = 4;
  final double minCellVoltage = 3.180;
  final int minCellNo = 12;
  final String balancingStatus = 'Active';

  String _sortBy = 'Cell No.';

  final List<Map<String, dynamic>> _cells = [
    {'no': 1, 'voltage': 3.298},
    {'no': 2, 'voltage': 3.157},
    {'no': 3, 'voltage': 3.235},
    {'no': 4, 'voltage': 3.246},
    {'no': 5, 'voltage': 3.125},
    {'no': 6, 'voltage': 3.122},
    {'no': 7, 'voltage': 3.045},
    {'no': 8, 'voltage': 3.012},
    {'no': 9, 'voltage': 3.298},
    {'no': 10, 'voltage': 3.238},
    {'no': 11, 'voltage': 3.265},
    {'no': 12, 'voltage': 3.180},
    {'no': 13, 'voltage': 3.290},
    {'no': 14, 'voltage': 3.201},
    {'no': 15, 'voltage': 3.155},
    {'no': 16, 'voltage': 3.278},
  ];

  List<Map<String, dynamic>> get _sortedCells {
    final sorted = List<Map<String, dynamic>>.from(_cells);
    if (_sortBy == 'Voltage') {
      sorted.sort((a, b) =>
          (b['voltage'] as double).compareTo(a['voltage'] as double));
    } else {
      sorted.sort((a, b) => (a['no'] as int).compareTo(b['no'] as int));
    }
    return sorted;
  }

  String _getHealth(double v) {
    if (v >= 3.2) return 'Healthy';
    if (v >= 3.1) return 'Medium';
    return 'Low';
  }

  Color _getHealthColor(double v) {
    if (v >= 3.2) return const Color(0xFF1B6B3A);
    if (v >= 3.1) return const Color(0xFFB8860B);
    return const Color(0xFFD4621A);
  }

  IconData _getHealthIcon(double v) {
    if (v >= 3.2) return Icons.verified_user_outlined;
    if (v >= 3.1) return Icons.info_outline_rounded;
    return Icons.warning_amber_rounded;
  }

  int _getFilledBars(double v) {
    if (v >= 3.28) return 8;
    if (v >= 3.25) return 7;
    if (v >= 3.22) return 6;
    if (v >= 3.19) return 5;
    if (v >= 3.16) return 4;
    if (v >= 3.13) return 3;
    if (v >= 3.10) return 2;
    if (v >= 3.05) return 1;
    return 0;
  }

  Color _getBarColor(double v) {
    if (v >= 3.2) return const Color(0xFF1B6B3A);
    if (v >= 3.1) return const Color(0xFFB8860B);
    return Colors.grey.shade400;
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disconnect',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to disconnect from $deviceName?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
  }

  // ── Sort dropdown using showMenu (like kebab) ──────────────────────────────
  void _showSortMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final Offset buttonOffset =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonOffset.dx,
      buttonOffset.dy + buttonSize.height + 4,
      overlay.size.width - buttonOffset.dx - buttonSize.width,
      0,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 6,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'Cell No.',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cell No.', style: TextStyle(fontSize: 14)),
              if (_sortBy == 'Cell No.')
                const Icon(Icons.check, color: Color(0xFF1B6B3A), size: 18),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'Voltage',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Voltage', style: TextStyle(fontSize: 14)),
              if (_sortBy == 'Voltage')
                const Icon(Icons.check, color: Color(0xFF1B6B3A), size: 18),
            ],
          ),
        ),
      ],
    );

    if (result != null) {
      setState(() => _sortBy = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(activeRoute: '/cells'),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CELL DETAILS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Device header ────────────────────────────────────────
            _buildDeviceHeader(),
            const SizedBox(height: 16),

            // ── Summary cards (equal height via IntrinsicHeight) ─────
            _buildSummaryCards(),
            const SizedBox(height: 16),

            // ── Cell voltages header ─────────────────────────────────
            _buildTableHeader(),
            const SizedBox(height: 4),

            // ── Scrollable cell list ─────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _sortedCells.length,
                    itemBuilder: (context, index) {
                      final cell = _sortedCells[index];
                      final isLast = index == _sortedCells.length - 1;
                      return _buildCellRow(
                          cell['no'] as int, cell['voltage'] as double, isLast);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Device header ────────────────────────────────────────────────────────
  Widget _buildDeviceHeader() {
    return Row(
      children: [
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deviceName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 3),
            Row(children: [
              const Text('Connected',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1B6B3A),
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF1B6B3A), shape: BoxShape.circle)),
            ]),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _showDisconnectDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4621A),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('DISCONNECT',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  )),
        ),
      ],
    );
  }

  // ── Summary cards — IntrinsicHeight ensures equal height ──────────────────
  Widget _buildSummaryCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total Cells
          Expanded(
            child: _buildSummaryCard(
              topWidget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.battery_full, color: Colors.white, size: 16),
                    SizedBox(width: 2),
                    Icon(Icons.battery_full, color: Colors.white, size: 16),
                    SizedBox(width: 2),
                    Icon(Icons.battery_full, color: Colors.white, size: 16),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.battery_full, color: Colors.white, size: 16),
                    SizedBox(width: 2),
                    Icon(Icons.battery_full, color: Colors.white, size: 16),
                    SizedBox(width: 2),
                    Icon(Icons.battery_full, color: Colors.white, size: 16),
                  ]),
                ],
              ),
              label: 'Total Cells',
              value: '$totalCells',
            ),
          ),
          const SizedBox(width: 4),

          // Max Cell
          Expanded(
            child: _buildSummaryCard(
              topWidget: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Center(
                  child: Text('V',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              label: 'Max. Cell',
              value: '$maxCellVoltage V',
              sub: 'Cell ${maxCellNo.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(width: 4),

          // Min Cell
          Expanded(
            child: _buildSummaryCard(
              topWidget: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Center(
                  child: Text('V',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              label: 'Min. Cell',
              value: '$minCellVoltage V',
              sub: 'Cell ${minCellNo.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(width: 4),

          // Balancing
          Expanded(
            child: _buildSummaryCard(
              topWidget: const Icon(Icons.balance_rounded,
                  color: Colors.white, size: 26),
              label: 'Balancing',
              value: balancingStatus,
              valueSize: 15,
              bottomWidget: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required Widget topWidget,
    required String label,
    required String value,
    String? sub,
    double valueSize = 13,
    Widget? bottomWidget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A6EAC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          topWidget,
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
          if (bottomWidget != null) ...[
            const SizedBox(height: 4),
            bottomWidget,
          ],
        ],
      ),
    );
  }

  // ── Table header with sort dropdown ───────────────────────────────────────
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Cell Voltages',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          Row(
            children: [
              const Text('Sort by: ',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => _showSortMenu(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCCCCCC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_sortBy,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cell row ───────────────────────────────────────────────────────────────
  Widget _buildCellRow(int no, double voltage, bool isLast) {
    final health = _getHealth(voltage);
    final healthColor = _getHealthColor(voltage);
    final healthIcon = _getHealthIcon(voltage);
    final filled = _getFilledBars(voltage);
    final barColor = _getBarColor(voltage);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // Cell No.
              SizedBox(
                width: 56,
                child: Text(
                  'Cell ${no.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
              // Voltage
              SizedBox(
                width: 56,
                child: Text(
                  '${voltage.toStringAsFixed(3)} V',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(width: 4),
              // 8-segment bar
              Row(
                children: List.generate(8, (i) => Container(
                  width: 11,
                  height: 15,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: i < filled ? barColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
              ),
              const Spacer(),
              // Health
              Icon(healthIcon, color: healthColor, size: 17),
              const SizedBox(width: 4),
              Text(health,
                  style: TextStyle(
                      fontSize: 13,
                      color: healthColor,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}