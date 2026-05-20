// lib/screens/bluetooth_device_scan_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/packet_formatter.dart';
import 'package:bmsmobileapp/services/parsed_packet.dart';
import 'package:bmsmobileapp/services/protocol.dart';
import 'package:bmsmobileapp/screens/dashboard.dart';
import 'package:bmsmobileapp/utils/slide_route.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BluetoothDeviceScanPage
// ─────────────────────────────────────────────────────────────────────────────
class BluetoothDeviceScanPage extends StatefulWidget {
  final BMSBluetoothService service;
  const BluetoothDeviceScanPage({super.key, required this.service});

  @override
  State<BluetoothDeviceScanPage> createState() =>
      _BluetoothDeviceScanPageState();
}

class _BluetoothDeviceScanPageState extends State<BluetoothDeviceScanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSub;
  StreamSubscription? _scanStateSub;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.service.addListener(_onServiceChanged);
    _listenScan();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});

    // ── ACK validated successfully → redirect to Dashboard ─────────────────
    if (widget.service.state == BMSConnectionState.ready) {
      _navigateToDashboard();
    }

    // ── ACK mismatch or any other error → show SnackBar, stay on page ───────
    if (widget.service.state == BMSConnectionState.error &&
        widget.service.errorMessage != null) {
      _connectingDeviceId = null;
      _showSnackBar(widget.service.errorMessage!, isError: true);
    }
  }

  void _listenScan() {
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _devices = results
            .where((r) => r.device.name.isNotEmpty)
            .map((r) => r.device)
            .toList();
      });
    });

    _scanStateSub = FlutterBluePlus.isScanning.listen((s) {
      setState(() => _isScanning = s);
    });
  }

  Future<void> _startScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    setState(() => _devices = []);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  Future<void> _onConnect(BluetoothDevice d) async {
    setState(() => _connectingDeviceId = d.remoteId.str);
    await widget.service.connect(d);
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideRoute(page: const DashboardScreen()),
      (route) => false,
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF1B6B3A),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        title: const Text('BMS Scanner', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth_searching), text: 'Scan'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Packets'),
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
          ),
          _PacketLogTab(service: widget.service),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — SCAN
// ─────────────────────────────────────────────────────────────────────────────
class _ScanTab extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final bool isScanning;
  final VoidCallback onScan;
  final ValueChanged<BluetoothDevice> onConnect;
  final BMSBluetoothService service;
  final String? connectingDeviceId;

  const _ScanTab({
    required this.devices,
    required this.isScanning,
    required this.onScan,
    required this.onConnect,
    required this.service,
    required this.connectingDeviceId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConnectionStateBanner(state: service.state),
        const SizedBox(height: 8),

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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.radar),
              label: Text(isScanning ? 'Scanning…' : 'Scan for Devices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B6B3A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),

        Expanded(
          child: devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_disabled,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('No devices found',
                          style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: devices.length,
                  itemBuilder: (_, i) {
                    final d = devices[i];
                    final isThis = service.device?.remoteId == d.remoteId;
                    final isBusy = connectingDeviceId == d.remoteId.str;

                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(
                        d.name.isEmpty ? 'Unknown' : d.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(d.remoteId.str,
                          style: const TextStyle(fontSize: 12)),
                      trailing: isBusy
                          ? _StatusChip(
                              label: _chipLabel(service.state),
                              color: _chipColor(service.state),
                              loading: true,
                            )
                          : isThis && service.state == BMSConnectionState.ready
                              ? const _StatusChip(
                                  label: 'Authenticated',
                                  color: Colors.green,
                                )
                              : ElevatedButton(
                                  onPressed: () => onConnect(d),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B6B3A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text('Connect'),
                                ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _chipLabel(BMSConnectionState s) {
    switch (s) {
      case BMSConnectionState.connecting:
        return 'Connecting…';
      case BMSConnectionState.discovering:
        return 'Discovering…';
      case BMSConnectionState.handshakeSent:
        return 'Handshake…';
      case BMSConnectionState.waitingAck:
        return 'Validating ACK…';
      default:
        return 'Connecting…';
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — PACKET LOG
// Shows every TX and RX packet in real time using AnimatedBuilder.
// ─────────────────────────────────────────────────────────────────────────────
class _PacketLogTab extends StatelessWidget {
  final BMSBluetoothService service;
  const _PacketLogTab({required this.service});

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
                Text('No packets yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                const SizedBox(height: 8),
                Text('Sent and received packets will appear here',
                    style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          reverse: true, // newest packets at bottom, scroll down to see latest
          itemCount: service.packetLog.length,
          itemBuilder: (_, i) => _PacketCard(packet: service.packetLog[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PACKET CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PacketCard extends StatelessWidget {
  final BMSParsedPacket packet;
  const _PacketCard({required this.packet});

  /// TX = green-teal, RX = blue, unknown = grey
  Color get _directionColor {
    if (packet.direction == PacketDirection.send) return const Color(0xFF1B6B3A);
    if (packet.direction == PacketDirection.receive) return Colors.blueAccent;
    return Colors.grey;
  }

  /// ACK gets a gold accent regardless of direction
  Color get _accentColor {
    if (packet.isAck) return Colors.amber.shade700;
    if (packet.isDisconnect) return Colors.red;
    if (packet.isHandshake) return const Color(0xFF1B6B3A);
    return _directionColor;
  }

  IconData get _directionIcon {
    if (packet.direction == PacketDirection.send) return Icons.arrow_upward;
    if (packet.direction == PacketDirection.receive) return Icons.arrow_downward;
    return Icons.swap_horiz;
  }

  @override
  Widget build(BuildContext context) {
    final fields = BMSPacketFormatter.toFieldMap(packet);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _accentColor.withOpacity(0.4)),
      ),
      child: ExpansionTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Direction arrow
            Icon(_directionIcon, size: 14, color: _directionColor),
            const SizedBox(height: 2),
            // Data ID badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                BMSProtocol.dataIdName(packet.dataId),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _accentColor),
              ),
            ),
          ],
        ),
        title: Text(
          BMSPacketFormatter.toHexDump(packet.rawBytes),
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
        subtitle: Row(
          children: [
            Icon(_directionIcon, size: 11, color: _directionColor),
            const SizedBox(width: 4),
            Text(
              '${packet.directionLabel}  •  ${fields['Time'] ?? ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: fields.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(e.key,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ),
                        Expanded(
                          child: Text(e.value,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONNECTION STATE BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _ConnectionStateBanner extends StatelessWidget {
  final BMSConnectionState state;
  const _ConnectionStateBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final (String msg, Color bg, IconData icon) = switch (state) {
      BMSConnectionState.ready => (
        '✅  ACK Validated — Connection Authenticated',
        const Color(0xFFE8F5E9),
        Icons.verified_user
      ),
      BMSConnectionState.handshakeSent => (
        'Sending handshake…',
        const Color(0xFFFFF8E1),
        Icons.sync
      ),
      BMSConnectionState.waitingAck => (
        'Validating ACK from device…',
        const Color(0xFFEDE7F6),
        Icons.shield_outlined
      ),
      BMSConnectionState.connecting => (
        'Connecting to device…',
        const Color(0xFFE3F2FD),
        Icons.bluetooth_searching
      ),
      BMSConnectionState.discovering => (
        'Discovering services…',
        const Color(0xFFE3F2FD),
        Icons.manage_search
      ),
      BMSConnectionState.error => (
        'Connection failed — ACK mismatch or error',
        const Color(0xFFFFEBEE),
        Icons.error_outline
      ),
      BMSConnectionState.disconnecting => (
        'Disconnecting…',
        const Color(0xFFF5F5F5),
        Icons.link_off
      ),
      _ => (
        'Not connected — tap Scan',
        const Color(0xFFF5F5F5),
        Icons.bluetooth_disabled
      ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;

  const _StatusChip({
    required this.label,
    required this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
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