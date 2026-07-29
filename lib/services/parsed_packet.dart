// lib/services/parsed_packet.dart

import 'dart:typed_data';
import 'protocol.dart';

enum PacketDirection { send, receive, unknown }

/// Alert catalogue for the Alerts Details Response (dataId 0x56).
/// ID / name / priority pulled from the "Alerts" reference sheet.
class BMSAlertInfo {
  final int id;
  final String name;
  final String type; // "Warning" or "Fault"
  final String priority; // "low" | "Medium" | "high"

  const BMSAlertInfo(this.id, this.name, this.type, this.priority);
}

class BMSAlertCatalogue {
  BMSAlertCatalogue._();

  static const Map<int, BMSAlertInfo> byId = {
    0x01: BMSAlertInfo(0x01, 'Cell volt high', 'Warning', 'low'),
    0x02: BMSAlertInfo(0x02, 'Cell volt high', 'Fault', 'high'),
    0x03: BMSAlertInfo(0x03, 'Cell volt low', 'Warning', 'low'),
    0x04: BMSAlertInfo(0x04, 'Cell volt low', 'Fault', 'high'),
    0x05: BMSAlertInfo(0x05, 'Voltage diff', 'Warning', 'low'),
    0x06: BMSAlertInfo(0x06, 'Voltage diff', 'Fault', 'high'),
    0x07: BMSAlertInfo(0x07, 'Single cell disconnect', 'Fault', 'high'),
    0x08: BMSAlertInfo(0x08, 'The whole group disconnect', 'Fault', 'high'),
    0x09: BMSAlertInfo(0x09, 'Cell Voltage', 'Fault', 'high'),
    0x0A: BMSAlertInfo(0x0A, 'Sum volt high', 'Warning', 'low'),
    0x0B: BMSAlertInfo(0x0B, 'Sum volt high', 'Fault', 'high'),
    0x0C: BMSAlertInfo(0x0C, 'Sum volt low', 'Warning', 'low'),
    0x0D: BMSAlertInfo(0x0D, 'Sum volt low', 'Fault', 'high'),
    0x0E: BMSAlertInfo(0x0E, 'Chg temp high', 'Warning', 'low'),
    0x0F: BMSAlertInfo(0x0F, 'Chg temp high', 'Fault', 'high'),
    0x10: BMSAlertInfo(0x10, 'Chg temp low', 'Warning', 'low'),
    0x11: BMSAlertInfo(0x11, 'Chg temp low', 'Fault', 'high'),
    0x12: BMSAlertInfo(0x12, 'Dischg temp high', 'Warning', 'low'),
    0x13: BMSAlertInfo(0x13, 'Dischg temp high', 'Fault', 'high'),
    0x14: BMSAlertInfo(0x14, 'Dischg temp low', 'Warning', 'low'),
    0x15: BMSAlertInfo(0x15, 'Dischg temp low', 'Fault', 'high'),
    0x16: BMSAlertInfo(0x16, 'Temp diff level', 'Warning', 'low'),
    0x17: BMSAlertInfo(0x17, 'Temp diff level', 'Fault', 'high'),
    0x18: BMSAlertInfo(0x18, 'Cell temp error', 'Fault', 'high'),
    0x19: BMSAlertInfo(0x19, 'Chg over current', 'Warning', 'low'),
    0x1A: BMSAlertInfo(0x1A, 'Chg over current', 'Fault', 'high'),
    0x1B: BMSAlertInfo(0x1B, 'Dischg over current', 'Warning', 'low'),
    0x1C: BMSAlertInfo(0x1C, 'Dischg over current', 'Fault', 'high'),
    0x1D: BMSAlertInfo(0x1D, 'Short circuit', 'Fault', 'high'),
    0x1E: BMSAlertInfo(0x1E, 'Soc low level', 'Warning', 'low'),
    0x1F: BMSAlertInfo(0x1F, 'Soc low level', 'Warning', 'Medium'),
    0x20: BMSAlertInfo(0x20, 'Soc low level', 'Fault', 'high'),
    0x21: BMSAlertInfo(0x21, 'SOH level 1', 'Warning', 'low'),
    0x22: BMSAlertInfo(0x22, 'SOH level 2', 'Fault', 'high'),
    0x23: BMSAlertInfo(0x23, 'AFE data comm', 'Fault', 'high'),
    0x24: BMSAlertInfo(0x24, 'EEPROM error', 'Warning', 'low'),
    0x25: BMSAlertInfo(0x25, 'Communication', 'Fault', 'high'),
    0x26: BMSAlertInfo(0x26, 'Internal comm', 'Fault', 'high'),
  };

  static BMSAlertInfo? lookup(int id) => byId[id];
}

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
  final String? firmwareVersion;
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

  // ─────────────────────────────────────────────────────────────────────────
  // Alerts Details Response (dataId == 0x56, 37-byte response)
  // Request dataId == 0x96 (5-byte control packet with sequence number)
  // ─────────────────────────────────────────────────────────────────────────
  final int?    alertCycleCount;          // Bytes 3–4 (LE16)
  final int?    alertCycleTimeAtFault;    // Bytes 5–6 (LE16)
  final int?    alertBatteryStatusCode;   // Byte 7 (1=Charging,2=Discharging,3=Storage,4=Ideal,5=Sleep)
  final int?    alertFailureDate;         // Byte 8
  final int?    alertFailureMonth;        // Byte 9
  final int?    alertFailureYear;         // Bytes 10–11 (LE16)
  final int?    alertFailureHour;         // Byte 12
  final int?    alertFailureMinute;       // Byte 13
  final int?    alertFaultId;             // Byte 15 (1 to 38 — maps to BMSAlertCatalogue)
  final int?    alertFaultActionCode;     // Byte 16 (0x01 = Disappear)
  final double? alertTotalVoltage;        // Bytes 17–18 (LE16, ×0.1 V)
  final double? alertCurrent;             // Bytes 19–20 (LE16 signed, ×0.1 A)
  final int?    alertSoc;                 // Byte 21 (%)
  final double? alertMaxCellVoltage;      // Bytes 22–23 (LE16, ×0.001 V)
  final int?    alertMaxCellVoltagePos;   // Byte 24
  final double? alertMinCellVoltage;      // Bytes 25–26 (LE16, ×0.001 V)
  final int?    alertMinCellVoltagePos;   // Byte 27
  final double? alertMaxTemp;             // Bytes 28–29 (LE16 signed, ×0.1 °C)
  final int?    alertMaxTempPos;          // Byte 30
  final double? alertLowestTemp;          // Bytes 31–32 (LE16 signed, ×0.1 °C)
  final int?    alertMinTempPos;          // Byte 33

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
    this.firmwareVersion,
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
    // Alerts Details Response
    this.alertCycleCount,
    this.alertCycleTimeAtFault,
    this.alertBatteryStatusCode,
    this.alertFailureDate,
    this.alertFailureMonth,
    this.alertFailureYear,
    this.alertFailureHour,
    this.alertFailureMinute,
    this.alertFaultId,
    this.alertFaultActionCode,
    this.alertTotalVoltage,
    this.alertCurrent,
    this.alertSoc,
    this.alertMaxCellVoltage,
    this.alertMaxCellVoltagePos,
    this.alertMinCellVoltage,
    this.alertMinCellVoltagePos,
    this.alertMaxTemp,
    this.alertMaxTempPos,
    this.alertLowestTemp,
    this.alertMinTempPos,
  });

  // ── Convenience flags ─────────────────────────────────────────────────────

  bool get isAck =>
      startByte == 0xAA && stopByte == 0xBB && dataId == 0x50;

bool get isLiveStatusAck =>
    startByte == BMSProtocol.ackStart &&
    stopByte == BMSProtocol.ackStop &&
    dataId == BMSProtocol.idLiveStatusAck &&
    length == BMSProtocol.packetLength;

     bool get isCalibrationAck =>
      startByte == BMSProtocol.ackStart &&
      stopByte == BMSProtocol.ackStop &&
      dataId == BMSProtocol.idCalibrationAck &&
      length == BMSProtocol.packetLength;

  bool get isDisconnect => dataId == BMSProtocol.idDisconnect;

  bool get isHandshake => dataId == BMSProtocol.idHandshake && startByte == BMSProtocol.startByte;

  bool get isBleNameResponse => dataId == BMSProtocol.idBleNameResponse && bleName != null;

  bool get isDashboardResponse =>
    dataId == BMSProtocol.idDashboardResponse && totalVoltage != null;

bool get isCellVoltageResponse =>
    dataId == BMSProtocol.idCellVoltageResponse && cellVoltages != null;

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

  bool get isAlertsResponse =>
      dataId == BMSProtocol.idAlertsResponse && alertCycleCount != null;

  // ── Decoded label fields ──────────────────────────────────────────────────

  String get batteryStatusLabel =>
      batteryStatusCode != null
          ? BMSProtocol.batteryStatusLabel(batteryStatusCode!)
          : '–';

  String get healthLabel =>
      healthCode != null ? BMSProtocol.healthLabel(healthCode!) : '–';

  /// Battery status at the moment of the fault (Alerts Details Response).
  /// Codes: 1=Charging, 2=Discharging, 3=Storage, 4=Ideal, 5=Sleep
  String get alertBatteryStatusLabel {
    switch (alertBatteryStatusCode) {
      case 1: return 'Charging';
      case 2: return 'Discharging';
      case 3: return 'Storage';
      case 4: return 'Ideal';
      case 5: return 'Sleep';
      default: return '–';
    }
  }

  /// Fault/alert action. Codes: 1=Disappear
  String get alertFaultActionLabel {
    switch (alertFaultActionCode) {
      case 1: return 'Disappear';
      default: return '–';
    }
  }

  /// Looks up the alert name/type/priority for [alertFaultId] using the
  /// BMSAlertCatalogue (Sl No 1–38 from the Alerts reference sheet).
  BMSAlertInfo? get alertInfo =>
      alertFaultId != null ? BMSAlertCatalogue.lookup(alertFaultId!) : null;

  String get alertNameLabel => alertInfo?.name ?? '–';

  String get alertTypeLabel => alertInfo?.type ?? '–';

  String get alertPriorityLabel => alertInfo?.priority ?? '–';

  /// Combined failure timestamp, e.g. "14/07/2026 09:35".
  String get alertFailureTimestampDisplay {
    if (alertFailureDate == null ||
        alertFailureMonth == null ||
        alertFailureYear == null ||
        alertFailureHour == null ||
        alertFailureMinute == null) {
      return '–';
    }
    final dd = alertFailureDate!.toString().padLeft(2, '0');
    final mm = alertFailureMonth!.toString().padLeft(2, '0');
    final yyyy = alertFailureYear!.toString();
    final hh = alertFailureHour!.toString().padLeft(2, '0');
    final min = alertFailureMinute!.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

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

  // ── Alerts Details display strings ────────────────────────────────────────

  String get alertTotalVoltageDisplay =>
      alertTotalVoltage != null
          ? '${alertTotalVoltage!.toStringAsFixed(1)} V'
          : '– V';

  String get alertCurrentDisplay =>
      alertCurrent != null ? '${alertCurrent!.toStringAsFixed(1)} A' : '– A';

  String get alertSocDisplay =>
      alertSoc != null ? '$alertSoc %' : '– %';

  String get alertMaxCellVoltageDisplay =>
      alertMaxCellVoltage != null
          ? '${alertMaxCellVoltage!.toStringAsFixed(3)} V'
          : '– V';

  String get alertMinCellVoltageDisplay =>
      alertMinCellVoltage != null
          ? '${alertMinCellVoltage!.toStringAsFixed(3)} V'
          : '– V';

  String get alertMaxTempDisplay =>
      alertMaxTemp != null ? '${alertMaxTemp!.toStringAsFixed(1)} °C' : '– °C';

  String get alertLowestTempDisplay =>
      alertLowestTemp != null
          ? '${alertLowestTemp!.toStringAsFixed(1)} °C'
          : '– °C';

  // ── Human-readable type name for logs ─────────────────────────────────────
  String get typeName {
    switch (dataId) {
      case 0x90: return 'HANDSHAKE';
case 0x50: return 'ACK';
case 0x91: return 'DISCONNECT';
case 0x92: return 'Live Status Packet';
case 0x52: return 'Live Status Ack';
case 0x53: return 'BLE Name Response (21-byte)';
case 0x54: return 'Dashboard Response (115-byte)';
case 0x55: return 'Cell Voltage Response (88-byte)';
case 0x56: return 'Alerts Details Response (37-byte)';
case 0x57: return 'Device Details Response (70-byte)';
case 0x58: return 'Battery Settings Response (18-byte)';
case 0x59: return 'Protection Settings Response (17-byte)';
case 0x5A: return 'Temperature Settings Response (11-byte)';
case 0x5B: return 'Factory Settings Response (53-byte)';
case 0x96: return 'Alerts Details Request';
case 0xB0: return 'Battery Settings Set Now';
case 0xB1: return 'Calibrate Now';
case 0xC1: return 'Calibrate Now — Ack';
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
    String?          firmwareVersion,
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
    int?             alertCycleCount,
    int?             alertCycleTimeAtFault,
    int?             alertBatteryStatusCode,
    int?             alertFailureDate,
    int?             alertFailureMonth,
    int?             alertFailureYear,
    int?             alertFailureHour,
    int?             alertFailureMinute,
    int?             alertFaultId,
    int?             alertFaultActionCode,
    double?          alertTotalVoltage,
    double?          alertCurrent,
    int?             alertSoc,
    double?          alertMaxCellVoltage,
    int?             alertMaxCellVoltagePos,
    double?          alertMinCellVoltage,
    int?             alertMinCellVoltagePos,
    double?          alertMaxTemp,
    int?             alertMaxTempPos,
    double?          alertLowestTemp,
    int?             alertMinTempPos,
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
      alertCycleCount:        alertCycleCount        ?? this.alertCycleCount,
      alertCycleTimeAtFault:  alertCycleTimeAtFault  ?? this.alertCycleTimeAtFault,
      alertBatteryStatusCode: alertBatteryStatusCode ?? this.alertBatteryStatusCode,
      alertFailureDate:       alertFailureDate       ?? this.alertFailureDate,
      alertFailureMonth:      alertFailureMonth      ?? this.alertFailureMonth,
      alertFailureYear:       alertFailureYear       ?? this.alertFailureYear,
      alertFailureHour:       alertFailureHour       ?? this.alertFailureHour,
      alertFailureMinute:     alertFailureMinute     ?? this.alertFailureMinute,
      alertFaultId:           alertFaultId           ?? this.alertFaultId,
      alertFaultActionCode:   alertFaultActionCode   ?? this.alertFaultActionCode,
      alertTotalVoltage:      alertTotalVoltage      ?? this.alertTotalVoltage,
      alertCurrent:           alertCurrent           ?? this.alertCurrent,
      alertSoc:               alertSoc               ?? this.alertSoc,
      alertMaxCellVoltage:    alertMaxCellVoltage    ?? this.alertMaxCellVoltage,
      alertMaxCellVoltagePos: alertMaxCellVoltagePos ?? this.alertMaxCellVoltagePos,
      alertMinCellVoltage:    alertMinCellVoltage    ?? this.alertMinCellVoltage,
      alertMinCellVoltagePos: alertMinCellVoltagePos ?? this.alertMinCellVoltagePos,
      alertMaxTemp:           alertMaxTemp           ?? this.alertMaxTemp,
      alertMaxTempPos:        alertMaxTempPos        ?? this.alertMaxTempPos,
      alertLowestTemp:        alertLowestTemp        ?? this.alertLowestTemp,
      alertMinTempPos:        alertMinTempPos        ?? this.alertMinTempPos,
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
    if (isAlertsResponse) {
      sb.write(', cycles=$alertCycleCount, cycleTimeAtFault=$alertCycleTimeAtFault'
          ', statusAtFault=$alertBatteryStatusLabel'
          ', failedAt=$alertFailureTimestampDisplay'
          ', alert=$alertNameLabel($alertTypeLabel, id=0x${(alertFaultId ?? 0).toRadixString(16).toUpperCase().padLeft(2, "0")}, prio=$alertPriorityLabel)'
          ', action=$alertFaultActionLabel'
          ', $alertTotalVoltageDisplay, $alertCurrentDisplay, soc=$alertSocDisplay'
          ', maxCell=$alertMaxCellVoltageDisplay(#$alertMaxCellVoltagePos)'
          ', minCell=$alertMinCellVoltageDisplay(#$alertMinCellVoltagePos)'
          ', maxTemp=$alertMaxTempDisplay(#$alertMaxTempPos)'
          ', minTemp=$alertLowestTempDisplay(#$alertMinTempPos)');
    }
    sb.write(')');
    return sb.toString();
  }
}
