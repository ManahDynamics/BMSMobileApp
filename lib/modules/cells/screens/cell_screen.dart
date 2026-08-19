// lib/screens/cells_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/widgets/screen_pulse_overlay.dart';

enum SortType { cellNo, voltage }

class CellData {
  final int    no;
  final double voltage;
  final bool   balancingActive;

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
  static const primaryGreen = Color(0xFF0B6645);
  static const cardBlue     = Color(0xFF3A6EAC);
  static const titleGreyBg  = Color(0xFFEEEEEE);

  final LocalAuthDB _localAuthDB = LocalAuthDB();

  SortType        _sortBy       = SortType.cellNo;
  List<CellData>  _sortedCells  = [];
  bool            _isFromCache  = false;
  final GlobalKey _sortButtonKey = GlobalKey();

  // Cached values for summary tiles when offline
  double? _cachedMaxVoltage;
  int?    _cachedMaxVoltageNo;
  double? _cachedMinVoltage;
  int?    _cachedMinVoltageNo;
  double? _cachedAvgVoltage;
  int     _cachedTotalCells = 0;

  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.service.startCellVoltagePolling();
    });
    TranslationService.instance.addListener(_onChanged);
    widget.service.addListener(_onChanged);
    _sortCells();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.service.refreshCellVoltages();

      // If BLE already has no data, try loading from cache immediately
      if (widget.service.latestCellVoltage == null) {
        _loadFromCache();
      }
    });
  }

  void _onChanged() {
    if (!mounted) return;
    // If live BLE data arrived, use it (clears cache flag)
    if (widget.service.latestCellVoltage != null) {
      setState(() {
        _isFromCache = false;
        _sortCells();
      });
    } else {
      setState(_sortCells);
    }
  }

  @override

  void dispose() {
    widget.service.removeListener(_onChanged);
    TranslationService.instance.removeListener(_onChanged);
     widget.service.startDashboardPolling();
    super.dispose();
  }

  // ── Build live cells from BLE service ───────────────────────────────────

  List<CellData> _buildCells() {
    final cv = widget.service.latestCellVoltage;
    if (cv?.cellVoltages == null || cv!.cellVoltages!.isEmpty) return [];
    final voltages  = List<double>.from(cv.cellVoltages!);
    final balancing = cv.cellBalancing ?? [];
    return List.generate(
      voltages.length,
      (i) => CellData(
        no              : i + 1,
        voltage         : voltages[i],
        balancingActive : i < balancing.length ? balancing[i] : false,
      ),
    );
  }

  void _sortCells() {
    final cells = _buildCells();
    _sortedCells = [...cells]
      ..sort((a, b) => _sortBy == SortType.voltage
          ? b.voltage.compareTo(a.voltage)
          : a.no.compareTo(b.no));
  }

  // ── Load from cache when BLE data is unavailable ─────────────────────────

  Future<void> _loadFromCache() async {
    final cached = await _localAuthDB.getCachedCellVoltage();
    if (cached == null || !mounted) return;

    final rawVoltages = cached['cellVoltages'];
    if (rawVoltages == null) return;

    final voltages  = List<double>.from(
        (rawVoltages as List<dynamic>).map((e) => (e as num).toDouble()));
    final balancing = cached['cellBalancing'] != null
        ? List<bool>.from(
            (cached['cellBalancing'] as List<dynamic>).map((e) => e as bool))
        : <bool>[];

    final cells = List.generate(
      voltages.length,
      (i) => CellData(
        no              : i + 1,
        voltage         : voltages[i],
        balancingActive : i < balancing.length ? balancing[i] : false,
      ),
    );

    setState(() {
      _isFromCache      = true;
      _cachedTotalCells = (cached['cellTotalCells'] as num?)?.toInt() ?? cells.length;
      _cachedMaxVoltage    = (cached['cellMaxVoltage'] as num?)?.toDouble();
      _cachedMaxVoltageNo  = (cached['cellMaxVoltageNo'] as num?)?.toInt();
      _cachedMinVoltage    = (cached['cellMinVoltage'] as num?)?.toDouble();
      _cachedMinVoltageNo  = (cached['cellMinVoltageNo'] as num?)?.toInt();
      _cachedAvgVoltage    = (cached['cellAvgVoltage'] as num?)?.toDouble();

      _sortedCells = [...cells]
        ..sort((a, b) => _sortBy == SortType.voltage
            ? b.voltage.compareTo(a.voltage)
            : a.no.compareTo(b.no));
    });
  }

  // ── Accessors (live BLE first, cached fallback) ──────────────────────────

  String get _deviceName =>
      widget.service.bleName ?? tr('cells.bms_device_fallback');

  int get _totalCells =>
      widget.service.latestCellVoltage?.cellTotalCells ??
      widget.service.latestDashboard?.totalCells ??
      (_isFromCache ? _cachedTotalCells : _sortedCells.length);

  double? get _maxVoltage =>
      widget.service.latestCellVoltage?.cellMaxVoltage ?? _cachedMaxVoltage;
  int? get _maxVoltageNo =>
      widget.service.latestCellVoltage?.cellMaxVoltageNo ?? _cachedMaxVoltageNo;
  double? get _minVoltage =>
      widget.service.latestCellVoltage?.cellMinVoltage ?? _cachedMinVoltage;
  int? get _minVoltageNo =>
      widget.service.latestCellVoltage?.cellMinVoltageNo ?? _cachedMinVoltageNo;
  double? get _avgVoltage =>
      widget.service.latestCellVoltage?.cellAvgVoltage ?? _cachedAvgVoltage;
  bool get _balancingActive =>
      widget.service.latestCellVoltage?.cellBalancingActive ?? false;

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
      v < 3.0
          ? (text: tr('cells.status_poor'), color: _voltageTierColor(v))
          : (text: tr('cells.status_good'), color: _voltageTierColor(v));

          Color _voltageTierColor(double v) {
    if (v >= 4.5) return const Color(0xFF0B6645); // darkest green — 4.5–5.0V
    if (v >= 4.0) return const Color(0xFF0B6645); // green — 4.0–4.5V
    if (v >= 3.5) return const Color(0xFF0B6645); // medium green — 3.5–4.0V
    if (v >= 3.0) return const Color(0xFF0B6645); // lightest green — 3.0–3.5V
    if (v >= 2.5) return const Color(0xFFE8A33D); // orange — 2.5–3.0V
    return const Color(0xFFD9483A);               // red — 2.0–2.5V
  }

  // ── Summary tile ─────────────────────────────────────────────────────────

  Widget _summaryTile({
    required String label,
    required String value,
    String? sub,
    bool isBalancing    = false,
    bool balancingActive = false,
    bool isTotalCells   = false,
  }) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width : 28, height: 28,
                decoration: BoxDecoration(
                  shape : BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: isBalancing
                      ? const Icon(Icons.balance_rounded,
                          color: Colors.white, size: 14)
                      : isTotalCells
                          ? const Icon(Icons.battery_std_rounded,
                              color: Colors.white, size: 16)
                          : const Text('V',
                              style: TextStyle(
                                  color     : Colors.white,
                                  fontSize  : 13,
                                  fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 5),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 10)),
              const SizedBox(height: 3),
              if (isBalancing) ...[
                Text('${tr('cells.active')}/',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: balancingActive
                            ? Colors.greenAccent
                            : Colors.white38,
                        fontSize  : 13,
                        fontWeight: FontWeight.bold)),
                Text(tr('cells.inactive'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: !balancingActive
                            ? Colors.orangeAccent
                            : Colors.white38,
                        fontSize  : 13,
                        fontWeight: FontWeight.bold)),
              ] else ...[
                Text(value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color     : Colors.white,
                        fontSize  : 14,
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
    final alertCount = _alertCount;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(activeRoute: '/cells', service: widget.service),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation      : 0,
        centerTitle    : true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon     : const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          children: [
            Text(tr('cells.title'),
                style: const TextStyle(
                    color     : Colors.white,
                    fontSize  : 16,
                    fontWeight: FontWeight.w600)),
            Text(_deviceName,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11)),
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
              if (alertCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding   : const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text('$alertCount',
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
            onSelected: (_) {},
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'edit_profile', child: Text(tr('dashboard.edit_profile'))),
              PopupMenuItem(
                  value: 'forget_password', child: Text(tr('dashboard.forget_password'))),
              PopupMenuItem(value: 'logout', child: Text(tr('logout.title'))),
            ],
          ),
        ],
      ),
      body: ScreenPulseOverlay(
  pulseValue: widget.service.cellVoltagePulse,
  color: primaryGreen,
  child: widget.service.isCellVoltageLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('cells.loading'),
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            )
          : Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Offline cache banner ───────────────────────────────────
            if (_isFromCache)
              Container(
                width  : double.infinity,
                margin : const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color       : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border      : Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off,
                        size: 14, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('cells.offline_banner'),
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            Text(
              '${tr('cells.title')}${_totalCells > 0 ? ' ($_totalCells ${tr('dashboard.cells')})' : ''}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // ── Summary container ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                  color       : cardBlue,
                  borderRadius: BorderRadius.circular(10)),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 1, color: Colors.white24),
                    _summaryTile(
                      label        : tr('cells.total_cells'),
                      value        : '$_totalCells',
                      isTotalCells : true,
                    ),
                    Container(width: 1, color: Colors.white24),
                    _summaryTile(
                      label: tr('cells.max_volt'),
                      value: _maxVoltage != null
                          ? '${_maxVoltage!.toStringAsFixed(3)} V'
                          : '– V',
                      sub  : _maxVoltageNo != null
                          ? '${tr('cells.cell_label')} ${_maxVoltageNo.toString().padLeft(2, '0')}'
                          : null,
                    ),
                    Container(width: 1, color: Colors.white24),
                    _summaryTile(
                      label: tr('cells.min_volt'),
                      value: _minVoltage != null
                          ? '${_minVoltage!.toStringAsFixed(3)} V'
                          : '– V',
                      sub  : _minVoltageNo != null
                          ? '${tr('cells.cell_label')} ${_minVoltageNo.toString().padLeft(2, '0')}'
                          : null,
                    ),
                    Container(width: 1, color: Colors.white24),
                    _summaryTile(
                      label: tr('cells.average_voltage'),
                      value: _avgVoltage != null
                          ? '${_avgVoltage!.toStringAsFixed(1)} V'
                          : '– V',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Sort header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color       : titleGreyBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('cells.cell_voltages'),
                      style: const TextStyle(
                          fontSize  : 14,
                          fontWeight: FontWeight.w600,
                          color     : Colors.black54)),
                  Row(
                    children: [
                      Text('${tr('cells.sort_by')}: ',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      GestureDetector(
                        key    : _sortButtonKey,
                        onTap  : () => _showSortMenu(context),
                        child  : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color       : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border      : Border.all(
                                color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _sortBy == SortType.cellNo
                                    ? tr('cells.sort_cell_no')
                                    : tr('cells.sort_voltage'),
                                style:
                                    const TextStyle(fontSize: 12),
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

            // ── Cell list ──────────────────────────────────────────────
            Expanded(
              child: hasData
                  ? ListView.builder(
                      itemCount  : _sortedCells.length,
                      itemBuilder: (context, index) {
                        final cell       = _sortedCells[index];
                        final status     = _cellStatus(cell.voltage);
                        final bool isPoor = cell.voltage < 3.2;
                        final int filledBars =
                            ((cell.voltage - 2.0) / (5.0 - 2.0) * 8)
                                .clamp(0, 8)
                                .toInt();

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 54,
                                    child: Text(
                                      '${tr('cells.cell_label')} ${cell.no.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize  : 13,
                                          color     : Colors.black87),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 64,
                                    child: Text(
                                      '${cell.voltage.toStringAsFixed(3)} V',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color   : Colors.black54),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: List.generate(8, (i) {
                                        final bool filled = i < filledBars;
                                        return Container(
                                          width : 10,
                                          height: 15,
                                          margin: const EdgeInsets.only(right: 3),
                                          decoration: BoxDecoration(
                                            color: filled
                                                ? _voltageTierColor(cell.voltage)
                                                : Colors.grey.shade300,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      status.text,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                          color     : status.color,
                                          fontWeight: FontWeight.w500,
                                          fontSize  : 13),
                                    ),
                                  ),
                                  if (cell.balancingActive) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      width : 18, height: 18,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          shape: BoxShape.circle),
                                      child: const Center(
                                        child: Text('B',
                                            style: TextStyle(
                                                color     : Colors.black54,
                                                fontSize  : 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (index != _sortedCells.length - 1)
                              const Divider(
                                  height   : 1,
                                  thickness: 1,
                                  indent   : 14,
                                  endIndent: 14),
                          ],
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.service.cellVoltageError != null
                            ? [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade400,
                                    size: 36),
                                const SizedBox(height: 12),
                                Text(
                                  widget.service.cellVoltageError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: Text(tr('cells.retry')),
                                  onPressed: () => widget.service
                                      .refreshCellVoltages(),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.history),
                                  label: Text(tr('dashboard.load_cached_data')),
                                  onPressed: _loadFromCache,
                                ),
                              ]
                            : [
                                const CircularProgressIndicator(
                                    color: primaryGreen),
                                const SizedBox(height: 16),
                                Text(tr('cells.waiting_for_data'),
                                    style: const TextStyle(
                                        color: Colors.black54)),
                                const SizedBox(height: 12),
                                // Offer to load from cache
                                TextButton.icon(
                                  icon: const Icon(Icons.history),
                                  label: Text(tr('dashboard.load_cached_data')),
                                  onPressed: _loadFromCache,
                                ),
                              ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    )
    );
  }

  Future<void> _showSortMenu(BuildContext context) async {
    final RenderBox button =
        _sortButtonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonTopLeft =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset buttonBottomRight = button.localToGlobal(
        button.size.bottomRight(Offset.zero), ancestor: overlay);

    final position = RelativeRect.fromLTRB(
      buttonTopLeft.dx,
      buttonBottomRight.dy + 4,
      overlay.size.width - buttonBottomRight.dx,
      0,
    );

    final result = await showMenu<SortType>(
      context : context,
      position: position,
      items   : [
        PopupMenuItem(value: SortType.cellNo,  child: Text(tr('cells.sort_cell_no'))),
        PopupMenuItem(value: SortType.voltage, child: Text(tr('cells.sort_voltage'))),
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