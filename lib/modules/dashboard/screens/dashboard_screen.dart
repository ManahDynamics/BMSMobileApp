// lib/screens/dashboard_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:bmsmobileapp/battery_indicator.dart'
    show BatteryIndicator, BatteryMode;
import 'package:flutter/material.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/services/local_auth_db.dart';
import '../../../modules/scanner/screens/BMS_scanner_screen.dart';
import '../../../modules/cells/screens/cell_screen.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/widgets/app_drawer.dart';
import 'package:bmsmobileapp/widgets/screen_pulse_overlay.dart';

import 'package:provider/provider.dart';

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
  final LocalAuthDB _localAuthDB = LocalAuthDB();

  Map<String, dynamic>? _lastCachedDash;
  Map<String, dynamic>? _lastCachedCell;
  String? _lastCachedDeviceName;
  Map<String, dynamic>? _cachedDashboard;
  Map<String, dynamic>? _cachedCellVoltage;
  String? _cachedDeviceName;
  bool _isFromCache = false;

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
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth,
                size: 40,
                color: Color(0xFF00796B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('dashboard.disconnect_confirm'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _disconnect();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBD5D26),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      tr('dashboard.yes'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      tr('dashboard.cancel'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

  /// Caches the device name
  Future<void> _cacheDeviceNameIfNew() async {
    final name = widget.service.bleName;
    if (name == null || name.isEmpty) return;

    if (name != _lastCachedDeviceName) {
      _lastCachedDeviceName = name;
      await _localAuthDB.saveDeviceName(name);

      setState(() {
        _cachedDeviceName = name;
        _isFromCache = false;
      });
    }
  }

  /// Converts dashboard model to a plain map and caches it.
  Future<void> _cacheDashboardIfNew() async {
    final dash = widget.service.latestDashboard;
    if (dash == null) return;

    // Build a comparable snapshot map from the dashboard model fields
    final map = <String, dynamic>{
      'soc': dash.soc,
      'batteryStatusCode': dash.batteryStatusCode,
      'batteryStatusLabel': dash.batteryStatusLabel,
      'batteryType': dash.batteryType,
      'batterySerial': dash.batterySerial,
      'capacityDisplay': dash.capacityDisplay,
      'healthLabel': dash.healthLabel,
      'healthCode': dash.healthCode,
      'voltageDisplay': dash.voltageDisplay,
      'currentDisplay': dash.currentDisplay,
      'temperatureDisplay': dash.temperatureDisplay,
      'powerDisplay': dash.powerDisplay,
      'chargeCyclesDisplay': dash.chargeCyclesDisplay,
      'totalCells': dash.totalCells,
      'avgCellVoltageDisplay': dash.avgCellVoltageDisplay,
      'voltageDiffDisplay': dash.voltageDiffDisplay,
      'minCellVoltageDisplay': dash.minCellVoltageDisplay,
      'maxCellVoltageDisplay': dash.maxCellVoltageDisplay,
      'temperature': dash.temperature,
      'voltageDiff': dash.voltageDiff,
      'warningAlerts': dash.warningAlerts,
      'faultAlerts': dash.faultAlerts,
      'clearedAlerts': dash.clearedAlerts,
      'totalAlerts': dash.totalAlerts,
    };

    // Only write if something changed
    if (map.toString() != _lastCachedDash.toString()) {
      _lastCachedDash = map;
      await _localAuthDB.saveDashboard(map);

      // Also update cached dashboard for display
      setState(() {
        _cachedDashboard = map;
        _isFromCache = false;
      });
    }
  }

  /// Converts cell voltage model to a plain map and caches it./// Converts cell voltage data (now embedded in the Dashboard packet) to a
  /// plain map and caches it.
  Future<void> _cacheCellVoltageIfNew() async {
    final dash = widget.service.latestDashboard;
    if (dash == null || dash.cellVoltages == null || dash.cellVoltages!.isEmpty) {
      return;
    }

    final voltages = dash.cellVoltages!;
    int? maxNo, minNo;
    if (dash.maxCellVoltage != null) {
      final i = voltages.indexWhere((v) => v == dash.maxCellVoltage);
      if (i >= 0) maxNo = i + 1;
    }
    if (dash.minCellVoltage != null) {
      final i = voltages.indexWhere((v) => v == dash.minCellVoltage);
      if (i >= 0) minNo = i + 1;
    }

    final map = <String, dynamic>{
      'cellVoltages': voltages,
      'cellTotalCells': dash.totalCells,
      'cellMaxVoltage': dash.maxCellVoltage,
      'cellMaxVoltageNo': maxNo,
      'cellMinVoltage': dash.minCellVoltage,
      'cellMinVoltageNo': minNo,
      'cellAvgVoltage': dash.avgCellVoltage,
    };

    if (map.toString() != _lastCachedCell.toString()) {
      _lastCachedCell = map;
      await _localAuthDB.saveCellVoltage(map);

      setState(() {
        _cachedCellVoltage = map;
        _isFromCache = false;
      });
    }
  }

  // ── Load from cache when BLE data is unavailable ─────────────────────────

  Future<void> _loadFromCache() async {
    final cachedDash = await _localAuthDB.getCachedDashboard();
    final cachedCell = await _localAuthDB.getCachedCellVoltage();
    final cachedName = await _localAuthDB.getCachedDeviceName();

    if (!mounted) return;

    setState(() {
      if (cachedDash != null) {
        _cachedDashboard = cachedDash;
        _isFromCache = true;
      }
      if (cachedCell != null) {
        _cachedCellVoltage = cachedCell;
        _isFromCache = true;
      }
      if (cachedName != null && cachedName.isNotEmpty) {
        _cachedDeviceName = cachedName;
        _isFromCache = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.service.startDashboardPolling();
    });

    // Try to load cached data initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If BLE has data, use it, otherwise load from cache.
      // Cell voltages now come from the Dashboard packet itself, so we no
      // longer check latestCellVoltage here.
      if (widget.service.latestDashboard == null ||
          widget.service.bleName == null) {
        _loadFromCache();
      }
    });
  }

  // ── Accessors (live BLE first, cached fallback) ──────────────────────────

  String get _effectiveDeviceName {
    final liveName = widget.service.bleName;
    if (liveName != null && liveName.isNotEmpty) {
      return liveName;
    }
    return _cachedDeviceName ?? widget.service.device?.name ?? 'BMS Device';
  }

  Map<String, dynamic>? get _effectiveDashboard {
    final live = widget.service.latestDashboard;
    if (live != null) {
      // Convert live model to map for consistent access
      return {
        'soc': live.soc,
        'batteryStatusCode': live.batteryStatusCode,
        'batteryStatusLabel': live.batteryStatusLabel,
        'batteryType': live.batteryType,
        'batterySerial': live.batterySerial,
        'capacityDisplay': live.capacityDisplay,
        'healthLabel': live.healthLabel,
        'healthCode': live.healthCode,
        'voltageDisplay': live.voltageDisplay,
        'currentDisplay': live.currentDisplay,
        'temperatureDisplay': live.temperatureDisplay,
        'powerDisplay': live.powerDisplay,
        'chargeCyclesDisplay': live.chargeCyclesDisplay,
        'totalCells': live.totalCells,
        'avgCellVoltageDisplay': live.avgCellVoltageDisplay,
        'voltageDiffDisplay': live.voltageDiffDisplay,
        'minCellVoltageDisplay': live.minCellVoltageDisplay,
        'maxCellVoltageDisplay': live.maxCellVoltageDisplay,
        'temperature': live.temperature,
        'voltageDiff': live.voltageDiff,
        'warningAlerts': live.warningAlerts,
        'faultAlerts': live.faultAlerts,
        'clearedAlerts': live.clearedAlerts,
        'totalAlerts': live.totalAlerts,
      };
    }
    return _cachedDashboard;
  }

  Map<String, dynamic>? get _effectiveCellVoltage {
    final live = widget.service.latestDashboard;
    if (live != null &&
        live.cellVoltages != null &&
        live.cellVoltages!.isNotEmpty) {
      final voltages = live.cellVoltages!;
      int? maxNo, minNo;
      if (live.maxCellVoltage != null) {
        final i = voltages.indexWhere((v) => v == live.maxCellVoltage);
        if (i >= 0) maxNo = i + 1;
      }
      if (live.minCellVoltage != null) {
        final i = voltages.indexWhere((v) => v == live.minCellVoltage);
        if (i >= 0) minNo = i + 1;
      }
      return {
        'cellVoltages': voltages,
        'cellTotalCells': live.totalCells,
        'cellMaxVoltage': live.maxCellVoltage,
        'cellMaxVoltageNo': maxNo,
        'cellMinVoltage': live.minCellVoltage,
        'cellMinVoltageNo': minNo,
        'cellAvgVoltage': live.avgCellVoltage,
      };
    }
    return _cachedCellVoltage;
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;

    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        _cacheDeviceNameIfNew();
        _cacheDashboardIfNew();
        _cacheCellVoltageIfNew();

        // Get effective data (live or cached)
        final deviceName = _effectiveDeviceName;
        final dashMap = _effectiveDashboard;
        final cellMap = _effectiveCellVoltage;

        // ── Device Info ────────────────────────────────────────────────
        final String batteryType =
            svc.batteryType ?? dashMap?['batteryType'] ?? '-';
        final String serialNo =
            svc.batterySerial ?? dashMap?['batterySerial'] ?? '-';

        // ── Dashboard Data ─────────────────────────────────────────────
        final int soc = dashMap?['soc'] ?? 0;
        final String batteryStatus = dashMap?['batteryStatusLabel'] ?? 'N/A';
        final bool isCharging = dashMap?['batteryStatusCode'] == 0x01;
        final String capacityDisplay = dashMap?['capacityDisplay'] ?? '0.0 Ah';
        final String health = dashMap?['healthLabel'] ?? 'N/A';
        final bool healthGood = dashMap?['healthCode'] == 0x01;

        final String voltageDisplay = dashMap?['voltageDisplay'] ?? '0.0 V';
        final String currentDisplay = dashMap?['currentDisplay'] ?? '0.0 A';
        final String tempDisplay = dashMap?['temperatureDisplay'] ?? '0 °C';
        final String powerDisplay = dashMap?['powerDisplay'] ?? '0 Kw';
        final String cyclesDisplay = dashMap?['chargeCyclesDisplay'] ?? '0';

        final int cellCount =
            dashMap?['totalCells'] ?? cellMap?['cellTotalCells'] ?? 0;
        final String avgVoltage = dashMap?['avgCellVoltageDisplay'] ?? '0.00 v';
        final String voltDiff = dashMap?['voltageDiffDisplay'] ?? '0.00 v';
        final String minVoltage =
            dashMap?['minCellVoltageDisplay'] ?? '0.000 V';
        final String maxVoltage =
            dashMap?['maxCellVoltageDisplay'] ?? '0.000 V';

        final List<double> cellVoltages =
            (cellMap?['cellVoltages'] as List?)?.cast<double>() ?? [];
        final int? maxVoltageNo = cellMap?['cellMaxVoltageNo'] as int?;
        final int? minVoltageNo = cellMap?['cellMinVoltageNo'] as int?;

        // ── Build alerts from live BMS data ────────────────────────────
        final int warningAlertsCount = dashMap?['warningAlerts'] as int? ?? 0;
        final int faultAlertsCount = dashMap?['faultAlerts'] as int? ?? 0;
        final int clearedAlertsCount = dashMap?['clearedAlerts'] as int? ?? 0;
        final int totalAlertsCount = dashMap?['totalAlerts'] as int? ?? 0;

        final bool hasData = dashMap != null || cellMap != null;

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
            title: Column(
              children: [
                Text(
                  tr('dashboard.title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (deviceName.isNotEmpty)
                  Text(
                    deviceName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                  if (totalAlertsCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$totalAlertsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) {
                  if (value == 'logout') _showDisconnectDialog();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit_profile',
                    child: Text(tr('dashboard.edit_profile')),
                  ),
                  PopupMenuItem(
                    value: 'forget_password',
                    child: Text(tr('dashboard.forget_password')),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Text(tr('logout.title')),
                  ),
                ],
              ),
            ],
          ),
          body: ScreenPulseOverlay(
            pulseValue: svc.dashboardPulse,
            color: _green,
            child: svc.isDashboardLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _green,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('dashboard.loading_details'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      // ── Offline cache banner ───────────────────────────────────
                      if (_isFromCache && !hasData)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off,
                                size: 14,
                                color: Colors.orange.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tr('dashboard.offline_cached_banner'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      _DeviceHeader(
                        batteryType: batteryType,
                        serialNo: serialNo,
                        onDisconnect: _showDisconnectDialog,
                      ),

                      if (svc.isBleNameLoading && !_isFromCache)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            tr('dashboard.fetching_device_name'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        )
                      else if (svc.bleNameError != null && !_isFromCache)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  svc.bleNameError!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_isFromCache && _cachedDeviceName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 14,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              // Expanded(
                              //   child: Text('Device name from cache: $_cachedDeviceName',
                              //       style: TextStyle(
                              //           fontSize: 12, color: Colors.orange.shade700)),
                              // ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      if (svc.dashboardError != null && !_isFromCache)
                        _ErrorSection(message: svc.dashboardError!)
                      else if (!hasData && !_isFromCache)
                        Column(
                          children: [
                            _ErrorSection(
                              message: tr('dashboard.no_data_available'),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              icon: const Icon(Icons.history),
                              label: Text(tr('dashboard.load_cached_data')),
                              onPressed: _loadFromCache,
                            ),
                          ],
                        )
                      else if (hasData)
                        _BatteryCard(
                          soc: soc,
                          statusCode: dashMap?['batteryStatusCode'] ?? 0x02,
                          capacity: capacityDisplay,
                          status: batteryStatus,
                          isCharging: isCharging,
                          health: health,
                          healthGood: healthGood,
                          cycles: cyclesDisplay,
                        ),

                      _gap16,

                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: tr('dashboard.voltage'),
                              value: voltageDisplay,
                              iconLabel: 'V',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              label: tr('dashboard.current'),
                              value: currentDisplay,
                              iconLabel: 'A',
                              isCharging: isCharging,
                            ),
                          ),
                        ],
                      ),

                      _gap12,

                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: tr('dashboard.temperature'),
                              value: tempDisplay,
                              icon: Icons.thermostat_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              label: tr('dashboard.power'),
                              value: powerDisplay,
                              icon: Icons.power_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      if (!hasData && !_isFromCache)
                        const SizedBox.shrink()
                      else if (hasData)
                        _CellSummary(
                          cellCount: cellCount,
                          avgVoltage: avgVoltage,
                          voltDiff: voltDiff,
                          minVoltage: minVoltage,
                          maxVoltage: maxVoltage,
                          cellVoltages: cellVoltages,
                          maxVoltageNo: maxVoltageNo,
                          minVoltageNo: minVoltageNo,
                          onViewMore: () => Navigator.push(
                            context,
                            SlideRoute(
                              page: CellsScreen(service: widget.service),
                            ),
                          ),
                        ),

                      _gap16,
                      _AlertsSummaryCard(
                        warningCount: warningAlertsCount,
                        faultCount: faultAlertsCount,
                        clearedCount: clearedAlertsCount,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
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
    final tr = TranslationService.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1 — title + subtext
        Text(
          '${tr('dashboard.battery_type')}: $batteryType',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E5E5E),
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '${tr('dashboard.battery_serial_no')}: $serialNo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: 0,
          ),
        ),

        const SizedBox(height: 8),

        // Row 2 — status pill + disconnect button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3FC579), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('dashboard.connected'),
                    style: const TextStyle(
                      color: Color(0xFF0C8F45),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0C8F45),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onDisconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBD5D26),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 1,
              ),
              child: Text(
                tr('dashboard.disconnect'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BatteryCard extends StatefulWidget {
  final int soc, statusCode;
  final String capacity, status, health, cycles;
  final bool isCharging, healthGood;

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
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
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

Color get _socColor {
  if (widget.soc <= 10) return const Color(0xFFE53935);  // red — critical
  if (widget.soc <= 30) return const Color(0xFFFFA726);  // orange — low
  return Colors.white;                                     // white — normal (matches Figma)
}

  @override
    Widget build(BuildContext context) {
     final tr = TranslationService.t;  
      return Container(
       padding: const EdgeInsets.all(10),
       decoration: BoxDecoration(
        color: const Color(0xFF3A6EAC),
        borderRadius: BorderRadius.circular(12),
      ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.soc}%',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        tr('dashboard.soc'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
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
                    Text(
                      tr('dashboard.battery_status'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 70,
                      height: 24,
                      child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: widget.statusCode == 0x01
                          ? BatteryIndicator(
                              key: const ValueKey('charging'),
                              soc: widget.soc.toDouble(),
                              mode: BatteryMode.charging,
                              width: 40,
                              height: 24,
                            )
                          : widget.statusCode == 0x02
                              ? BatteryIndicator(
                                  key: const ValueKey('idle'),
                                  soc: widget.soc.toDouble(),
                                  mode: BatteryMode.idle,
                                  width: 40,
                                  height: 24,
                                )
                              : BatteryIndicator(
                                  key: const ValueKey('load'),
                                  soc: widget.soc.toDouble(),
                                  mode: BatteryMode.loadConnected,
                                  width: 40,
                                  height: 24,
                                ),
                    ),
                    ),
                  ],
                ),
                Text(
                  widget.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(color: Colors.white24, height: 14),
                Text(
                  tr('dashboard.remaining_capacity'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  widget.capacity,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Divider(color: Colors.white24, height: 14),
              IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('dashboard.cycles'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              widget.cycles,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        width: 1,
                        color: Colors.white30,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('dashboard.health'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  widget.health,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                               Icon(
                                widget.healthGood
                                    ? Icons.gpp_good_rounded
                                    : Icons.gpp_bad_rounded,
                                color: widget.healthGood
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final radius = (size.shortestSide - 16) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      6.28 * (soc / 100),
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final String? iconLabel;
  final IconData? icon;
  final String? badge;
  final bool isCharging;

  const _MetricCard({
    required this.label,
    required this.value,
    this.iconLabel,
    this.icon,
    this.isCharging = false,
  }) : badge = null;

 @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade600, width: 1.5),
            ),
            child: iconLabel != null
                ? Text(
                    iconLabel!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  )
                : Icon(icon, color: Colors.black54, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5E5E5E),
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    if (isCharging) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade400, width: 1),
                            ),
                            child: Text(
                              TranslationService.t('dashboard.charging'),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }}
class _CellSummary extends StatelessWidget {
  final int cellCount;
  final String avgVoltage, voltDiff, minVoltage, maxVoltage;
  final List<double> cellVoltages;
  final int? maxVoltageNo, minVoltageNo;
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
Color _voltageColor(double v) {
  if (v >= 4.5) return const Color(0xFF0B6645); // darkest green — 4.5–5.0V
  if (v >= 4.0) return const Color(0xFF0B6645); // green — 4.0–4.5V
  if (v >= 3.5) return const Color(0xFF0B6645); // medium green — 3.5–4.0V
  if (v >= 3.0) return const Color(0xFF0B6645); // lightest green — 3.0–3.5V
  if (v >= 2.5) return const Color(0xFFE8A33D); // orange — 2.5–3.0V
  return const Color(0xFFD9483A);               // red — 2.0–2.5V
}
  @override
  Widget build(BuildContext context) {
    final tr = TranslationService.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Text(
            //   '${tr('dashboard.cell_summary')} ($cellCount ${tr('dashboard.cells')})',
            //   style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            // ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: tr('dashboard.cell_summary'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0,
                    ),
                  ),
                  TextSpan(
                    text: ' ($cellCount ${tr('dashboard.cells')})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF989898),
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onViewMore,
              child: Row(
                children: [
                  Text(
                    tr('dashboard.view_more'),
                    style: const TextStyle(
                      color: Color(0xFF3A6EAC),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF3A6EAC),
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              tr('dashboard.average_voltage'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF5E5E5E), letterSpacing: 0),
            ),
            const SizedBox(width: 4),
            Text(
              avgVoltage,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              tr('dashboard.volt_difference'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF5E5E5E), letterSpacing: 0),
            ),
            const SizedBox(width: 4),
            Text(
              voltDiff,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5E5E5E),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Container(
        padding: const EdgeInsets.fromLTRB(0, 1, 0, 8),
        child: Column(
          children: [
            _buildCellChart(), 
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tr('dashboard.min_volt')} $minVoltage',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5E5E5E), fontWeight: FontWeight.w700, letterSpacing: 0),
                ),
                Text(
                  '${tr('dashboard.max_volt')} $maxVoltage',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5E5E5E), fontWeight: FontWeight.bold, letterSpacing: 0),
                ),
              ],
            ),
          ],
        ),
      ),
      ],
    );    
  }
  Widget _buildCellChart() {
  const double barWidth = 32;

  return LayoutBuilder(
    builder: (context, constraints) {
      final double availableWidth = constraints.maxWidth;
      final double neededWidth = cellVoltages.length * barWidth;
      final bool needsScroll = neededWidth > availableWidth;

      if (!needsScroll) {
        // Fits comfortably — spread bars evenly, no scroll arrows.
        return SizedBox(
          height: 90,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(
              cellVoltages.length,
              (i) => _buildBar(i, cellVoltages, maxVoltageNo, minVoltageNo),
            ),
          ),
        );
      }

      // Too many cells to fit — keep the scrollable version with arrows.
      return SizedBox(
        height: 80,
        width: double.infinity,
        child: Row(
          children: [
            const SizedBox(
              width: 10,
              child: Icon(Icons.chevron_left, size: 18, color: Colors.grey),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: 90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(
                      cellVoltages.length,
                      (i) => _buildBar(i, cellVoltages, maxVoltageNo, minVoltageNo),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 12,
              child: Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildBar(int index, List<double> voltages, int? maxNo, int? minNo) {
  final double v = voltages[index];
  final Color color = _voltageColor(v);
  // Chart box is 85px tall. Value label (~14) + gap(2) + bar + gap(2) + cell label (~14)
  // must all fit inside that, so the bar itself is capped at ~53px max.
  final double height = 15 + ((v - 2.0) / (5.0 - 2.0) * 38).clamp(0.0, 38.0);
  return SizedBox(
    width: 28,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          v.toStringAsFixed(2),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Container(
          width: 18,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 30,
          child: Text(
            'C${(index + 1).toString().padLeft(2, '0')}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.black54),
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF1B6B3A),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
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

class _AlertsSummaryCard extends StatelessWidget {
  final int warningCount, faultCount, clearedCount;
  const _AlertsSummaryCard({
    required this.warningCount,
    required this.faultCount,
    required this.clearedCount,
  });

  @override
  Widget build(BuildContext context) {
    final tr = TranslationService.t;
    final bool hasAny = warningCount > 0 || faultCount > 0 || clearedCount > 0;
    final List<Widget> rows = [];
    if (warningCount > 0) {
      rows.add(
        _alertRow(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.grey.shade600,
          label: tr('dashboard.warning_alerts'),
          count: warningCount,
        ),
      );
    }
    if (faultCount > 0) {
      rows.add(
        _alertRow(
          icon: Icons.error_outline_rounded,
          iconColor: Colors.grey.shade600,
          label: tr('dashboard.fault_alerts'),
          count: faultCount,
        ),
      );
    }
    if (clearedCount > 0) {
      rows.add(
        _alertRow(
          icon: Icons.check_circle_outline_rounded,
          iconColor: Colors.grey.shade600,
          label: tr('dashboard.cleared_alerts'),
          count: clearedCount,
        ),
      );
    }

    final List<Widget> children = [];
    for (int i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade100,
            indent: 14,
            endIndent: 14,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_none_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              tr('dashboard.active_alerts'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15,letterSpacing: 0),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: hasAny
              ? Column(children: children)
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr('dashboard.no_active_alerts'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _alertRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5E5E5E),
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            count.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
        ],
      ),
    );
  }
}