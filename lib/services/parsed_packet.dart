// lib/services/parsed_packet.dart

import 'dart:typed_data';
import 'protocol.dart';

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

  // ── Dashboard / Packet4 shared fields ────────────────────────────────────
  final int?    soc;
  final double? totalVoltage;
  final double? totalCurrent;
  final double? remainingCapacity;
  final double? totalPower;         // in Watts
  final String? totalPowerDisplay;

  // ── Dashboard-only fields (dataId == 0x52, 86-byte response) ─────────────
  final int?    batteryStatusCode;  // raw byte: 0x01/0x02/0x03
  final int?    healthCode;         // raw byte: 0x01/0x02
  final double? temperature;        // °C
  final int?    totalCells;
  final int?    chargeCycles;
  final double? avgCellVoltage;     // V (×0.001)
  final double? voltageDiff;        // V (×0.001)
  final double? maxCellVoltage;     // V (×0.001)
  final double? minCellVoltage;     // V (×0.001)

  // ── Device info fields (dataId 0x59–0x5C) ────────────────────────────────
  final String? batterySerial;
  final String? softwareVersion;
  final String? hardwareVersion;
  final String? snCode;

  const BMSParsedPacket({
    required this.startByte,
    required this.length,
    required this.dataId,
    required this.crc,
    required this.stopByte,
    required this.rawBytes,
    required this.receivedAt,
    this.direction = PacketDirection.unknown,
    // Shared
    this.soc,
    this.totalVoltage,
    this.totalCurrent,
    this.remainingCapacity,
    this.totalPower,
    this.totalPowerDisplay,
    // Dashboard-only
    this.batteryStatusCode,
    this.healthCode,
    this.temperature,
    this.totalCells,
    this.chargeCycles,
    this.avgCellVoltage,
    this.voltageDiff,
    this.maxCellVoltage,
    this.minCellVoltage,
    // Device info
    this.batterySerial,
    this.softwareVersion,
    this.hardwareVersion,
    this.snCode,
  });

  // ── Convenience flags ─────────────────────────────────────────────────────

  bool get isAck =>
      startByte == 0xAA && stopByte == 0xBB && dataId == 0x50;

  bool get isDisconnect => dataId == 0x91;

  bool get isHandshake => dataId == 0x90 && startByte == 0xCC;

  /// Legacy 12-byte packet (0x51)
  bool get isPacket4 => dataId == 0x51 && totalVoltage != null;

  /// New 86-byte full dashboard response (0x52)
  bool get isDashboardResponse => dataId == 0x52 && totalVoltage != null;

  bool get isDeviceInfo =>
      dataId == 0x59 || dataId == 0x5A || dataId == 0x5B || dataId == 0x5C;

  // ── Decoded label fields ──────────────────────────────────────────────────

  String get batteryStatusLabel =>
      batteryStatusCode != null
          ? BMSProtocol.batteryStatusLabel(batteryStatusCode!)
          : '–';

  String get healthLabel =>
      healthCode != null ? BMSProtocol.healthLabel(healthCode!) : '–';

  // ── Formatted display strings ─────────────────────────────────────────────

  String get voltageDisplay =>
      totalVoltage != null ? '${totalVoltage!.toStringAsFixed(1)} V' : '– V';

  String get currentDisplay =>
      totalCurrent != null ? '${totalCurrent!.toStringAsFixed(1)} A' : '– A';

  String get socDisplay =>
      soc != null ? '$soc %' : '– %';

  String get capacityDisplay =>
      remainingCapacity != null
          ? '${remainingCapacity!.toStringAsFixed(1)} Ah'
          : '– Ah';

  String get powerDisplay =>
      totalPower != null ? '${totalPower!.toStringAsFixed(0)} W' : '– W';

  String get temperatureDisplay =>
      temperature != null ? '${temperature!.toStringAsFixed(1)} °C' : '– °C';

  String get avgCellVoltageDisplay =>
      avgCellVoltage != null
          ? '${avgCellVoltage!.toStringAsFixed(3)} V'
          : '– V';

  String get voltageDiffDisplay =>
      voltageDiff != null
          ? '${voltageDiff!.toStringAsFixed(3)} V'
          : '– V';

  String get maxCellVoltageDisplay =>
      maxCellVoltage != null
          ? '${maxCellVoltage!.toStringAsFixed(3)} V'
          : '– V';

  String get minCellVoltageDisplay =>
      minCellVoltage != null
          ? '${minCellVoltage!.toStringAsFixed(3)} V'
          : '– V';

  String get chargeCyclesDisplay =>
      chargeCycles != null ? '$chargeCycles' : '–';

  String get totalCellsDisplay =>
      totalCells != null ? '$totalCells' : '–';

  // ── Human-readable type name for logs ─────────────────────────────────────
  String get typeName {
    switch (dataId) {
      case 0x90: return 'HANDSHAKE';
      case 0x50: return 'ACK';
      case 0x91: return 'DISCONNECT';
      case 0x51: return 'Packet4 legacy (SOC/V/A)';
      case 0x52: return 'Dashboard Response (full 86-byte)';
      case 0x59: return 'Battery Serial No';
      case 0x5A: return 'Software Version';
      case 0x5B: return 'Hardware Version';
      case 0x5C: return 'SN Code';
      default:
        return 'Unknown (0x${dataId.toRadixString(16).toUpperCase().padLeft(2, "0")})';
    }
  }

  String get directionLabel {
    switch (direction) {
      case PacketDirection.send:    return 'TX';
      case PacketDirection.receive: return 'RX';
      case PacketDirection.unknown: return '??';
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
    int?             soc,
    double?          totalVoltage,
    double?          totalCurrent,
    double?          remainingCapacity,
    double?          totalPower,
    String?          totalPowerDisplay,
    int?             batteryStatusCode,
    int?             healthCode,
    double?          temperature,
    int?             totalCells,
    int?             chargeCycles,
    double?          avgCellVoltage,
    double?          voltageDiff,
    double?          maxCellVoltage,
    double?          minCellVoltage,
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
      soc:               soc               ?? this.soc,
      totalVoltage:      totalVoltage      ?? this.totalVoltage,
      totalCurrent:      totalCurrent      ?? this.totalCurrent,
      remainingCapacity: remainingCapacity ?? this.remainingCapacity,
      totalPower:        totalPower        ?? this.totalPower,
      totalPowerDisplay: totalPowerDisplay ?? this.totalPowerDisplay,
      batteryStatusCode: batteryStatusCode ?? this.batteryStatusCode,
      healthCode:        healthCode        ?? this.healthCode,
      temperature:       temperature       ?? this.temperature,
      totalCells:        totalCells        ?? this.totalCells,
      chargeCycles:      chargeCycles      ?? this.chargeCycles,
      avgCellVoltage:    avgCellVoltage    ?? this.avgCellVoltage,
      voltageDiff:       voltageDiff       ?? this.voltageDiff,
      maxCellVoltage:    maxCellVoltage    ?? this.maxCellVoltage,
      minCellVoltage:    minCellVoltage    ?? this.minCellVoltage,
      batterySerial:     batterySerial     ?? this.batterySerial,
      softwareVersion:   softwareVersion   ?? this.softwareVersion,
      hardwareVersion:   hardwareVersion   ?? this.hardwareVersion,
      snCode:            snCode            ?? this.snCode,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer('BMSParsedPacket(type=$typeName, dir=$directionLabel');
    if (isPacket4 || isDashboardResponse) {
      sb.write(', $voltageDisplay, $currentDisplay, $socDisplay, $capacityDisplay');
    }
    if (isDashboardResponse) {
      sb.write(', status=$batteryStatusLabel, health=$healthLabel'
          ', temp=$temperatureDisplay, cells=$totalCellsDisplay'
          ', cycles=$chargeCyclesDisplay, avg=$avgCellVoltageDisplay'
          ', diff=$voltageDiffDisplay, max=$maxCellVoltageDisplay'
          ', min=$minCellVoltageDisplay');
    }
    if (isDeviceInfo) {
      sb.write(', value=${batterySerial ?? softwareVersion ?? hardwareVersion ?? snCode}');
    }
    sb.write(')');
    return sb.toString();
  }
}