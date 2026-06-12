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

  // ── BLE Name Response (dataId == 0x51, 19-byte response) ─────────────────
  final String? bleName;

  // ── Dashboard / shared fields ─────────────────────────────────────────────
  final int?    soc;
  final double? totalVoltage;
  final double? totalCurrent;
  final double? remainingCapacity;
  final double? totalPower;        // in Watts (converted from KW)
  final String? totalPowerDisplay;

  // ── Dashboard-only fields (dataId == 0x52, 86-byte response) ─────────────
  final int?    batteryStatusCode; // 0x01=Charging, 0x02=Idle, 0x03=Load Connected
  final int?    healthCode;        // 0x01=Good, 0x02=Poor
  final double? temperature;       // °C (signed)
  final int?    totalCells;        // Byte 72
  final int?    chargeCycles;      // Bytes 73–74
  final double? avgCellVoltage;    // Bytes 75–76 (×0.001 V)
  final double? voltageDiff;       // Bytes 77–78 (×0.001 V)
  final double? maxCellVoltage;    // Bytes 79–80 (×0.001 V)
  final double? minCellVoltage;    // Bytes 81–82 (×0.001 V)

  // ── Cell Voltage Response fields (dataId == 0x53, 88-byte response) ───────
  final List<double>? cellVoltages;    // per-cell voltages (×0.001 V)
  final List<bool>?   cellBalancing;   // per-cell balancing flags
  final double? cellMaxVoltage;        // summary max from response
  final int?    cellMaxVoltageNo;      // cell number with max (1-based)
  final double? cellMinVoltage;        // summary min from response
  final int?    cellMinVoltageNo;      // cell number with min (1-based)
  final double? cellAvgVoltage;        // average cell voltage from response
  final bool?   cellBalancingActive;   // overall balancing status (Byte 11)
  final int?    cellTotalCells;        // total cells from cell response (Byte 12)

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
    // BLE Name
    this.bleName,
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
    // Cell voltage response
    this.cellVoltages,
    this.cellBalancing,
    this.cellMaxVoltage,
    this.cellMaxVoltageNo,
    this.cellMinVoltage,
    this.cellMinVoltageNo,
    this.cellAvgVoltage,
    this.cellBalancingActive,
    this.cellTotalCells,
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

  /// BLE Name response (19-byte, dataId == 0x51)
  bool get isBleNameResponse => dataId == 0x51 && bleName != null;

  /// Full 86-byte dashboard response (0x52)
  bool get isDashboardResponse => dataId == 0x52 && totalVoltage != null;

  /// Cell voltage response (0x53)
  bool get isCellVoltageResponse => dataId == 0x53 && cellVoltages != null;

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
      case 0x51: return 'BLE Name Response (19-byte)';
      case 0x52: return 'Dashboard Response (86-byte)';
      case 0x53: return 'Cell Voltage Response (88-byte)';
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
    String?          bleName,
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
    List<double>?    cellVoltages,
    List<bool>?      cellBalancing,
    double?          cellMaxVoltage,
    int?             cellMaxVoltageNo,
    double?          cellMinVoltage,
    int?             cellMinVoltageNo,
    double?          cellAvgVoltage,
    bool?            cellBalancingActive,
    int?             cellTotalCells,
    String?          batterySerial,
    String?          softwareVersion,
    String?          hardwareVersion,
    String?          snCode,
  }) {
    return BMSParsedPacket(
      startByte:           startByte           ?? this.startByte,
      length:              length              ?? this.length,
      dataId:              dataId              ?? this.dataId,
      crc:                 crc                 ?? this.crc,
      stopByte:            stopByte            ?? this.stopByte,
      rawBytes:            rawBytes            ?? this.rawBytes,
      receivedAt:          receivedAt          ?? this.receivedAt,
      direction:           direction           ?? this.direction,
      bleName:             bleName             ?? this.bleName,
      soc:                 soc                 ?? this.soc,
      totalVoltage:        totalVoltage        ?? this.totalVoltage,
      totalCurrent:        totalCurrent        ?? this.totalCurrent,
      remainingCapacity:   remainingCapacity   ?? this.remainingCapacity,
      totalPower:          totalPower          ?? this.totalPower,
      totalPowerDisplay:   totalPowerDisplay   ?? this.totalPowerDisplay,
      batteryStatusCode:   batteryStatusCode   ?? this.batteryStatusCode,
      healthCode:          healthCode          ?? this.healthCode,
      temperature:         temperature         ?? this.temperature,
      totalCells:          totalCells          ?? this.totalCells,
      chargeCycles:        chargeCycles        ?? this.chargeCycles,
      avgCellVoltage:      avgCellVoltage      ?? this.avgCellVoltage,
      voltageDiff:         voltageDiff         ?? this.voltageDiff,
      maxCellVoltage:      maxCellVoltage      ?? this.maxCellVoltage,
      minCellVoltage:      minCellVoltage      ?? this.minCellVoltage,
      cellVoltages:        cellVoltages        ?? this.cellVoltages,
      cellBalancing:       cellBalancing       ?? this.cellBalancing,
      cellMaxVoltage:      cellMaxVoltage      ?? this.cellMaxVoltage,
      cellMaxVoltageNo:    cellMaxVoltageNo    ?? this.cellMaxVoltageNo,
      cellMinVoltage:      cellMinVoltage      ?? this.cellMinVoltage,
      cellMinVoltageNo:    cellMinVoltageNo    ?? this.cellMinVoltageNo,
      cellAvgVoltage:      cellAvgVoltage      ?? this.cellAvgVoltage,
      cellBalancingActive: cellBalancingActive ?? this.cellBalancingActive,
      cellTotalCells:      cellTotalCells      ?? this.cellTotalCells,
      batterySerial:       batterySerial       ?? this.batterySerial,
      softwareVersion:     softwareVersion     ?? this.softwareVersion,
      hardwareVersion:     hardwareVersion     ?? this.hardwareVersion,
      snCode:              snCode              ?? this.snCode,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer('BMSParsedPacket(type=$typeName, dir=$directionLabel');
    if (isBleNameResponse) {
      sb.write(', bleName=$bleName');
    }
    if (isDashboardResponse) {
      sb.write(', $voltageDisplay, $currentDisplay, $socDisplay, $capacityDisplay');
      sb.write(', status=$batteryStatusLabel, health=$healthLabel'
          ', temp=$temperatureDisplay, cells=$totalCellsDisplay'
          ', cycles=$chargeCyclesDisplay, avg=$avgCellVoltageDisplay'
          ', diff=$voltageDiffDisplay, max=$maxCellVoltageDisplay'
          ', min=$minCellVoltageDisplay');
    }
    if (isCellVoltageResponse) {
      sb.write(', cells=${cellVoltages?.length ?? 0}'
          ', max=${cellMaxVoltage?.toStringAsFixed(3)}V(#$cellMaxVoltageNo)'
          ', min=${cellMinVoltage?.toStringAsFixed(3)}V(#$cellMinVoltageNo)'
          ', avg=${cellAvgVoltage?.toStringAsFixed(3)}V'
          ', balancing=${cellBalancingActive == true ? "Active" : "Inactive"}');
    }
    if (isDeviceInfo) {
      sb.write(', value=${batterySerial ?? softwareVersion ?? hardwareVersion ?? snCode}');
    }
    sb.write(')');
    return sb.toString();
  }
}