// lib/screens/cells_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';

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
  static const primaryGreen = Color(0xFF1B6B3A);
  static const cardBlue     = Color(0xFF3A6EAC);
  static const titleGreyBg  = Color(0xFFEEEEEE);

  SortType _sortBy = SortType.cellNo;
  List<CellData> _sortedCells = [];
  final GlobalKey _sortButtonKey = GlobalKey();

  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onChanged);
    widget.service.addListener(_onChanged);
    _sortCells();
    // ── Request fresh cell voltage data the moment this screen opens ──────
    widget.service.refreshCellVoltages();
  }

  void _onChanged() {
    if (mounted) setState(() => _sortCells());
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    TranslationService.instance.removeListener(_onChanged);
    super.dispose();
  }

  List<CellData> _buildCells() {
    final cv = widget.service.latestCellVoltage;
    if (cv?.cellVoltages == null || cv!.cellVoltages!.isEmpty) return [];
    final voltages  = List<double>.from(cv.cellVoltages!);
    final balancing = cv.cellBalancing ?? [];
    return List.generate(voltages.length, (i) => CellData(
      no: i + 1,
      voltage: voltages[i],
      balancingActive: i < balancing.length ? balancing[i] : false,
    ));
  }

  void _sortCells() {
    final cells = _buildCells();
    _sortedCells = [...cells]
      ..sort((a, b) => _sortBy == SortType.voltage
          ? b.voltage.compareTo(a.voltage)
          : a.no.compareTo(b.no));
  }

      String get _deviceName => widget.service.bleName ?? 'BMS Device';

  int get _totalCells =>
      widget.service.latestCellVoltage?.cellTotalCells ??
      widget.service.latestDashboard?.totalCells ??
      _sortedCells.length;

  double? get _maxVoltage      => widget.service.latestCellVoltage?.cellMaxVoltage;
  int?    get _maxVoltageNo    => widget.service.latestCellVoltage?.cellMaxVoltageNo;
  double? get _minVoltage      => widget.service.latestCellVoltage?.cellMinVoltage;
  int?    get _minVoltageNo    => widget.service.latestCellVoltage?.cellMinVoltageNo;
  double? get _avgVoltage      => widget.service.latestCellVoltage?.cellAvgVoltage;
  bool    get _balancingActive => widget.service.latestCellVoltage?.cellBalancingActive ?? false;

  // Alert count reused from dashboard logic (just SOC + temp for now)
  int get _alertCount {
    int count = 0;
    final dash = widget.service.latestDashboard;
    if (dash?.temperature != null && dash!.temperature! > 45) count++;
    if ((dash?.soc ?? 100) <= 10) count++;
    if (dash?.temperature != null && dash!.temperature! < 0) count++;
    if ((dash?.voltageDiff ?? 0) > 0.1) count++;
    return count;
  }

  ({String text, Color color}) _cellStatus(double v) =>
      v < 3.2 ? (text: 'Poor', color: Colors.orange) : (text: 'Good', color: primaryGreen);

  // ── Single combined summary container with 4 equal tiles ────────────────
  Widget _summaryTile({
    required String label,
    required String value,
    String? sub,
    bool isBalancing = false,
    bool balancingActive = false,
  }) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle icon
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: isBalancing
                      ? const Icon(Icons.balance_rounded,
                          color: Colors.white, size: 14)
                      : const Text('V',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 5),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
              const SizedBox(height: 3),
              if (isBalancing) ...[
                Text('Active/',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: balancingActive
                            ? Colors.greenAccent
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Text('Inactive',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: !balancingActive
                            ? Colors.orangeAccent
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ] else ...[
                Text(value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ],
              ],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasData    = _sortedCells.isNotEmpty;
    final maxCellNo  = _maxVoltageNo;
    final minCellNo  = _minVoltageNo;
    final alertCount = _alertCount;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/cells', service: widget.service),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        // ── Hamburger menu on left ────────────────────────────────────
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        // ── Title: "Cell Details" + device name subtitle ──────────────
        title: Column(
          children: [
            const Text('Cell Details',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            Text(_deviceName,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          // ── Notification bell with badge ──────────────────────────
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white),
                onPressed: () {},
              ),
              if (alertCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text('$alertCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          // ── Three dots menu ───────────────────────────────────────
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (value) {
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                  value: 'edit_profile', child: Text('Edit Profile')),
              PopupMenuItem(
                  value: 'forget_password', child: Text('Forget Password')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Title row ─────────────────────────────────────────────────
            Text(
              'Cell Details${_totalCells > 0 ? ' ($_totalCells Cells)' : ''}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // ── Single combined summary container ─────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     Container(width: 1, color: Colors.white24),
                    _summaryTile(
                    label: 'Total Cells',
                    value: '$_totalCells',
                    ),
                     Container(width: 1, color: Colors.white24),
                    _summaryTile(
                      label: 'Max. Volt',
                      value: _maxVoltage != null
                          ? '${_maxVoltage!.toStringAsFixed(3)} V'
                          : '– V',
                      sub: _maxVoltageNo != null
                          ? 'Cell ${_maxVoltageNo.toString().padLeft(2, '0')}'
                          : null,
                    ),
                    // Vertical divider
                    Container(width: 1, color: Colors.white24),
                    _summaryTile(
                      label: 'Min. Volt',
                      value: _minVoltage != null
                          ? '${_minVoltage!.toStringAsFixed(3)} V'
                          : '– V',
                      sub: _minVoltageNo != null
                          ? 'Cell ${_minVoltageNo.toString().padLeft(2, '0')}'
                          : null,
                    ),
                    Container(width: 1, color: Colors.white24),
                    _summaryTile(
                      label: 'Average\nVoltage',
                      value: _avgVoltage != null
                          ? '${_avgVoltage!.toStringAsFixed(1)} V'
                          : '– V',
                    ),
                  
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Cell Voltages header + sort ───────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: titleGreyBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cell Voltages',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  Row(
                    children: [
                      const Text('Sort by: ',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      GestureDetector(
                        key: _sortButtonKey,
                        onTap: () => _showSortMenu(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _sortBy == SortType.cellNo
                                    ? 'Cell No.'
                                    : 'Voltage',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Icon(Icons.keyboard_arrow_down,
                                  size: 16),
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

            // ── Cell List ─────────────────────────────────────────────────
            Expanded(
              child: hasData
                  ? ListView.builder(
                      itemCount: _sortedCells.length,
                      itemBuilder: (context, index) {
                        final cell   = _sortedCells[index];
                        final status = _cellStatus(cell.voltage);
                        final bool isPoor   = cell.voltage < 3.2;
                        final bool isMaxCell = cell.no == maxCellNo;
                        final bool isMinCell = cell.no == minCellNo;

                        // Bar fill: 3.0–4.2V → 0–8 bars
                        final int filledBars =
                            ((cell.voltage - 3.0) / (4.2 - 3.0) * 8)
                                .clamp(0, 8)
                                .toInt();

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  // Cell number
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      'Cell ${cell.no.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13),
                                    ),
                                  ),

                                  // Voltage value
                                  SizedBox(
                                    width: 68,
                                    child: Text(
                                      '${cell.voltage.toStringAsFixed(3)} V',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),

                                  // Bar chart — 8 segments
                                  Expanded(
                                    child: Row(
                                      children: List.generate(8, (i) {
                                        final bool filled = i < filledBars;
                                        return Container(
                                          width: 10,
                                          height: 15,
                                          margin: const EdgeInsets.only(
                                              right: 2),
                                          decoration: BoxDecoration(
                                            color: filled
                                                ? (isPoor
                                                    ? Colors.orange
                                                    : primaryGreen)
                                                : Colors.grey.shade300,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  // ── Red dot for max cell ──────────
                                  if (isMaxCell)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle),
                                    )
                                  else if (isMinCell)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle),
                                    )
                                  else
                                    const SizedBox(width: 12),

                                  // Status text
                                  Text(
                                    status.text,
                                    style: TextStyle(
                                        color: status.color,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13),
                                  ),

                                  // Balancing badge
                                  if (cell.balancingActive) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: primaryGreen,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Text('B',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (index != _sortedCells.length - 1)
                              const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 14,
                                  endIndent: 14),
                          ],
                        );
                      },
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: primaryGreen),
                          SizedBox(height: 16),
                          Text('Waiting for cell data...',
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSortMenu(BuildContext context) async {
    // ── Calculate the button's position so menu opens directly below it ───
    final RenderBox button =
        _sortButtonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset buttonBottomRight = button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay);

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonTopLeft.dx,
      buttonBottomRight.dy + 4, // small gap below the button
      overlay.size.width - buttonBottomRight.dx,
      0,
    );

    final result = await showMenu<SortType>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: SortType.cellNo,  child: Text('Cell No.')),
        const PopupMenuItem(value: SortType.voltage, child: Text('Voltage')),
      ],
    );
    if (result != null && result != _sortBy) {
      setState(() {
        _sortBy = result;
        _sortCells();
      });
    }
  }
}