// lib/screens/alert_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:bmsmobileapp/services/bluetooth_service.dart';
import 'package:bmsmobileapp/services/parsed_packet.dart';
import 'package:bmsmobileapp/services/translation_service.dart';

class AlertDetailScreen extends StatelessWidget {
  final BMSBluetoothService service;
  final BMSParsedPacket packet;
  final Color alertStatusColor;

  const AlertDetailScreen({
    super.key,
    required this.service,
    required this.packet,
    required this.alertStatusColor,
  });

  String tr(String key) => TranslationService.t(key);

  // Ordered list of (label, value) pairs pulled straight from the parsed
  // Alerts Details Response (dataId 0x56) — no re-derivation, just display.
  List<MapEntry<String, String>> get _rows => [
        MapEntry('Cycle count', '${packet.alertCycleCount ?? '–'}'),
        MapEntry('Cycle time @ Fault', '${packet.alertCycleTimeAtFault ?? '–'} sec'),
        MapEntry('Battery status @ Fault', packet.alertBatteryStatusLabel),
        MapEntry('Failure time', packet.alertFailureTimestampDisplay),
        MapEntry('Fault ID', packet.alertNameLabel),
        MapEntry('Fault action', packet.alertFaultActionLabel),
        MapEntry('Total voltage', packet.alertTotalVoltageDisplay),
        MapEntry('Current', packet.alertCurrentDisplay),
        MapEntry('SOC', packet.alertSocDisplay),
        MapEntry('Max cell voltage', packet.alertMaxCellVoltageDisplay),
        MapEntry('Max cell voltage position', '${packet.alertMaxCellVoltagePos ?? '–'}'),
        MapEntry('Min cell voltage', packet.alertMinCellVoltageDisplay),
        MapEntry('Min cell voltage position', '${packet.alertMinCellVoltagePos ?? '–'}'),
        MapEntry('Max temperature', packet.alertMaxTempDisplay),
        MapEntry('Max temperature position', '${packet.alertMaxTempPos ?? '–'}'),
        MapEntry('Min temperature', packet.alertLowestTempDisplay),
        MapEntry('Min temperature position', '${packet.alertMinTempPos ?? '–'}'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B3A),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('alerts').toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              service.bleName ?? service.batterySerial ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'disconnect', child: Text(tr('disconnect'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: alertStatusColor),
              const SizedBox(width: 8),
              Text(
                packet.alertNameLabel,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: alertStatusColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF3A6EAC),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text('Parameters',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5)),
                      ),
                      Text('Value',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5)),
                    ],
                  ),
                ),
                for (int i = 0; i < _rows.length; i++)
                  Container(
                    color: i.isEven ? const Color(0xFFF7F7F7) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _rows[i].key,
                            style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                          ),
                        ),
                        Text(
                          _rows[i].value,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.black),
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