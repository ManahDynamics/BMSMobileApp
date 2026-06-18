// lib/services/packet_parser.dart

import 'package:flutter/foundation.dart';

import 'protocol.dart';
import 'crc_service.dart';
import 'parsed_packet.dart';

enum BMSParseError {
  tooShort,
  invalidFraming,
  invalidLength,
  crcMismatch,
  unexpectedResponse,
  unknownDataId,
}

class BMSParseResult {
  final BMSParsedPacket? packet;
  final BMSParseError?   error;
  final String?          errorDetail;

  const BMSParseResult.success(this.packet)
      : error = null, errorDetail = null;
  const BMSParseResult.failure(this.error, {this.errorDetail})
      : packet = null;

  bool get isSuccess => packet != null;
}

class BMSPacketParser {
  BMSPacketParser._();

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC ENTRY POINT
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult parse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    if (bytes.length < 5) {
      return const BMSParseResult.failure(BMSParseError.tooShort);
    }

    final int start = bytes[0] & 0xFF;
    final int stop  = bytes[bytes.length - 1] & 0xFF;

    final bool isBmsFrame    = (start == BMSProtocol.ackStart  && stop == BMSProtocol.ackStop);
    final bool isMobileFrame = (start == BMSProtocol.startByte && stop == BMSProtocol.stopByte);

    if (!isBmsFrame && !isMobileFrame) {
      return const BMSParseResult.failure(BMSParseError.invalidFraming);
    }

    // 88-byte cell voltage response
    if (bytes.length == BMSProtocol.cellVoltageResponseLength && isBmsFrame) {
      return _parseCellVoltageResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 120-byte dashboard response (NEW)
    if (bytes.length == BMSProtocol.dashboardResponseLength && isBmsFrame) {
      return _parseDashboardResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 19-byte BLE Name response
    if (bytes.length == BMSProtocol.bleNameResponseLength && isBmsFrame) {
      return _parseBleNameResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 5-byte control packet
    if (bytes.length == 5) {
      return _parseControlPacket(bytes);
    }

    // 19-byte device-info packet (0x59–0x5C)
    if (bytes.length == 19 && isBmsFrame) {
      return _parseDeviceInfoPacket(bytes, lastSentDataId: lastSentDataId);
    }

    return BMSParseResult.failure(
      BMSParseError.invalidLength,
      errorDetail: 'Unexpected length: ${bytes.length}',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REQUEST / RESPONSE ID MATCHING
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<int, int> _expectedResponseId = {
    BMSProtocol.idHandshake:          BMSProtocol.idAck,
    BMSProtocol.idBleNameRequest:     BMSProtocol.idBleNameResponse,
    BMSProtocol.idDashboardRequest:   BMSProtocol.idDashboardResponse,
    BMSProtocol.idCellVoltageRequest: BMSProtocol.idCellVoltageResponse,
    BMSProtocol.idBatterySerial:      BMSProtocol.idBatterySerial,
    BMSProtocol.idSoftwareVersion:    BMSProtocol.idSoftwareVersion,
    BMSProtocol.idHardwareVersion:    BMSProtocol.idHardwareVersion,
    BMSProtocol.idSnCode:             BMSProtocol.idSnCode,
  };

  static bool _responseMatchesRequest(int sentDataId, int responseDataId) {
    if (responseDataId == BMSProtocol.idAck) return true;
    final expected = _expectedResponseId[sentDataId];
    return expected == responseDataId;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5-BYTE CONTROL PACKET
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseControlPacket(List<int> bytes) {
    final int start  = bytes[0] & 0xFF;
    final int length = bytes[1] & 0xFF;
    final int dataId = bytes[2] & 0xFF;
    final int crc    = bytes[3] & 0xFF;
    final int stop   = bytes[4] & 0xFF;

    if (length != BMSProtocol.packetLength) {
      return const BMSParseResult.failure(BMSParseError.invalidLength);
    }

    final int computedCrc = BMSCrcService.calculateCRC8([length, dataId]);
    if (computedCrc != crc) {
      debugPrint('❌ CRC MISMATCH [control] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [control] dataId=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:  start,
      length:     length,
      dataId:     dataId,
      crc:        crc,
      stopByte:   stop,
      rawBytes:   Uint8List.fromList(bytes),
      receivedAt: DateTime.now(),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 19-BYTE BLE NAME RESPONSE  (dataId 0x51)
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseBleNameResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int crc    = bytes[17] & 0xFF;
    final int stop   = bytes[18] & 0xFF;

    if (lastSentDataId != null && !_responseMatchesRequest(lastSentDataId, dataId)) {
      debugPrint('⚠️  RESPONSE MISMATCH [BLE Name]');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    final crcData     = bytes.sublist(1, 17);
    final computedCrc = BMSCrcService.calculateCRC8(crcData);
    if (computedCrc != crc) {
      debugPrint('❌ CRC MISMATCH [BLE Name]');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [BLE Name Response]');
    final String bleName = _decodeAscii(bytes, BMSProtocol.bleNameStart, BMSProtocol.bleNameEnd);
    debugPrint('📋 BLE Name → "$bleName"');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:  start,
      length:     length,
      dataId:     dataId,
      crc:        crc,
      stopByte:   stop,
      rawBytes:   Uint8List.fromList(bytes),
      receivedAt: DateTime.now(),
      bleName:    bleName.isNotEmpty ? bleName : null,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 120-BYTE DASHBOARD RESPONSE  (dataId 0x52)
  //
  // Byte 0        : 0xAA (start)
  // Byte 1        : 0x78 (length)
  // Byte 2        : 0x52 (Data ID)
  // Bytes 3–19    : Battery Type (17 ASCII bytes)
  // Byte 20       : SOC (0–100%)
  // Byte 21       : Battery Status
  // Bytes 22–23   : Remaining Capacity (×0.1 Ah, big-endian)
  // Bytes 24–25   : Charge/Discharge Cycles (big-endian)
  // Byte 26       : Health
  // Bytes 27–28   : Total Voltage (×0.1 V, big-endian)
  // Bytes 29–30   : Total Current (signed ×0.1 A, big-endian)
  // Bytes 31–32   : Temperature (signed °C, big-endian)
  // Bytes 33–34   : Power in KW (signed ×0.1 KW, big-endian)
  // Byte 35       : Total Cells
  // Bytes 36–37   : Avg Cell Voltage (×0.001 V, big-endian)
  // Bytes 38–39   : Voltage Difference (×0.001 V, big-endian)
  // Bytes 40–41   : Max Cell Voltage (×0.001 V, big-endian)
  // Bytes 42–43   : Min Cell Voltage (×0.001 V, big-endian)
  // Bytes 44–59   : Battery Serial No (16 ASCII bytes)
  // Bytes 60–78   : Software Version (19 ASCII bytes)
  // Bytes 79–97   : Hardware Version (19 ASCII bytes)
  // Bytes 98–116  : Firmware Version (19 ASCII bytes)
  // Bytes 117–118 : CRC (use low byte 118 for CRC-8)
  // Byte 119      : 0xBB (stop)
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseDashboardResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int stop   = bytes[BMSProtocol.dashStopByte] & 0xFF;

    if (lastSentDataId != null && !_responseMatchesRequest(lastSentDataId, dataId)) {
      debugPrint('⚠️  RESPONSE MISMATCH [Dashboard]');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    // CRC covers bytes[1..116] (up to but not including CRC bytes)
    final crcData         = bytes.sublist(1, BMSProtocol.dashCrcHigh);
    final int computedCrc = BMSCrcService.calculateCRC8(crcData);
    final int receivedCrc = bytes[BMSProtocol.dashCrcLow] & 0xFF; // use low byte (118)

    if (computedCrc != receivedCrc) {
      debugPrint('❌ CRC MISMATCH [Dashboard] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [Dashboard Response]');

    // ── ASCII fields ──────────────────────────────────────────────────────
    final batteryType     = _decodeAscii(bytes, BMSProtocol.dashBatteryTypeStart,     BMSProtocol.dashBatteryTypeEnd);
    final batterySerial   = _decodeAscii(bytes, BMSProtocol.dashBatterySerialStart,   BMSProtocol.dashBatterySerialEnd);
    final softwareVersion = _decodeAscii(bytes, BMSProtocol.dashSoftwareVersionStart, BMSProtocol.dashSoftwareVersionEnd);
    final hardwareVersion = _decodeAscii(bytes, BMSProtocol.dashHardwareVersionStart, BMSProtocol.dashHardwareVersionEnd);
    final firmwareVersion = _decodeAscii(bytes, BMSProtocol.dashFirmwareVersionStart, BMSProtocol.dashFirmwareVersionEnd);

    // ── Numeric fields ────────────────────────────────────────────────────
    final int soc                  = bytes[BMSProtocol.dashSocByte] & 0xFF;
    final int batteryStatusCode    = bytes[BMSProtocol.dashBatteryStatusByte] & 0xFF;
    final int rawCapacity          = _bigEndian16(bytes, BMSProtocol.dashCapacityHigh);
    final double remainingCapacity = rawCapacity / 10.0;
    final int rawCycles            = _bigEndian16(bytes, BMSProtocol.dashCyclesHigh);
    final int healthCode           = bytes[BMSProtocol.dashHealthByte] & 0xFF;
    final int rawVoltage           = _bigEndian16(bytes, BMSProtocol.dashVoltageHigh);
    final double totalVoltage      = rawVoltage / 10.0;
    final int rawCurrent           = _bigEndian16(bytes, BMSProtocol.dashCurrentHigh);
    final double totalCurrent      = _decodeSigned16(rawCurrent) / 10.0;
    final int rawTemp              = _bigEndian16(bytes, BMSProtocol.dashTempHigh);
    final double temperature       = _decodeSigned16(rawTemp).toDouble();
    final int rawPower             = _bigEndian16(bytes, BMSProtocol.dashPowerHigh);
    final double totalPower        = _decodeSigned16(rawPower) / 10.0 * 1000.0;
    final int totalCells           = bytes[BMSProtocol.dashTotalCellsByte] & 0xFF;
    final int rawAvgVoltage        = _bigEndian16(bytes, BMSProtocol.dashAvgVoltageHigh);
    final double avgCellVoltage    = rawAvgVoltage / 1000.0;
    final int rawVoltDiff          = _bigEndian16(bytes, BMSProtocol.dashVoltDiffHigh);
    final double voltageDiff       = rawVoltDiff / 1000.0;
    final int rawMaxVoltage        = _bigEndian16(bytes, BMSProtocol.dashMaxVoltageHigh);
    final double maxCellVoltage    = rawMaxVoltage / 1000.0;
    final int rawMinVoltage        = _bigEndian16(bytes, BMSProtocol.dashMinVoltageHigh);
    final double minCellVoltage    = rawMinVoltage / 1000.0;

    debugPrint('📊 Dashboard → '
        'Type=$batteryType | Serial=$batterySerial | SW=$softwareVersion | '
        'HW=$hardwareVersion | FW=$firmwareVersion | '
        'SOC=$soc% | V=${totalVoltage}V | A=${totalCurrent}A | '
        'Cap=${remainingCapacity}Ah | Status=$batteryStatusCode | '
        'Health=$healthCode | Temp=$temperature°C | '
        'Power=${totalPower}W | Cells=$totalCells | '
        'Cycles=$rawCycles | Avg=${avgCellVoltage}V | '
        'Diff=${voltageDiff}V | Max=${maxCellVoltage}V | Min=${minCellVoltage}V');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:         start,
      length:            length,
      dataId:            dataId,
      crc:               receivedCrc,
      stopByte:          stop,
      rawBytes:          Uint8List.fromList(bytes),
      receivedAt:        DateTime.now(),
      batteryType:       batteryType.isNotEmpty     ? batteryType     : null,
      soc:               soc,
      totalVoltage:      totalVoltage,
      totalCurrent:      totalCurrent,
      remainingCapacity: remainingCapacity,
      totalPower:        totalPower,
      batteryStatusCode: batteryStatusCode,
      healthCode:        healthCode,
      temperature:       temperature,
      totalCells:        totalCells,
      chargeCycles:      rawCycles,
      avgCellVoltage:    avgCellVoltage,
      voltageDiff:       voltageDiff,
      maxCellVoltage:    maxCellVoltage,
      minCellVoltage:    minCellVoltage,
      batterySerial:     batterySerial.isNotEmpty   ? batterySerial   : null,
      softwareVersion:   softwareVersion.isNotEmpty ? softwareVersion : null,
      hardwareVersion:   hardwareVersion.isNotEmpty ? hardwareVersion : null,
      firmwareVersion:   firmwareVersion.isNotEmpty ? firmwareVersion : null,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 88-BYTE CELL VOLTAGE RESPONSE  (dataId 0x53)
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseCellVoltageResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int stop   = bytes[BMSProtocol.cellStopByte] & 0xFF;

    if (lastSentDataId != null && !_responseMatchesRequest(lastSentDataId, dataId)) {
      debugPrint('⚠️  RESPONSE MISMATCH [CellVoltage]');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    final crcData            = bytes.sublist(1, BMSProtocol.cellCrcHigh);
    final int computedCrc    = BMSCrcService.calculateCRC8(crcData);
    final int receivedCrc    = bytes[BMSProtocol.cellCrcLow] & 0xFF;

    if (computedCrc != receivedCrc) {
      debugPrint('❌ CRC MISMATCH [CellVoltage]');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [Cell Voltage Response]');

    final int rawMaxVoltage  = _bigEndian16(bytes, BMSProtocol.cellMaxVoltageHigh);
    final double maxVoltage  = rawMaxVoltage / 1000.0;
    final int maxVoltageNo   = bytes[BMSProtocol.cellMaxVoltageCellNo] & 0xFF;

    final int rawMinVoltage  = _bigEndian16(bytes, BMSProtocol.cellMinVoltageHigh);
    final double minVoltage  = rawMinVoltage / 1000.0;
    final int minVoltageNo   = bytes[BMSProtocol.cellMinVoltageCellNo] & 0xFF;

    final int rawAvgVoltage  = _bigEndian16(bytes, BMSProtocol.cellAvgVoltageHigh);
    final double avgVoltage  = rawAvgVoltage / 1000.0;

    final int balancingByte    = bytes[BMSProtocol.cellBalancingByte] & 0xFF;
    final bool balancingActive = balancingByte == BMSProtocol.balancingActive;

    final int totalCells = bytes[BMSProtocol.cellTotalCellsByte] & 0xFF;

    final int safeCells          = totalCells.clamp(0, 24);
    final List<double> voltages  = [];
    final List<bool>   balancing = [];

    for (int i = 0; i < safeCells; i++) {
      final int base = BMSProtocol.cellDataStart + i * BMSProtocol.cellDataStride;
      if (base + 1 >= BMSProtocol.cellCrcHigh) break;

      final int rawV    = _bigEndian16(bytes, base);
      final double volt = rawV / 1000.0;
      final int balByte = bytes[base + 2] & 0xFF;
      final bool active = balByte == BMSProtocol.balancingActive;

      voltages.add(volt);
      balancing.add(active);
    }

    debugPrint('🔋 Cell Voltage → Cells=$totalCells | Max=${maxVoltage}V(#$maxVoltageNo) | '
        'Min=${minVoltage}V(#$minVoltageNo) | Avg=${avgVoltage}V');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:           start,
      length:              length,
      dataId:              dataId,
      crc:                 receivedCrc,
      stopByte:            stop,
      rawBytes:            Uint8List.fromList(bytes),
      receivedAt:          DateTime.now(),
      cellVoltages:        voltages,
      cellBalancing:       balancing,
      cellMaxVoltage:      maxVoltage,
      cellMaxVoltageNo:    maxVoltageNo,
      cellMinVoltage:      minVoltage,
      cellMinVoltageNo:    minVoltageNo,
      cellAvgVoltage:      avgVoltage,
      cellBalancingActive: balancingActive,
      cellTotalCells:      totalCells,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 19-BYTE DEVICE INFO PACKET  (dataId 0x59–0x5C)
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseDeviceInfoPacket(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int crc    = bytes[17] & 0xFF;
    final int stop   = bytes[18] & 0xFF;

    const validIds = {0x59, 0x5A, 0x5B, 0x5C};
    if (!validIds.contains(dataId)) {
      return const BMSParseResult.failure(BMSParseError.unknownDataId);
    }

    if (lastSentDataId != null && !_responseMatchesRequest(lastSentDataId, dataId)) {
      debugPrint('⚠️  RESPONSE MISMATCH [DeviceInfo]');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    final crcData     = bytes.sublist(1, 17);
    final computedCrc = BMSCrcService.calculateCRC8(crcData);
    if (computedCrc != crc) {
      debugPrint('❌ CRC MISMATCH [DeviceInfo 0x${dataId.toRadixString(16).toUpperCase()}]');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [DeviceInfo 0x${dataId.toRadixString(16).toUpperCase()}]');
    final value = _decodeAscii(bytes, 3, 17);
    debugPrint('📋 DeviceInfo → "$value"');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:       start,
      length:          length,
      dataId:          dataId,
      crc:             crc,
      stopByte:        stop,
      rawBytes:        Uint8List.fromList(bytes),
      receivedAt:      DateTime.now(),
      batterySerial:   dataId == 0x59 ? value : null,
      softwareVersion: dataId == 0x5A ? value : null,
      hardwareVersion: dataId == 0x5B ? value : null,
      snCode:          dataId == 0x5C ? value : null,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static int _decodeSigned16(int raw) {
    final r = raw & 0xFFFF;
    return (r & 0x8000) != 0 ? -(0x10000 - r) : r;
  }

  static int _bigEndian16(List<int> bytes, int offset) =>
      ((bytes[offset] & 0xFF) << 8) | (bytes[offset + 1] & 0xFF);

  static String _decodeAscii(List<int> bytes, int start, int end) =>
      String.fromCharCodes(
        bytes.sublist(start, end).where((b) => b != 0 && b != 0x20),
      ).trim();

  static BMSParsedPacket? tryParse(List<int> bytes, {int? lastSentDataId}) =>
      parse(bytes, lastSentDataId: lastSentDataId).packet;
}