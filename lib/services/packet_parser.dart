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

    // ── Route by length ───────────────────────────────────────────────────

    // 88-byte cell voltage response (0xAA … 0xBB)
    if (bytes.length == BMSProtocol.cellVoltageResponseLength && isBmsFrame) {
      return _parseCellVoltageResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 86-byte full dashboard response (0xAA … 0xBB)
    if (bytes.length == BMSProtocol.dashboardResponseLength && isBmsFrame) {
      return _parseDashboardResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 19-byte BLE Name response (0xAA … 0xBB)
    if (bytes.length == BMSProtocol.bleNameResponseLength && isBmsFrame) {
      return _parseBleNameResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 5-byte control packet (ACK / Handshake / Disconnect / requests)
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
  //
  // Structure:
  //   Byte 0       : 0xAA (start)
  //   Byte 1       : 0x13 (length)
  //   Byte 2       : 0x51 (Data ID)
  //   Bytes 3–16   : BLE Name (14 ASCII bytes)
  //   Byte 17      : CRC
  //   Byte 18      : 0xBB (stop)
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
      debugPrint('⚠️  RESPONSE MISMATCH [BLE Name] '
          'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    // CRC covers bytes[1..16]
    final crcData     = bytes.sublist(1, 17);
    final computedCrc = BMSCrcService.calculateCRC8(crcData);
    if (computedCrc != crc) {
      debugPrint('❌ CRC MISMATCH [BLE Name] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}');
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
  // 86-BYTE DASHBOARD RESPONSE  (dataId 0x52)
  //
  // Structure per spec:
  //   Byte 0       : 0xAA (start)
  //   Byte 1       : 0x55 (length)
  //   Byte 2       : 0x52 (Data ID)
  //   Bytes 3–16   : Battery Serial No  (14 ASCII bytes)
  //   Bytes 17–30  : Software Version   (14 ASCII bytes)
  //   Bytes 31–44  : Hardware Version   (14 ASCII bytes)
  //   Bytes 45–58  : SN Code            (14 ASCII bytes)
  //   Byte 59      : SOC (0–100%)
  //   Byte 60      : Battery Status
  //   Bytes 61–62  : Remaining Capacity (×0.1 Ah, big-endian)
  //   Byte 63      : Health
  //   Bytes 64–65  : Total Voltage (×0.1 V, big-endian)
  //   Bytes 66–67  : Total Current (signed ×0.1 A, big-endian)
  //   Bytes 68–69  : Temperature (signed °C, big-endian)
  //   Bytes 70–71  : Power in KW (signed ×0.1 KW, big-endian)
  //   Byte 72      : Total Cells
  //   Bytes 73–74  : Charge/Discharge Cycles (big-endian)
  //   Bytes 75–76  : Avg Cell Voltage (×0.001 V, big-endian)
  //   Bytes 77–78  : Voltage Difference (×0.001 V, big-endian)
  //   Bytes 79–80  : Max Cell Voltage (×0.001 V, big-endian)
  //   Bytes 81–82  : Min Cell Voltage (×0.001 V, big-endian)
  //   Bytes 83–84  : CRC (big-endian; compare low byte for CRC-8)
  //   Byte 85      : 0xBB (stop)
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
      debugPrint('⚠️  RESPONSE MISMATCH [Dashboard] '
          'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    // CRC covers bytes[1..82] (i.e. from length byte up to and not including CRC bytes)
    final crcData         = bytes.sublist(1, BMSProtocol.dashCrcHigh);
    final int computedCrc = BMSCrcService.calculateCRC8(crcData);
    final int receivedCrc = bytes[BMSProtocol.dashCrcLow] & 0xFF; // use low byte

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
    final batterySerial   = _decodeAscii(bytes, BMSProtocol.dashBatterySerialStart,   BMSProtocol.dashBatterySerialEnd);
    final softwareVersion = _decodeAscii(bytes, BMSProtocol.dashSoftwareVersionStart, BMSProtocol.dashSoftwareVersionEnd);
    final hardwareVersion = _decodeAscii(bytes, BMSProtocol.dashHardwareVersionStart, BMSProtocol.dashHardwareVersionEnd);
    final snCode          = _decodeAscii(bytes, BMSProtocol.dashSnCodeStart,          BMSProtocol.dashSnCodeEnd);

    // ── Numeric fields ────────────────────────────────────────────────────
    final int soc                  = bytes[BMSProtocol.dashSocByte] & 0xFF;
    final int batteryStatusCode    = bytes[BMSProtocol.dashBatteryStatusByte] & 0xFF;
    final int rawCapacity          = _bigEndian16(bytes, BMSProtocol.dashCapacityHigh);
    final double remainingCapacity = rawCapacity / 10.0;
    final int healthCode           = bytes[BMSProtocol.dashHealthByte] & 0xFF;
    final int rawVoltage           = _bigEndian16(bytes, BMSProtocol.dashVoltageHigh);
    final double totalVoltage      = rawVoltage / 10.0;
    final int rawCurrent           = _bigEndian16(bytes, BMSProtocol.dashCurrentHigh);
    final double totalCurrent      = _decodeSigned16(rawCurrent) / 10.0;
    final int rawTemp              = _bigEndian16(bytes, BMSProtocol.dashTempHigh);
    final double temperature       = _decodeSigned16(rawTemp).toDouble();
    final int rawPower             = _bigEndian16(bytes, BMSProtocol.dashPowerHigh);
    // Spec: power in KW (×0.1 KW), convert to Watts for internal storage
    final double totalPower        = _decodeSigned16(rawPower) / 10.0 * 1000.0;
    final int totalCells           = bytes[BMSProtocol.dashTotalCellsByte] & 0xFF;
    final int rawCycles            = _bigEndian16(bytes, BMSProtocol.dashCyclesHigh);
    final int rawAvgVoltage        = _bigEndian16(bytes, BMSProtocol.dashAvgVoltageHigh);
    final double avgCellVoltage    = rawAvgVoltage / 1000.0;
    final int rawVoltDiff          = _bigEndian16(bytes, BMSProtocol.dashVoltDiffHigh);
    final double voltageDiff       = rawVoltDiff / 1000.0;
    final int rawMaxVoltage        = _bigEndian16(bytes, BMSProtocol.dashMaxVoltageHigh);
    final double maxCellVoltage    = rawMaxVoltage / 1000.0;
    final int rawMinVoltage        = _bigEndian16(bytes, BMSProtocol.dashMinVoltageHigh);
    final double minCellVoltage    = rawMinVoltage / 1000.0;

    debugPrint('📊 Dashboard → '
        'Serial=$batterySerial | SW=$softwareVersion | HW=$hardwareVersion | '
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
      snCode:            snCode.isNotEmpty           ? snCode           : null,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 88-BYTE CELL VOLTAGE RESPONSE  (dataId 0x53)
  //
  // Structure per spec:
  //   Byte 0        : 0xAA (start)
  //   Byte 1        : 0x57 (length)
  //   Byte 2        : 0x53 (Data ID)
  //   Bytes 3–4     : Max Voltage (×0.001 V, big-endian)
  //   Byte 5        : Max Voltage Cell No (1–24)
  //   Bytes 6–7     : Min Voltage (×0.001 V, big-endian)
  //   Byte 8        : Min Voltage Cell No (1–24)
  //   Bytes 9–10    : Avg Voltage (×0.001 V, big-endian)
  //   Byte 11       : Overall Balancing (0x01=Active, 0x02=Inactive)
  //   Byte 12       : Total Cells (min 6, max 24)
  //   Bytes 13–14   : Cell 1 Voltage (×0.001 V, big-endian)
  //   Byte 15       : Cell 1 Balancing
  //   [repeat ×24 cells, 3 bytes each]
  //   Bytes 85–86   : CRC (use low byte 86 for CRC-8)
  //   Byte 87       : 0xBB (stop)
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
      debugPrint('⚠️  RESPONSE MISMATCH [CellVoltage] '
          'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    // CRC covers bytes[1..84]; compare against low byte (byte 86)
    final crcData            = bytes.sublist(1, BMSProtocol.cellCrcHigh);
    final int computedCrc    = BMSCrcService.calculateCRC8(crcData);
    final int receivedCrc    = bytes[BMSProtocol.cellCrcLow] & 0xFF;

    if (computedCrc != receivedCrc) {
      debugPrint('❌ CRC MISMATCH [CellVoltage] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [Cell Voltage Response]');

    // ── Summary fields ────────────────────────────────────────────────────
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

    // ── Per-cell data ─────────────────────────────────────────────────────
    final int safeCells       = totalCells.clamp(0, 24);
    final List<double> voltages  = [];
    final List<bool>   balancing = [];

    for (int i = 0; i < safeCells; i++) {
      final int base = BMSProtocol.cellDataStart + i * BMSProtocol.cellDataStride;
      // Guard: don't read into CRC area (bytes 85+)
      if (base + 1 >= BMSProtocol.cellCrcHigh) break;

      final int rawV    = _bigEndian16(bytes, base);
      final double volt = rawV / 1000.0;
      final int balByte = bytes[base + 2] & 0xFF;
      final bool active = balByte == BMSProtocol.balancingActive;

      voltages.add(volt);
      balancing.add(active);
    }

    debugPrint('🔋 Cell Voltage Response → '
        'Cells=$totalCells | Max=${maxVoltage}V(#$maxVoltageNo) | '
        'Min=${minVoltage}V(#$minVoltageNo) | Avg=${avgVoltage}V | '
        'Balancing=${balancingActive ? "Active" : "Inactive"}');
    for (int i = 0; i < voltages.length; i++) {
      debugPrint('   Cell ${(i + 1).toString().padLeft(2, "0")}: '
          '${voltages[i].toStringAsFixed(3)}V '
          '| ${balancing[i] ? "Balancing" : "–"}');
    }

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
      debugPrint('⚠️  RESPONSE MISMATCH [DeviceInfo] '
          'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
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