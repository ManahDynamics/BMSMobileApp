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
  final double? totalPower;
  final String? totalPowerDisplay;

  // ── Device info fields (dataId 0x59–0x5C) ─────────────────────────────────
  // Populated when the BMS responds to a device-info request packet.
  // Each field holds the decoded ASCII string from bytes 3–16 of the response.
  final String? batterySerial;   // Packet 12 – dataId 0x59
  final String? softwareVersion; // Packet 13 – dataId 0x5A
  final String? hardwareVersion; // Packet 14 – dataId 0x5B
  final String? snCode;          // Packet 15 – dataId 0x5C

  const BMSParsedPacket({
    required this.startByte,
    required this.length,
    required this.dataId,
    required this.crc,
    required this.stopByte,
    required this.rawBytes,
    required this.receivedAt,
    this.direction = PacketDirection.unknown,
    // Packet 4
    this.totalVoltage,
    this.totalCurrent,
    this.soc,
    this.remainingCapacity,
    this.totalPower,
    this.totalPowerDisplay,
    // Device info
    this.batterySerial,
    this.softwareVersion,
    this.hardwareVersion,
    this.snCode,
  });

  // ── Convenience flags ─────────────────────────────────────────────────────

  bool get isAck =>
      startByte == 0xAA && stopByte == 0xBB && dataId == 0x50;

  bool get isDisconnect =>
      dataId == 0x91;

  bool get isHandshake =>
      dataId == 0x90 && startByte == 0xCC;

  bool get isPacket4 =>
      dataId == 0x51 && totalVoltage != null;

  /// True when this packet carries one of the four device-info ASCII strings.
  bool get isDeviceInfo =>
      dataId == 0x59 || dataId == 0x5A || dataId == 0x5B || dataId == 0x5C;

  // ── Direction label for UI/log display ───────────────────────────────────
  String get directionLabel {
    switch (direction) {
      case PacketDirection.send:    return 'TX';
      case PacketDirection.receive: return 'RX';
      case PacketDirection.unknown: return '??';
    }
  }

  // ── Formatted display strings ─────────────────────────────────────────────
  String get voltageDisplay    => totalVoltage      != null ? '${totalVoltage!.toStringAsFixed(1)} V'       : '– V';
  String get currentDisplay    => totalCurrent      != null ? '${totalCurrent!.toStringAsFixed(1)} A'       : '– A';
  String get socDisplay        => soc               != null ? '$soc %'                                       : '– %';
  String get capacityDisplay   => remainingCapacity != null ? '${remainingCapacity!.toStringAsFixed(1)} Ah' : '– Ah';
  String get powerDisplay      => totalPower        != null ? '${totalPower!.toStringAsFixed(1)} W'         : '– W';

  // ── Human-readable type name for logs ─────────────────────────────────────
  String get typeName {
    switch (dataId) {
      case 0x90: return 'HANDSHAKE';
      case 0x50: return 'ACK';
      case 0x91: return 'DISCONNECT';
      case 0x51: return 'Packet4 (SOC/Voltage/Current)';
      case 0x59: return 'Battery Serial No';
      case 0x5A: return 'Software Version';
      case 0x5B: return 'Hardware Version';
      case 0x5C: return 'SN Code';
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
    String?          batterySerial,
    String?          softwareVersion,
    String?          hardwareVersion,
    String?          snCode,
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
      batterySerial:     batterySerial     ?? this.batterySerial,
      softwareVersion:   softwareVersion   ?? this.softwareVersion,
      hardwareVersion:   hardwareVersion   ?? this.hardwareVersion,
      snCode:            snCode            ?? this.snCode,
    );
  }

  @override
  String toString() =>
      'BMSParsedPacket('
      'type=$typeName, '
      'dir=$directionLabel'
      '${isPacket4 ? ", $voltageDisplay, $currentDisplay, $socDisplay, $capacityDisplay, $powerDisplay" : ""}'
      '${isDeviceInfo ? ", value=${batterySerial ?? softwareVersion ?? hardwareVersion ?? snCode}" : ""}'
      ')';
}