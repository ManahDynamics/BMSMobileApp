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

  // ── BLE Name Response (dataId == 0x51) ────────────────────────────────────
  final String? bleName;

  // ── Dashboard / shared fields ─────────────────────────────────────────────
  final int?    soc;
  final double? totalVoltage;
  final double? totalCurrent;
  final double? remainingCapacity;
  final double? totalPower;        // in Watts (converted from KW)
  final String? totalPowerDisplay;

  // ── Dashboard-only fields (dataId == 0x52, 120-byte response) ────────────
  final String? batteryType;       // Bytes 3–19 (17 ASCII bytes)
  final int?    batteryStatusCode; // 0x01=Charging, 0x02=Idle, 0x03=Load Connected
  final int?    healthCode;        // 0x01=Good, 0x02=Poor
  final double? temperature;       // °C (signed)
  final int?    totalCells;        // Byte 35
  final int?    chargeCycles;      // Bytes 24–25
  final double? avgCellVoltage;    // Bytes 36–37 (×0.001 V)
  final double? voltageDiff;       // Bytes 38–39 (×0.001 V)
  final double? maxCellVoltage;    // Bytes 40–41 (×0.001 V)
  final double? minCellVoltage;    // Bytes 42–43 (×0.001 V)
  final String? firmwareVersion;   // Bytes 98–116 (19 ASCII bytes) — ALSO
                                    // reused for the Device Details Response
                                    // (0x57) firmware-version ASCII field.
  final int? warningAlerts;        // Byte 108 (v2 dashboard only)
  final int? faultAlerts;          // Byte 109 (v2 dashboard only)
  final int? clearedAlerts;        // Byte 110 (v2 dashboard only)
  final int? totalAlerts;          // Byte 111 (v2 dashboard only)

  // ── Cell Voltage Response fields (dataId == 0x53, 88-byte response) ───────
  final List<double>? cellVoltages;
  final List<bool>?   cellBalancing;
  final double? cellMaxVoltage;
  final int?    cellMaxVoltageNo;
  final double? cellMinVoltage;
  final int?    cellMinVoltageNo;
  final double? cellAvgVoltage;
  final bool?   cellBalancingActive;
  final int?    cellTotalCells;

  // ── Device Details Response fields (dataId == 0x57, 70-byte response) ───
  // NOTE: reuses the batterySerial / softwareVersion / hardwareVersion /
  // firmwareVersion fields below (legacy 0x59-0x5C device-info IDs are no
  // longer used in this build of the protocol, so there's no collision).
  final String? batterySerial;
  final String? softwareVersion;
  final String? hardwareVersion;
  final String? snCode;

  // ─────────────────────────────────────────────────────────────────────────
  // Battery Settings (0x58 read-back / 0xB0 Set Now)
  // ─────────────────────────────────────────────────────────────────────────
  final int? batteryString;
  final double? ratedCapacity;
  final int? socSet;
  final int? sleepWaitingTime;
  final double? balancedStartDiffVolt;
  final double? balancedStartVolt;
  final double? nominalCellVoltage;
  final int? cellChemistry;

  // ─────────────────────────────────────────────────────────────────────────
  // Protection Settings (0x59 read-back / 0xB2 Set Now)
  // ─────────────────────────────────────────────────────────────────────────
  final double? singleCellHighVoltProtection;
  final double? singleCellLowVoltProtection;
  final double? sumVoltHighProtection;
  final double? sumVoltLowProtection;
  final double? chargeOverCurrentProtection;
  final double? dischargeOverCurrentProtection;

  // ─────────────────────────────────────────────────────────────────────────
  // Temperature Settings (0x5A read-back / 0xB3 Set Now)
  // ─────────────────────────────────────────────────────────────────────────
  final int? noOfTempChannels;
  final int? chargeHighTempProtection;
  final int? chargeLowTempProtection;
  final int? dischargeHighTempProtection;
  final int? dischargeLowTempProtection;
  final int? diffTempProtection;

  // ─────────────────────────────────────────────────────────────────────────
  // Factory Settings (0x5B read-back / 0xB4 Set Now)
  // ─────────────────────────────────────────────────────────────────────────
  final String? batterySlNo;
  final String? bmsSerialNo;
  final String? bleDeviceName;

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
    this.batteryType,
    this.batteryStatusCode,
    this.healthCode,
    this.temperature,
    this.totalCells,
    this.chargeCycles,
    this.avgCellVoltage,
    this.voltageDiff,
    this.maxCellVoltage,
    this.minCellVoltage,
    this.firmwareVersion,
    this.warningAlerts,
    this.faultAlerts,
    this.clearedAlerts,
    this.totalAlerts,
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
    // Device info / Device Details
    this.batterySerial,
    this.softwareVersion,
    this.hardwareVersion,
    this.snCode,
    // Battery Settings
    this.batteryString,
    this.ratedCapacity,
    this.socSet,
    this.sleepWaitingTime,
    this.balancedStartDiffVolt,
    this.balancedStartVolt,
    this.nominalCellVoltage,
    this.cellChemistry,
    // Protection Settings
    this.singleCellHighVoltProtection,
    this.singleCellLowVoltProtection,
    this.sumVoltHighProtection,
    this.sumVoltLowProtection,
    this.chargeOverCurrentProtection,
    this.dischargeOverCurrentProtection,
    // Temperature Settings
    this.noOfTempChannels,
    this.chargeHighTempProtection,
    this.chargeLowTempProtection,
    this.dischargeHighTempProtection,
    this.dischargeLowTempProtection,
    this.diffTempProtection,
    // Factory Settings
    this.batterySlNo,
    this.bmsSerialNo,
    this.bleDeviceName,
  });

  // ── Convenience flags ─────────────────────────────────────────────────────

  bool get isAck =>
      startByte == 0xAA && stopByte == 0xBB && dataId == 0x50;

  bool get isDisconnect => dataId == 0x91;

  bool get isHandshake => dataId == 0x90 && startByte == 0xCC;

  bool get isBleNameResponse => dataId == 0x51 && bleName != null;

  bool get isDashboardResponse => dataId == 0x52 && totalVoltage != null;

  bool get isCellVoltageResponse => dataId == 0x53 && cellVoltages != null;

  /// FIXED: this getter was missing entirely — without it,
  /// bluetooth_service.dart had no way to recognize a parsed Device Details
  /// (0x57) packet, so it was parsed successfully and then silently dropped.
  bool get isDeviceDetailsResponse =>
      dataId == BMSProtocol.idDeviceDetailsResponse;

  bool get isBatterySettingsResponse =>
      dataId == BMSProtocol.idBatterySettingsResponse;

  bool get isProtectionSettingsResponse =>
      dataId == BMSProtocol.idProtectionSettingsResponse;

  bool get isTemperatureSettingsResponse =>
      dataId == BMSProtocol.idTemperatureSettingsResponse;

  bool get isFactorySettingsResponse =>
      dataId == BMSProtocol.idFactorySettingsResponse;

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
      totalPower != null ? '${(totalPower!).toStringAsFixed(3)} Kw' : '– Kw';

  String get temperatureDisplay =>
      temperature != null ? '${temperature!.toStringAsFixed(1)} °C' : '– °C';

  String get avgCellVoltageDisplay =>
      avgCellVoltage != null
          ? '${avgCellVoltage!.toStringAsFixed(3)} v'
          : '– v';

  String get voltageDiffDisplay =>
      voltageDiff != null
          ? '${voltageDiff!.toStringAsFixed(3)} v'
          : '– v';

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
      case 0x51: return 'BLE Name Response (21-byte)';
      case 0x52: return 'Dashboard Response (115-byte)';
      case 0x53: return 'Cell Voltage Response (88-byte)';
      case 0x57: return 'Device Details Response (70-byte)';
      case 0x58: return 'Battery Settings Response (18-byte)';
      case 0x59: return 'Protection Settings Response (17-byte)';
      case 0x5A: return 'Temperature Settings Response (11-byte)';
      case 0x5B: return 'Factory Settings Response (53-byte)';
      case 0xB0: return 'Battery Settings Set Now';
      case 0xB1: return 'Calibrate Now';
      case 0xB2: return 'Protection Settings Set Now';
      case 0xB3: return 'Temperature Settings Set Now';
      case 0xB4: return 'Factory Settings Set Now';
      case 0xB5: return 'Firmware Upgrade';
      case 0xB6: return 'Restart';
      case 0xB7: return 'Factory Data Reset';
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
    String?          batteryType,
    int?             batteryStatusCode,
    int?             healthCode,
    double?          temperature,
    int?             totalCells,
    int?             chargeCycles,
    double?          avgCellVoltage,
    double?          voltageDiff,
    double?          maxCellVoltage,
    double?          minCellVoltage,
    String?          firmwareVersion,
    int?             warningAlerts,
    int?             faultAlerts,
    int?             clearedAlerts,
    int?             totalAlerts,
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
    int?             batteryString,
    double?          ratedCapacity,
    int?             socSet,
    int?             sleepWaitingTime,
    double?          balancedStartDiffVolt,
    double?          balancedStartVolt,
    double?          nominalCellVoltage,
    int?             cellChemistry,
    double?          singleCellHighVoltProtection,
    double?          singleCellLowVoltProtection,
    double?          sumVoltHighProtection,
    double?          sumVoltLowProtection,
    double?          chargeOverCurrentProtection,
    double?          dischargeOverCurrentProtection,
    int?             noOfTempChannels,
    int?             chargeHighTempProtection,
    int?             chargeLowTempProtection,
    int?             dischargeHighTempProtection,
    int?             dischargeLowTempProtection,
    int?             diffTempProtection,
    String?          batterySlNo,
    String?          bmsSerialNo,
    String?          bleDeviceName,
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
      batteryType:         batteryType         ?? this.batteryType,
      batteryStatusCode:   batteryStatusCode   ?? this.batteryStatusCode,
      healthCode:          healthCode          ?? this.healthCode,
      temperature:         temperature         ?? this.temperature,
      totalCells:          totalCells          ?? this.totalCells,
      chargeCycles:        chargeCycles        ?? this.chargeCycles,
      avgCellVoltage:      avgCellVoltage      ?? this.avgCellVoltage,
      voltageDiff:         voltageDiff         ?? this.voltageDiff,
      maxCellVoltage:      maxCellVoltage      ?? this.maxCellVoltage,
      minCellVoltage:      minCellVoltage      ?? this.minCellVoltage,
      firmwareVersion:     firmwareVersion     ?? this.firmwareVersion,
      warningAlerts:       warningAlerts       ?? this.warningAlerts,
      faultAlerts:         faultAlerts         ?? this.faultAlerts,
      clearedAlerts:       clearedAlerts       ?? this.clearedAlerts,
      totalAlerts:         totalAlerts         ?? this.totalAlerts,
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
      batteryString:       batteryString       ?? this.batteryString,
      ratedCapacity:       ratedCapacity       ?? this.ratedCapacity,
      socSet:              socSet              ?? this.socSet,
      sleepWaitingTime:    sleepWaitingTime    ?? this.sleepWaitingTime,
      balancedStartDiffVolt: balancedStartDiffVolt ?? this.balancedStartDiffVolt,
      balancedStartVolt:   balancedStartVolt   ?? this.balancedStartVolt,
      nominalCellVoltage:  nominalCellVoltage  ?? this.nominalCellVoltage,
      cellChemistry:       cellChemistry       ?? this.cellChemistry,
      singleCellHighVoltProtection:
          singleCellHighVoltProtection ?? this.singleCellHighVoltProtection,
      singleCellLowVoltProtection:
          singleCellLowVoltProtection ?? this.singleCellLowVoltProtection,
      sumVoltHighProtection: sumVoltHighProtection ?? this.sumVoltHighProtection,
      sumVoltLowProtection:  sumVoltLowProtection  ?? this.sumVoltLowProtection,
      chargeOverCurrentProtection:
          chargeOverCurrentProtection ?? this.chargeOverCurrentProtection,
      dischargeOverCurrentProtection:
          dischargeOverCurrentProtection ?? this.dischargeOverCurrentProtection,
      noOfTempChannels:    noOfTempChannels    ?? this.noOfTempChannels,
      chargeHighTempProtection:
          chargeHighTempProtection ?? this.chargeHighTempProtection,
      chargeLowTempProtection:
          chargeLowTempProtection ?? this.chargeLowTempProtection,
      dischargeHighTempProtection:
          dischargeHighTempProtection ?? this.dischargeHighTempProtection,
      dischargeLowTempProtection:
          dischargeLowTempProtection ?? this.dischargeLowTempProtection,
      diffTempProtection:  diffTempProtection  ?? this.diffTempProtection,
      batterySlNo:         batterySlNo         ?? this.batterySlNo,
      bmsSerialNo:         bmsSerialNo         ?? this.bmsSerialNo,
      bleDeviceName:       bleDeviceName       ?? this.bleDeviceName,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer('BMSParsedPacket(type=$typeName, dir=$directionLabel');
    if (isBleNameResponse) {
      sb.write(', bleName=$bleName');
    }
    if (isDashboardResponse) {
      sb.write(', type=$batteryType');
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
    if (isDeviceDetailsResponse) {
      sb.write(', serial=$batterySerial, sw=$softwareVersion, hw=$hardwareVersion, fw=$firmwareVersion');
    }
    if (isBatterySettingsResponse) {
      sb.write(', string=$batteryString, capacity=$ratedCapacity, soc=$socSet'
          ', sleep=$sleepWaitingTime, chemistry=$cellChemistry');
    }
    if (isProtectionSettingsResponse) {
      sb.write(', cellHigh=$singleCellHighVoltProtection, cellLow=$singleCellLowVoltProtection'
          ', sumHigh=$sumVoltHighProtection, sumLow=$sumVoltLowProtection'
          ', chargeOc=$chargeOverCurrentProtection, dischargeOc=$dischargeOverCurrentProtection');
    }
    if (isTemperatureSettingsResponse) {
      sb.write(', channels=$noOfTempChannels, chargeHigh=$chargeHighTempProtection'
          ', chargeLow=$chargeLowTempProtection, dischargeHigh=$dischargeHighTempProtection'
          ', dischargeLow=$dischargeLowTempProtection, diff=$diffTempProtection');
    }
    if (isFactorySettingsResponse) {
      sb.write(', batterySl=$batterySlNo, bmsSerial=$bmsSerialNo, bleName=$bleDeviceName');
    }
    sb.write(')');
    return sb.toString();
  }
}