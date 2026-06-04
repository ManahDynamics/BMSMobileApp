// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/screens/bluetooth_device_scan_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';

enum SortType { cellNo, voltage }

class CellData {
  final int no;
  final double voltage;
  final bool balancingActive;

  const CellData({
    required this.no,
    required this.voltage,
    this.balancingActive = false,
  });
}

class CellsScreen extends StatefulWidget {
  final BMSBluetoothService service;
  const CellsScreen({super.key, required this.service});

  @override
  State<CellsScreen> createState() => _CellsScreenState();
}

class _CellsScreenState extends State<CellsScreen> {
  static const primaryGreen  = Color(0xFF1B6B3A);
  static const warningOrange = Color(0xFFD4621A);
  static const mediumYellow  = Color(0xFFB8860B);
  static const cardBlue      = Color(0xFF3A6EAC);
  static const lightBg       = Color(0xFFF5F5F5);

  SortType _sortBy = SortType.cellNo;
  late List<CellData> _sortedCells;

  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onChanged);
    widget.service.addListener(_onChanged);
    _sortCells();
    // Start polling cell voltages every 5s — stops automatically in dispose()
    widget.service.startCellVoltagePolling();
  }

  void _onChanged() {
    if (mounted) {
      setState(() => _sortCells());
    }
  }

  @override
  void dispose() {
    // Stop cell voltage polling when leaving the screen
    widget.service.stopCellVoltagePolling();
    TranslationService.instance.removeListener(_onChanged);
    widget.service.removeListener(_onChanged);
    super.dispose();
  }

  // ── Build cell list from latest BLE packet ─────────────────────────────────
  List<CellData> _buildCells() {
    final cv = widget.service.latestCellVoltage;
    if (cv == null ||
        cv.cellVoltages == null ||
        cv.cellVoltages!.isEmpty) {
      return [];
    }

    final voltages  = cv.cellVoltages!;
    final balancing = cv.cellBalancing ?? [];

    return List.generate(voltages.length, (i) {
      return CellData(
        no: i + 1,
        voltage: voltages[i],
        balancingActive: i < balancing.length ? balancing[i] : false,
      );
    });
  }

  void _sortCells() {
    final cells = _buildCells();
    _sortedCells = [...cells]
      ..sort((a, b) => _sortBy == SortType.voltage
          ? b.voltage.compareTo(a.voltage)
          : a.no.compareTo(b.no));
  }

  // ── Summary values from cell voltage packet ────────────────────────────────
  String get _deviceName {
    return widget.service.batterySerial ?? 'BMS_001';
  }

  int get _totalCells {
    return widget.service.latestCellVoltage?.cellTotalCells ??
        widget.service.latestDashboard?.totalCells ??
        0;
  }

  double? get _maxVoltage =>
      widget.service.latestCellVoltage?.cellMaxVoltage;

  int? get _maxVoltageNo =>
      widget.service.latestCellVoltage?.cellMaxVoltageNo;

  double? get _minVoltage =>
      widget.service.latestCellVoltage?.cellMinVoltage;

  int? get _minVoltageNo =>
      widget.service.latestCellVoltage?.cellMinVoltageNo;

  double? get _avgVoltage =>
      widget.service.latestCellVoltage?.cellAvgVoltage;

  bool get _balancingActive =>
      widget.service.latestCellVoltage?.cellBalancingActive ?? false;

  // ── Bar / status helpers ───────────────────────────────────────────────────
  int _bars(double v) {
    const levels = [3.28, 3.25, 3.22, 3.19, 3.16, 3.13, 3.10, 3.05];
    return levels.where((e) => v >= e).length;
  }

  ({String text, Color color, IconData icon, int bars}) _cellStatus(double v) {
    if (v >= 3.2) {
      return (
        text: tr('healthy'),
        color: primaryGreen,
        icon: Icons.verified_user_outlined,
        bars: _bars(v),
      );
    }
    if (v >= 3.1) {
      return (
        text: tr('medium'),
        color: mediumYellow,
        icon: Icons.info_outline_rounded,
        bars: _bars(v),
      );
    }
    return (
      text: tr('low'),
      color: Colors.grey.shade400,
      icon: Icons.warning_amber_rounded,
      bars: _bars(v),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleDisconnect() async {
    await widget.service.disconnect();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: BluetoothDeviceScanPage(service: widget.service)),
      (route) => false,
    );
  }

  void _showDisconnectDialog() => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(
            tr('disconnect'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '${tr('disconnect_confirmation_from')} $_deviceName?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'),
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handleDisconnect();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: warningOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(tr('disconnect')),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // SORT MENU
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _showSortMenu(BuildContext context) async {
    final button  = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final offset  = button.localToGlobal(Offset.zero, ancestor: overlay);

    final result = await showMenu<SortType>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height + 4,
        overlay.size.width - offset.dx - button.size.width,
        0,
      ),
      items: [
        PopupMenuItem(
          value: SortType.cellNo,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('cell_no')),
              if (_sortBy == SortType.cellNo)
                const Icon(Icons.check, color: primaryGreen, size: 18),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: SortType.voltage,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('voltage')),
              if (_sortBy == SortType.voltage)
                const Icon(Icons.check, color: primaryGreen, size: 18),
            ],
          ),
        ),
      ],
    );

    if (result != null && result != _sortBy) {
      setState(() {
        _sortBy = result;
        _sortCells();
      });
    }
  }

  String get _sortLabel =>
      tr(_sortBy == SortType.cellNo ? 'cell_no' : 'voltage');

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY CARD WIDGET
  // ─────────────────────────────────────────────────────────────────────────
  Widget _summaryCard({
    required Widget top,
    required String label,
    required String value,
    String? sub,
    Widget? bottom,
    double size = 13,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: cardBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            top,
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
            if (bottom != null) ...[
              const SizedBox(height: 4),
              bottom,
            ],
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasData = _sortedCells.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/cells', service: widget.service),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        title: Text(
          tr('cell_details'),
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
          children: [
            // ── Device header row ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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
                    Text(_deviceName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          tr('connected'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: primaryGreen, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _showDisconnectDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warningOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(tr('disconnect'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Summary cards ───────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  // Total cells
                  Expanded(
                    child: _summaryCard(
                      top: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Wrap(spacing: 2, children: [
                            Icon(Icons.battery_full,
                                color: Colors.white, size: 16),
                            Icon(Icons.battery_full,
                                color: Colors.white, size: 16),
                            Icon(Icons.battery_full,
                                color: Colors.white, size: 16),
                          ]),
                          SizedBox(height: 2),
                          Wrap(spacing: 2, children: [
                            Icon(Icons.battery_full,
                                color: Colors.white, size: 16),
                            Icon(Icons.battery_full,
                                color: Colors.white, size: 16),
                            Icon(Icons.battery_full,
                                color: Colors.white, size: 16),
                          ]),
                        ],
                      ),
                      label: tr('total_cells'),
                      value: _totalCells > 0 ? '$_totalCells' : '–',
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Max voltage
                  Expanded(
                    child: _summaryCard(
                      top: _vIcon(),
                      label: tr('max_cell'),
                      value: _maxVoltage != null
                          ? '${_maxVoltage!.toStringAsFixed(3)} V'
                          : '– V',
                      sub: _maxVoltageNo != null
                          ? 'Cell ${_maxVoltageNo.toString().padLeft(2, '0')}'
                          : '–',
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Min voltage
                  Expanded(
                    child: _summaryCard(
                      top: _vIcon(),
                      label: tr('min_cell'),
                      value: _minVoltage != null
                          ? '${_minVoltage!.toStringAsFixed(3)} V'
                          : '– V',
                      sub: _minVoltageNo != null
                          ? 'Cell ${_minVoltageNo.toString().padLeft(2, '0')}'
                          : '–',
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Avg voltage
                  Expanded(
                    child: _summaryCard(
                      top: _vIcon(),
                      label: tr('avg_voltage'),
                      value: _avgVoltage != null
                          ? '${_avgVoltage!.toStringAsFixed(3)} V'
                          : '– V',
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Balancing status
                  Expanded(
                    child: _summaryCard(
                      top: const Icon(Icons.balance_rounded,
                          color: Colors.white, size: 26),
                      label: tr('balancing'),
                      value: widget.service.latestCellVoltage != null
                          ? (_balancingActive ? 'Active' : 'Inactive')
                          : '–',
                      size: 13,
                      bottom: const Icon(Icons.bar_chart_rounded,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Cell voltages header ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: lightBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('cell_voltages'),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                  ),
                  Row(
                    children: [
                      Text('${tr('sort_by')}: '),
                      GestureDetector(
                        onTap: () => _showSortMenu(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFCCCCCC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_sortLabel),
                              const SizedBox(width: 4),
                              const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Cell list ───────────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: lightBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: hasData
                    ? ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _sortedCells.length,
                        itemBuilder: (context, index) {
                          final cell = _sortedCells[index];
                          final s    = _cellStatus(cell.voltage);

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                                child: Row(
                                  children: [
                                    // Cell number
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        'Cell ${cell.no.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    // Voltage
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        '${cell.voltage.toStringAsFixed(3)} V',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Bar chart
                                    Row(
                                      children: List.generate(
                                        8,
                                        (i) => Container(
                                          width: 11,
                                          height: 15,
                                          margin: const EdgeInsets.only(
                                              right: 2),
                                          decoration: BoxDecoration(
                                            color: i < s.bars
                                                ? s.color
                                                : Colors.grey.shade300,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Status icon + label
                                    Icon(s.icon, color: s.color, size: 17),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.text,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: s.color,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    // ── Balancing badge "B" ─────────────
                                    if (cell.balancingActive) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'B',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      // Reserve same space so rows don't shift
                                      const SizedBox(width: 26),
                                    ],
                                  ],
                                ),
                              ),
                              if (index != _sortedCells.length - 1)
                                const Divider(
                                    height: 1, indent: 16, endIndent: 16),
                            ],
                          );
                        },
                      )
                    // ── Empty / loading state ─────────────────────────────
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: primaryGreen),
                            const SizedBox(height: 16),
                            Text(
                              tr('loading_cell_data'),
                              style: const TextStyle(
                                  color: Colors.black45, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _vIcon() => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Center(
          child: Text(
            'V',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}