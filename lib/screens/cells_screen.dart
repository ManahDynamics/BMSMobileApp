// lib/screens/cells_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
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
  static const primaryGreen = Color(0xFF1B6B3A);
  static const cardBlue = Color(0xFF3A6EAC);
  static const titleGreyBg = Color(0xFFEEEEEE);

  SortType _sortBy = SortType.cellNo;
  List<CellData> _sortedCells = [];

  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    TranslationService.instance.addListener(_onChanged);
    widget.service.addListener(_onChanged);
    _sortCells();
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
    if (cv?.cellVoltages == null || cv!.cellVoltages!.isEmpty) {
      return [];
    }

    final voltages = List<double>.from(cv.cellVoltages!);
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

  String get _deviceName =>
      widget.service.bleName ?? widget.service.latestDashboard?.bleName ?? 'BMS Device';

  int get _totalCells =>
      widget.service.latestCellVoltage?.cellTotalCells ??
      widget.service.latestDashboard?.totalCells ??
      _sortedCells.length;

  double? get _maxVoltage => widget.service.latestCellVoltage?.cellMaxVoltage;
  int? get _maxVoltageNo => widget.service.latestCellVoltage?.cellMaxVoltageNo;
  double? get _minVoltage => widget.service.latestCellVoltage?.cellMinVoltage;
  int? get _minVoltageNo => widget.service.latestCellVoltage?.cellMinVoltageNo;
  double? get _avgVoltage => widget.service.latestCellVoltage?.cellAvgVoltage;
  bool get _balancingActive => widget.service.latestCellVoltage?.cellBalancingActive ?? false;

  ({String text, Color color}) _cellStatus(double v) {
    if (v < 3.2) {
      return (text: 'Poor', color: Colors.orange);
    }
    return (text: 'Good', color: primaryGreen);
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    String? sub,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cardBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 4),
              Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              if (sub != null)
                Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasData = _sortedCells.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_deviceName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cell Details${_totalCells > 0 ? ' ($_totalCells Cells)' : ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            IntrinsicHeight(
              child: Row(
                children: [
                  _summaryCard(icon: Icons.arrow_upward, label: 'Max. Volt', value: _maxVoltage != null ? '${_maxVoltage!.toStringAsFixed(3)} V' : '– V', sub: _maxVoltageNo != null ? 'Cell ${_maxVoltageNo.toString().padLeft(2, '0')}' : null),
                  const SizedBox(width: 8),
                  _summaryCard(icon: Icons.arrow_downward, label: 'Min. Volt', value: _minVoltage != null ? '${_minVoltage!.toStringAsFixed(3)} V' : '– V', sub: _minVoltageNo != null ? 'Cell ${_minVoltageNo.toString().padLeft(2, '0')}' : null),
                  const SizedBox(width: 8),
                  _summaryCard(icon: Icons.show_chart, label: 'Average Voltage', value: _avgVoltage != null ? '${_avgVoltage!.toStringAsFixed(1)} V' : '– V'),
                  const SizedBox(width: 8),
                  _summaryCard(icon: Icons.balance_rounded, label: 'Balancing', value: _balancingActive ? 'Active' : 'Inactive'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: titleGreyBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cell Voltages', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54)),
                  Row(
                    children: [
                      const Text('Sort by: ', style: TextStyle(fontSize: 13, color: Colors.black54)),
                      GestureDetector(
                        onTap: () => _showSortMenu(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Text(_sortBy == SortType.cellNo ? 'Cell No.' : 'Voltage'),
                              const Icon(Icons.keyboard_arrow_down, size: 18),
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

            Expanded(
              child: hasData
                  ? ListView.builder(
                      itemCount: _sortedCells.length,
                      itemBuilder: (context, index) {
                        final cell = _sortedCells[index];
                        final status = _cellStatus(cell.voltage);

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  SizedBox(width: 58, child: Text('Cell ${cell.no.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w500))),
                                  SizedBox(width: 78, child: Text('${cell.voltage.toStringAsFixed(3)} V', style: const TextStyle(fontSize: 13.5))),

                                  Expanded(
                                    child: Row(
                                      children: List.generate(
                                        8,
                                        (i) => Container(
                                          width: 9.5,
                                          height: 16,
                                          margin: const EdgeInsets.only(right: 2),
                                          decoration: BoxDecoration(
                                            color: i < (cell.voltage * 2.4).clamp(0, 8).toInt()
                                                ? (cell.voltage >= 3.2 ? primaryGreen : Colors.orange)
                                                : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    width: 85,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(status.text, style: TextStyle(color: status.color, fontWeight: FontWeight.w500, fontSize: 13.5)),
                                        if (cell.balancingActive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('B', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index != _sortedCells.length - 1)
                              const Divider(height: 1, indent: 16, endIndent: 16),
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
                          Text('Waiting for cell data...', style: TextStyle(color: Colors.black54)),
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
    final result = await showMenu<SortType>(
      context: context,
      position: const RelativeRect.fromLTRB(200, 100, 0, 0),
      items: [
        const PopupMenuItem(value: SortType.cellNo, child: Text('Cell No.')),
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