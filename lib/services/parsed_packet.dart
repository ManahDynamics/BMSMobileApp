// lib/services/parsed_packet.dart

import 'dart:typed_data';

enum PacketDirection { send, receive, unknown }

class BMSParsedPacket {
  // ── Common fields (all packets) ───────────────────────────────────────────
  final int startByte;
  final int length;
  final int dataId;
  final int crc;
  final int stopByte;
  final Uint8List rawBytes;
  final DateTime receivedAt;
  final PacketDirection direction;

  // ── Packet 4 fields (dataId == 0x51) ─────────────────────────────────────
  final double? totalVoltage;
  final double? totalCurrent;
  final int?    soc;
  final double? remainingCapacity;

  const BMSParsedPacket({
    required this.startByte,
    required this.length,
    required this.dataId,
    required this.crc,
    required this.stopByte,
    required this.rawBytes,
    required this.receivedAt,
    this.direction = PacketDirection.unknown,
    this.totalVoltage,
    this.totalCurrent,
    this.soc,
    this.remainingCapacity,
  });

  // ── Convenience flags ─────────────────────────────────────────────────────

  // FIX: dataId changed from 0x90 → 0x50 to match actual ACK packet
  // ACK packet from device: 0xAA 0x05 0x50 xx 0xBB
  bool get isAck =>
      startByte == 0xAA && stopByte == 0xBB && dataId == 0x50;

  bool get isDisconnect =>
      dataId == 0x91;

  bool get isHandshake =>
      dataId == 0x90 && startByte == 0xCC;

  bool get isPacket4 =>
      dataId == 0x51 && totalVoltage != null;

  // ── Direction label for UI/log display ───────────────────────────────────
  String get directionLabel {
    switch (direction) {
      case PacketDirection.send:    return 'TX';
      case PacketDirection.receive: return 'RX';
      case PacketDirection.unknown: return '??';
    }
  }

  // ── Formatted display strings ─────────────────────────────────────────────
  String get voltageDisplay         => totalVoltage      != null ? '${totalVoltage!.toStringAsFixed(1)} V'       : '– V';
  String get currentDisplay         => totalCurrent      != null ? '${totalCurrent!.toStringAsFixed(1)} A'       : '– A';
  String get socDisplay             => soc               != null ? '$soc %'                                       : '– %';
  String get capacityDisplay        => remainingCapacity != null ? '${remainingCapacity!.toStringAsFixed(1)} Ah' : '– Ah';

  // ── Human-readable type name for logs ─────────────────────────────────────
  // FIX: split 0x90 / 0x50 into separate cases — 0x90 = HANDSHAKE, 0x50 = ACK
  String get typeName {
    switch (dataId) {
      case 0x90: return 'HANDSHAKE';
      case 0x50: return 'ACK';
      case 0x91: return 'DISCONNECT';
      case 0x51: return 'Packet4 (SOC/Voltage/Current)';
      default:
        return 'Unknown (0x${dataId.toRadixString(16).toUpperCase().padLeft(2, "0")})';
    }
  }

  // ── copyWith ──────────────────────────────────────────────────────────────
  BMSParsedPacket copyWith({
    int?             startByte,
    int?             length,
    int?             dataId,
    int?             crc,
    int?             stopByte,
    Uint8List?       rawBytes,
    DateTime?        receivedAt,
    PacketDirection? direction,
    double?          totalVoltage,
    double?          totalCurrent,
    int?             soc,
    double?          remainingCapacity,
  }) {
    return BMSParsedPacket(
      startByte:         startByte         ?? this.startByte,
      length:            length            ?? this.length,
      dataId:            dataId            ?? this.dataId,
      crc:               crc               ?? this.crc,
      stopByte:          stopByte          ?? this.stopByte,
      rawBytes:          rawBytes          ?? this.rawBytes,
      receivedAt:        receivedAt        ?? this.receivedAt,
      direction:         direction         ?? this.direction,
      totalVoltage:      totalVoltage      ?? this.totalVoltage,
      totalCurrent:      totalCurrent      ?? this.totalCurrent,
      soc:               soc               ?? this.soc,
      remainingCapacity: remainingCapacity ?? this.remainingCapacity,
    );
  }

  @override
  String toString() =>
      'BMSParsedPacket('
      'type=$typeName, '
      'dir=$directionLabel'
      '${isPacket4 ? ", $voltageDisplay, $currentDisplay, $socDisplay, $capacityDisplay" : ""}'
      ')';
}