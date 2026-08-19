import 'package:flutter/material.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/packet_formatter.dart';

class PacketLogScreen extends StatefulWidget {
  final BMSBluetoothService service;

  const PacketLogScreen({super.key, required this.service});

  @override
  State<PacketLogScreen> createState() => _PacketLogScreenState();
}

class _PacketLogScreenState extends State<PacketLogScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packets = widget.service.packetLog;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Packet Log'),
        backgroundColor: const Color(0xFF1B6B3A),
        actions: [
          IconButton(
            onPressed: widget.service.clearPacketLog,
            icon: const Icon(Icons.clear_all_rounded),
            tooltip: 'Clear packet log',
          ),
        ],
      ),
      body: packets.isEmpty
          ? const Center(
              child: Text(
                'No packet activity yet.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: packets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final packet = packets[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showPacketDetails(context, packet),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${packet.directionLabel} • ${packet.typeName}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                BMSPacketFormatter.timeString(packet.receivedAt),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            BMSPacketFormatter.toHexDump(packet.rawBytes),
                            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showPacketDetails(BuildContext context, packet) {
    final detailText = BMSPacketFormatter.toFullDetail(packet);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${packet.directionLabel} • ${packet.typeName}'),
        content: SingleChildScrollView(
          child: SelectableText(detailText, style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
