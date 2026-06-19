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
import 'package:bmsmobileapp/services/packet_formatter.dart';
import 'package:bmsmobileapp/services/parsed_packet.dart';
import 'package:bmsmobileapp/services/protocol.dart';
import 'package:bmsmobileapp/screens/dashboard.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';
import 'package:bmsmobileapp/services/translation_service.dart';
import 'package:bmsmobileapp/services/token_service.dart';
import 'package:bmsmobileapp/services/auth_service.dart';
import 'package:bmsmobileapp/core/api/routes/app_router.dart';

class PairedDevice {
  final String deviceId;
  final String deviceName;
  final DateTime pairedAt;

  PairedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.pairedAt,
  });

  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    final pairedAt = DateTime.tryParse(json['pairedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return PairedDevice(
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      pairedAt: pairedAt,
    );
  }
}

class BluetoothDeviceScanPage extends StatefulWidget {
  final BMSBluetoothService service;
  const BluetoothDeviceScanPage({super.key, required this.service});

  @override
  State<BluetoothDeviceScanPage> createState() => _BluetoothDeviceScanPageState();
}

class _BluetoothDeviceScanPageState extends State<BluetoothDeviceScanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSub;
  StreamSubscription? _scanStateSub;

  String? _connectingDeviceId;
  bool _isPairing = false;
  String? _pairedBatterySerial;

  List<PairedDevice> _pairedDevices = [];
  bool _isLoadingPairedDevices = false;
  String? _pairedDevicesError;

  final TokenService _tokenService = TokenService();

  String tr(String key) => TranslationService.t(key);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.service.addListener(_onServiceChanged);
    TranslationService.instance.addListener(_onTranslationsChanged);
    _listenScan();
    _fetchPairedDevices();
  }

  void _onTranslationsChanged() {
    if (mounted) setState(() {});
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});

    if (widget.service.state == BMSConnectionState.ready) {
      final serial = widget.service.batterySerial?.trim();
      if (serial != null && serial.isNotEmpty) {
        if (serial == _pairedBatterySerial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateToDashboard();
          });
        } else if (!_isPairing) {
          _pairDevice(serial);
        }
      }
    }

    if (widget.service.state == BMSConnectionState.error &&
        widget.service.errorMessage != null) {
      _connectingDeviceId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnackBar(widget.service.errorMessage!, isError: true);
      });
    }
  }

  void _listenScan() {
    _scanSub?.cancel();
    _scanStateSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _devices = results
            .where((r) {
              final name = r.device.platformName.toLowerCase();
              return name.isNotEmpty && name.startsWith('mch');
            })
            .map((r) => r.device)
            .toList();
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
      setState(() => _devices = []);
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  Future<void> _onConnect(BluetoothDevice d) async {
    try {
      setState(() => _connectingDeviceId = d.remoteId.str);
      await widget.service.connect(d);
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
            child: Text(tr('logout.cancel'), style: const TextStyle(color: Colors.black54)),
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
      await AppRouter.bmsService.disconnect().timeout(const Duration(seconds: 2), onTimeout: () => null);
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
      final response = await http.post(
        Uri.parse('http://15.207.26.224:3030/api/connect/paired-device'),
        headers: headers,
        body: jsonEncode({'batterySerialNo': batterySerial}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _pairedBatterySerial = batterySerial;
        _showSnackBar('Device paired successfully', isError: false);
        if (mounted) _navigateToDashboard();
      } else {
        _showSnackBar(data['message']?.toString() ?? 'Pairing failed', isError: true);
      }
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  Future<void> _fetchPairedDevices({bool isRefresh = false}) async {
    if (_isLoadingPairedDevices) return;

    // Clear existing list immediately when refreshing so stale data disappears right away
    setState(() {
      _isLoadingPairedDevices = true;
      _pairedDevicesError = null;
      if (isRefresh) _pairedDevices = [];
    });

    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://15.207.26.224:3030/api/connect/paired-devices'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final devices = (data['data'] as List?)
                ?.map((e) => PairedDevice.fromJson(e))
                .toList() ??
            [];
        if (mounted) setState(() => _pairedDevices = devices);
      } else {
        if (mounted) {
          setState(() => _pairedDevicesError =
              data['message']?.toString() ?? 'Failed to load paired devices');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _pairedDevicesError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingPairedDevices = false);
    }
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
        backgroundColor: isError ? AppColors.error : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    TranslationService.instance.removeListener(_onTranslationsChanged);
    FlutterBluePlus.stopScan();
    _tabController.dispose();
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
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white),
            tooltip: tr('logout.title'),
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: const Icon(Icons.bluetooth_searching), text: tr('scan.tab_scan')),
            Tab(icon: const Icon(Icons.receipt_long), text: tr('scan.tab_packets')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ScanTab(
            devices: _devices,
            isScanning: _isScanning,
            onScan: _startScan,
            onConnect: _onConnect,
            service: widget.service,
            connectingDeviceId: _connectingDeviceId,
            pairedDevices: _pairedDevices,
            isLoadingPairedDevices: _isLoadingPairedDevices,
            pairedDevicesError: _pairedDevicesError,
            // Pass isRefresh: true so old devices are cleared before reload
            onRefreshPairedDevices: () => _fetchPairedDevices(isRefresh: true),
          ),
          _PacketLogTab(service: widget.service),
        ],
      ),
    );
  }
}

// ================= SCAN TAB =================
class _ScanTab extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final bool isScanning;
  final VoidCallback onScan;
  final ValueChanged<BluetoothDevice> onConnect;
  final BMSBluetoothService service;
  final String? connectingDeviceId;
  final List<PairedDevice> pairedDevices;
  final bool isLoadingPairedDevices;
  final String? pairedDevicesError;
  final Future<void> Function() onRefreshPairedDevices;

  const _ScanTab({
    required this.devices,
    required this.isScanning,
    required this.onScan,
    required this.onConnect,
    required this.service,
    required this.connectingDeviceId,
    required this.pairedDevices,
    required this.isLoadingPairedDevices,
    required this.pairedDevicesError,
    required this.onRefreshPairedDevices,
  });

  String tr(String key) => TranslationService.t(key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _ConnectionStateBanner(state: service.state),
        const SizedBox(height: AppSpacing.sm),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: isScanning ? null : onScan,
              icon: isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.radar),
              label: Text(isScanning ? tr('scan.scanning') : tr('scan.scan_button')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (pairedDevices.isNotEmpty || isLoadingPairedDevices || pairedDevicesError != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Text(tr('paired_devices'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        onPressed: isLoadingPairedDevices ? null : onRefreshPairedDevices,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                ),
                if (isLoadingPairedDevices)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (!isLoadingPairedDevices && pairedDevicesError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(pairedDevicesError!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                if (!isLoadingPairedDevices && pairedDevicesError == null)
                  ...pairedDevices.map((device) => _buildPairedDeviceTile(device, context)),
                const SizedBox(height: 24),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr('scan.available_devices'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),

              if (devices.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_disabled, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text(tr('scan.no_devices'),
                          style: const TextStyle(color: Color(0xFF9E9E9E))),
                    ],
                  ),
                )
              else
                ...devices.map((d) => _buildDeviceTile(d, context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPairedDeviceTile(PairedDevice device, BuildContext context) {
    final isThis = service.device?.remoteId.str == device.deviceId;
    final isBusy = connectingDeviceId == device.deviceId;

    return ListTile(
      leading: const Icon(Icons.battery_charging_full, color: AppColors.primaryGreen),
      title: Text(device.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: isBusy
          ? _StatusChip(
              label: _chipLabel(service.state),
              color: _chipColor(service.state),
              loading: true)
          : isThis && service.state == BMSConnectionState.ready
              ? _StatusChip(label: tr('scan.authenticated'), color: Colors.green)
              : ElevatedButton(
                  onPressed: () {
                    try {
                      final d = devices.firstWhere(
                          (dev) => dev.remoteId.str == device.deviceId);
                      onConnect(d);
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr('scan.device_not_in_range')),
                        backgroundColor: AppColors.error,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(tr('scan.connect')),
                ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice d, BuildContext context) {
    final isThis = service.device?.remoteId == d.remoteId;
    final isBusy = connectingDeviceId == d.remoteId.str;

    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: Text(
        d.platformName.isEmpty ? tr('scan.unknown_device') : d.platformName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(d.remoteId.str, style: const TextStyle(fontSize: 12)),
      trailing: isBusy
          ? _StatusChip(
              label: _chipLabel(service.state),
              color: _chipColor(service.state),
              loading: true)
          : isThis && service.state == BMSConnectionState.ready
              ? _StatusChip(label: tr('scan.authenticated'), color: Colors.green)
              : ElevatedButton(
                  onPressed: () => onConnect(d),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(tr('scan.connect')),
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

class _PacketLogTab extends StatelessWidget {
  final BMSBluetoothService service;
  const _PacketLogTab({required this.service});

  String tr(String key) => TranslationService.t(key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (service.packetLog.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(tr('scan.no_packets'),
                    style: const TextStyle(fontSize: 18, color: Color(0xFF9E9E9E))),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          reverse: true,
          itemCount: service.packetLog.length,
          itemBuilder: (_, i) => _PacketCard(packet: service.packetLog[i]),
        );
      },
    );
  }
}

class _PacketCard extends StatelessWidget {
  final BMSParsedPacket packet;
  const _PacketCard({required this.packet});

  @override
  Widget build(BuildContext context) {
    final fields = BMSPacketFormatter.toFieldMap(packet);
    final isSend = packet.direction == PacketDirection.send;
    final color = isSend ? AppColors.primaryGreen : Colors.blueAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: ExpansionTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSend ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14, color: color),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(BMSProtocol.dataIdName(packet.dataId),
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
        title: Text(BMSPacketFormatter.toHexDump(packet.rawBytes),
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            Icon(isSend ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              '${packet.directionLabel}  •  ${fields[TranslationService.t('scan.packet_field_time')] ?? fields['Time'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: fields.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 80,
                                child: Text(e.key,
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF9E9E9E)))),
                            Expanded(
                                child: Text(e.value,
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;

  const _StatusChip({required this.label, required this.color, this.loading = false});

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
                child: CircularProgressIndicator(strokeWidth: 2, color: color))
          else
            Icon(Icons.check_circle, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}