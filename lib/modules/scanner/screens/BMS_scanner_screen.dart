// lib/screens/bluetooth_device_scan_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'package:bmsmobileapp/core/theme/app_colors.dart';
import 'package:bmsmobileapp/core/theme/app_spacing.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import '../../../modules/dashboard/screens/dashboard_screen.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/token_service.dart';
import 'package:bmsmobileapp/services/auth_service.dart';
import 'package:bmsmobileapp/core/api/routes/app_router.dart';
import 'package:bmsmobileapp/database/paired_devices_db.dart';
// Removed import of nonexistent debug_log_overlay.dart to fix missing URI error

// ─────────────────────────────────────────────────────────────
// Signal-strength helper widget  (matches Figma bar icon)
// ─────────────────────────────────────────────────────────────
class _SignalBars extends StatelessWidget {
  final int rssi; // e.g. -55
  const _SignalBars({required this.rssi});

  /// Returns 1-4 bars based on RSSI value
  int get _bars {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    const filledColor = Color(0xFF424242);
    const unfilledColor = Color(0xFFD6D6D6);
    const totalBars = 4;
    const barWidth = 3.5;
    const barSpacing = 1.5;
    const maxHeight = 11.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(totalBars, (i) {
        final filled = i < bars;
        final height = maxHeight * ((i + 1) / totalBars);
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : barSpacing),
          child: Container(
            width: barWidth,
            height: height,
            decoration: BoxDecoration(
              color: filled ? filledColor : unfilledColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/// Compact "Signal Strength  [bars]  –55 dBm" row
class _SignalStrengthRow extends StatelessWidget {
  final int rssi;
  const _SignalStrengthRow({required this.rssi});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TranslationService.t('scan.signal_strength'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
        ),
        const SizedBox(width: 6),
        _SignalBars(rssi: rssi),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────

class BluetoothDeviceScanPage extends StatefulWidget {
  final BMSBluetoothService service;
  const BluetoothDeviceScanPage({super.key, required this.service});

  @override
  State<BluetoothDeviceScanPage> createState() => _BluetoothDeviceScanPageState();
}

class _BluetoothDeviceScanPageState extends State<BluetoothDeviceScanPage> {
  List<BluetoothDevice> _devices = [];

  /// RSSI map: device remoteId.str → latest RSSI value
  final Map<String, int> _rssiMap = {};

  bool _isScanning = false;
  StreamSubscription? _scanSub;
  StreamSubscription? _scanStateSub;

  String? _connectingDeviceId;
  bool _isPairing = false;
  bool _dashboardOpened = false;
  // Previously used to store selected paired battery serial. Removed as unused.

  final TokenService _tokenService = TokenService();
  final PairedDevicesDB _pairedDevicesDB = PairedDevicesDB();
  List<PairedDevice> _pairedDevices = [];

  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
    TranslationService.instance.addListener(_onTranslationsChanged);
    _listenScan();
    _loadPairedDevices();
  }

  Future<void> _loadPairedDevices() async {
    final devices = await _pairedDevicesDB.getAllDevices();
    if (mounted) {
      setState(() {
        _pairedDevices = devices;
      });
    }
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

 void _onServiceChanged() {
  if (!mounted) return;
  debugPrint('state=${widget.service.state}');

  setState(() {});

  if (widget.service.readyForDashboard && !_dashboardOpened) {
    _dashboardOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigateToDashboard();
      }
    });
  }
}
  void _listenScan() {
    _scanSub?.cancel();
    _scanStateSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      final filtered = results.where((r) {
        final name = r.device.platformName.toLowerCase();
        return name.isNotEmpty && name.startsWith('');
      }).toList();

      setState(() {
        _devices = filtered.map((r) => r.device).toList();
        // Update RSSI map for every result
        for (final r in filtered) {
          _rssiMap[r.device.remoteId.str] = r.rssi;
        }
      });
    });

    _scanStateSub = FlutterBluePlus.isScanning.listen((s) {
      if (!mounted) return;
      setState(() => _isScanning = s);
    });
  }

  Future<void> _startScan() async {
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses.values.any((status) => !status.isGranted)) {
        _showSnackBar(tr('scan.permissions_denied'), isError: true);
        return;
      }

      if (!mounted) return;
      setState(() {
        _devices = [];
        _rssiMap.clear();
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  Future<void> _onConnect(BluetoothDevice d) async {
    try {
      setState(() => _connectingDeviceId = d.remoteId.str);
      await widget.service.connect(d);
      
      // Automatically save device to paired devices on successful connection
      final isAlreadyPaired = await _pairedDevicesDB.isDevicePaired(d.remoteId.str);
      if (!isAlreadyPaired) {
        await _pairDeviceLocally(d);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connectingDeviceId = null);
        _showSnackBar(e.toString(), isError: true);
      }
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _tokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(tr('logout.title')),
          ],
        ),
        content: Text(tr('logout.confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('logout.cancel'),
                style: const TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('logout.confirm_button')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AppRouter.bmsService
          .disconnect()
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      await AuthService.clearTokens();
      await TokenService().clearAll();
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (e) {
      if (kDebugMode) print('Logout error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _pairDevice(String batterySerial) async {
    if (_isPairing || batterySerial.isEmpty) return;
    setState(() => _isPairing = true);
    _showSnackBar('Pairing device...');

    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('http://15.207.26.224:3030/api/connect/paired-device'),
            headers: headers,
            body: jsonEncode({'batterySerialNo': batterySerial}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar('Device paired successfully', isError: false);
        if (mounted) _navigateToDashboard();
      } else {
        _showSnackBar(
            data['message']?.toString() ?? 'Pairing failed',
            isError: true);
      }
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  Future<void> _pairDeviceLocally(BluetoothDevice device) async {
    final pairedDevice = PairedDevice(
      deviceId: device.remoteId.str,
      name: device.platformName.isEmpty ? 'Unknown Device' : device.platformName,
      macAddress: device.remoteId.str,
      pairedAt: DateTime.now(),
    );
    
    await _pairedDevicesDB.insertDevice(pairedDevice);
    await _loadPairedDevices();
    _showSnackBar('Device paired locally', isError: false);
  }

  Future<void> _unpairDevice(String deviceId) async {
    await _pairedDevicesDB.deleteDevice(deviceId);
    await _loadPairedDevices();
    _showSnackBar('Device unpaired', isError: false);
  }


  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: DashboardScreen(service: widget.service)),
      (route) => false,
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppColors.error : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(tr('scan.title'),
            style:
                theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white),
            tooltip: tr('logout.title'),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _ScanTab(
        devices: _devices,
        pairedDevices: _pairedDevices,
        rssiMap: _rssiMap,
        isScanning: _isScanning,
        onScan: _startScan,
        onConnect: _onConnect,
        onPair: _pairDeviceLocally,
        onUnpair: _unpairDevice,
        service: widget.service,
        connectingDeviceId: _connectingDeviceId,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SCAN TAB
// ═══════════════════════════════════════════════════════════════
class _ScanTab extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final List<PairedDevice> pairedDevices;
  final Map<String, int> rssiMap;
  final bool isScanning;
  final VoidCallback onScan;
  final ValueChanged<BluetoothDevice> onConnect;
  final ValueChanged<BluetoothDevice> onPair;
  final ValueChanged<String> onUnpair;
  final BMSBluetoothService service;
  final String? connectingDeviceId;

  const _ScanTab({
    required this.devices,
    required this.pairedDevices,
    required this.rssiMap,
    required this.isScanning,
    required this.onScan,
    required this.onConnect,
    required this.onPair,
    required this.onUnpair,
    required this.service,
    required this.connectingDeviceId,
  });

  String tr(String key) => TranslationService.t(key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter out devices that are already paired
    final availableDevices = devices.where((d) => 
      !pairedDevices.any((pd) => pd.deviceId == d.remoteId.str)
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bluetooth Device Scan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr('Search and connect to your battery'),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
        // _ConnectionStateBanner(state: service.state),
        const SizedBox(height: AppSpacing.sm),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: isScanning ? null : onScan,
              icon: isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black54))
                  : const Icon(Icons.crop_free, size: 20, color: Colors.black87),
              label: Text(
                (isScanning
                        ? tr('scan.scanning')
                        : tr('scan.scan_button'))
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.4,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // ── Paired Devices section ───────────────────
              if (pairedDevices.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Paired Devices',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                ...pairedDevices.map((d) => _buildPairedDeviceTile(d, context)),
                const SizedBox(height: 16),
              ],
              
              // ── Available Devices section ───────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr('scan.available_devices'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),

              if (availableDevices.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      Icon(Icons.bluetooth_disabled,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text(tr('scan.no_devices'),
                          style:
                              const TextStyle(color: Color(0xFF9E9E9E))),
                    ],
                  ),
                )
              else
                ...availableDevices.map((d) => _buildDeviceTile(d, context)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Available (scanned) device tile ────────────────────────
  Widget _buildDeviceTile(BluetoothDevice d, BuildContext context) {
    final isThis = service.device?.remoteId == d.remoteId;
    final isBusy = connectingDeviceId == d.remoteId.str;
    final rssi = rssiMap[d.remoteId.str];
    final isPaired = pairedDevices.any((pd) => pd.deviceId == d.remoteId.str);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Bluetooth icon box
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bluetooth,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),

            // Name + MAC + signal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.platformName.isEmpty
                        ? tr('scan.unknown_device')
                        : d.platformName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 1),
                  if (rssi != null) _SignalStrengthRow(rssi: rssi),
                ],
              ),
            ),

            // Action
            isBusy
                ? _StatusChip(
                    label: _chipLabel(service.state),
                    color: _chipColor(service.state),
                    loading: true)
                : isThis && service.state == BMSConnectionState.ready
                    ? _StatusChip(
                        label: tr('scan.authenticated'),
                        color: Colors.green)
                    : isPaired
                        ? _StatusChip(
                            label: 'Paired',
                            color: Colors.green)
                        : ElevatedButton(
                            onPressed: () => onConnect(d),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3A6EAC),
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(tr('scan.connect'), style: const TextStyle(fontSize: 14)),
                          ),
          ],
        ),
      ),
    );
  }

  // ── Paired device tile ────────────────────────
  Widget _buildPairedDeviceTile(PairedDevice device, BuildContext context) {
    final isThis = service.device?.remoteId.str == device.deviceId;
    final isBusy = connectingDeviceId == device.deviceId;
    final isInScanList = devices.any((d) => d.remoteId.str == device.deviceId);
    final rssi = rssiMap[device.deviceId];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Bluetooth icon box
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bluetooth,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),

            // Name + Signal Strength
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 1),
                  if (rssi != null)
                    _SignalStrengthRow(rssi: rssi)
                  else
                    const Text(
                      'Not in range',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF757575)),
                    ),
                ],
              ),
            ),

            // Action
            isBusy
                ? _StatusChip(
                    label: _chipLabel(service.state),
                    color: _chipColor(service.state),
                    loading: true)
                : isThis && service.state == BMSConnectionState.ready
                    ? _StatusChip(
                        label: tr('scan.authenticated'),
                        color: Colors.green)
                    : isInScanList
                        ? ElevatedButton(
                            onPressed: () {
                              final bluetoothDevice = devices.firstWhere(
                                (d) => d.remoteId.str == device.deviceId,
                              );
                              onConnect(bluetoothDevice);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3A6EAC),
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(tr('scan.connect'), style: const TextStyle(fontSize: 14)),
                          )
                        : TextButton(
                            onPressed: onScan,
                            child: Text('Scan to connect', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
          ],
        ),
      ),
    );
  }

  String _chipLabel(BMSConnectionState s) {
    switch (s) {
      case BMSConnectionState.connecting:
        return tr('scan.state_connecting');
      case BMSConnectionState.discovering:
        return tr('scan.state_discovering');
      case BMSConnectionState.handshakeSent:
        return tr('scan.state_handshake');
      case BMSConnectionState.waitingAck:
        return tr('scan.state_validating_ack');
      default:
        return tr('scan.state_connecting');
    }
  }

  Color _chipColor(BMSConnectionState s) {
    switch (s) {
      case BMSConnectionState.waitingAck:
        return Colors.purple;
      case BMSConnectionState.handshakeSent:
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// CONNECTION STATE BANNER  (unchanged)
// ═══════════════════════════════════════════════════════════════
class _ConnectionStateBanner extends StatelessWidget {
  final BMSConnectionState state;
  const _ConnectionStateBanner({required this.state});

  String tr(String key) => TranslationService.t(key);

  @override
  Widget build(BuildContext context) {
    final (String msg, Color bg, IconData icon) = switch (state) {
      BMSConnectionState.ready =>
        (tr('scan.banner_ready'), const Color(0xFFE8F5E9), Icons.verified_user),
      BMSConnectionState.handshakeSent =>
        (tr('scan.banner_handshake'), const Color(0xFFFFF8E1), Icons.sync),
      BMSConnectionState.waitingAck =>
        (tr('scan.banner_waiting_ack'), const Color(0xFFEDE7F6), Icons.shield_outlined),
      BMSConnectionState.connecting =>
        (tr('scan.banner_connecting'), const Color(0xFFE3F2FD), Icons.bluetooth_searching),
      _ => (tr('scan.banner_connecting'), const Color(0xFFE3F2FD), Icons.bluetooth_searching),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STATUS CHIP  (unchanged)
// ═══════════════════════════════════════════════════════════════
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  

  const _StatusChip(
      {required this.label, required this.color, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color))
          else
            Icon(Icons.check_circle, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

