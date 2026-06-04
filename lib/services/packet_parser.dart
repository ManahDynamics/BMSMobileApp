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
  unexpectedResponse, // Response dataId does not match any pending request
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

    // 86-byte full dashboard response  (0xAA … 0xBB)
    if (bytes.length == BMSProtocol.dashboardResponseLength && isBmsFrame) {
      return _parseDashboardResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 19-byte device-info packet  (0xAA … 0xBB)
    if (bytes.length == 19 && isBmsFrame) {
      return _parseDeviceInfoPacket(bytes, lastSentDataId: lastSentDataId);
    }

    // 12-byte legacy Packet4  (0xAA … 0xBB)
    if (bytes.length == 12 && isBmsFrame) {
      return _parseLegacyPacket4(bytes, lastSentDataId: lastSentDataId);
    }

    // 5-byte control packet  (ACK / Handshake / Disconnect)
    if (bytes.length == 5) {
      return _parseControlPacket(bytes);
    }

    return const BMSParseResult.failure(BMSParseError.invalidLength);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REQUEST / RESPONSE ID MATCHING
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<int, int> _expectedResponseId = {
    BMSProtocol.idHandshake:          BMSProtocol.idAck,
    BMSProtocol.idAutoRefresh:        BMSProtocol.idPacket4,
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
  // 12-BYTE LEGACY PACKET4
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseLegacyPacket4(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int crc    = bytes[10] & 0xFF;
    final int stop   = bytes[11] & 0xFF;

    if (lastSentDataId != null && !_responseMatchesRequest(lastSentDataId, dataId)) {
      debugPrint('⚠️  RESPONSE MISMATCH [legacy Packet4] '
          'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    final crcData     = bytes.sublist(1, 10);
    final computedCrc = BMSCrcService.calculateCRC8(crcData);
    if (computedCrc != crc) {
      debugPrint('❌ CRC MISMATCH [Packet4] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [Packet4]');

    final int rawVoltage      = (bytes[3] & 0xFF) | ((bytes[4] & 0xFF) << 8);
    final double totalVoltage = rawVoltage / 10.0;
    final int rawCurrent      = (bytes[5] & 0xFF) | ((bytes[6] & 0xFF) << 8);
    final double totalCurrent = _decodeSigned16(rawCurrent) / 10.0;
    final int soc             = bytes[7] & 0xFF;
    final int rawCapacity     = (bytes[8] & 0xFF) | ((bytes[9] & 0xFF) << 8);
    final double remainingCapacity = rawCapacity / 10.0;
    final double totalPower   = totalVoltage * totalCurrent;

    debugPrint('🔢 Packet4 → V=${totalVoltage}V  A=${totalCurrent}A  SOC=$soc%  Cap=${remainingCapacity}Ah  P=${totalPower}W');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:         start,
      length:            length,
      dataId:            dataId,
      crc:               crc,
      stopByte:          stop,
      rawBytes:          Uint8List.fromList(bytes),
      receivedAt:        DateTime.now(),
      soc:               soc,
      totalVoltage:      totalVoltage,
      totalCurrent:      totalCurrent,
      remainingCapacity: remainingCapacity,
      totalPower:        totalPower,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 86-BYTE DASHBOARD RESPONSE  (dataId 0x52)
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseDashboardResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int stop   = bytes[85] & 0xFF;

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

    final crcData         = bytes.sublist(1, 83);
    final int computedCrc = BMSCrcService.calculateCRC8(crcData);
    final int receivedCrcLow = bytes[83] & 0xFF;
    if (computedCrc != receivedCrcLow) {
      debugPrint('❌ CRC MISMATCH [Dashboard] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${receivedCrcLow.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${receivedCrcLow.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [Dashboard Response]');

    final batterySerial   = _decodeAscii(bytes, 3,  17);
    final softwareVersion = _decodeAscii(bytes, 17, 31);
    final hardwareVersion = _decodeAscii(bytes, 31, 45);
    final snCode          = _decodeAscii(bytes, 45, 59);

    final int soc               = bytes[59] & 0xFF;
    final int batteryStatusCode = bytes[60] & 0xFF;
    final int rawCapacity       = _bigEndian16(bytes, 61);
    final double remainingCapacity = rawCapacity / 10.0;
    final int healthCode        = bytes[63] & 0xFF;
    final int rawVoltage        = _bigEndian16(bytes, 64);
    final double totalVoltage   = rawVoltage / 10.0;
    final int rawCurrent        = _bigEndian16(bytes, 66);
    final double totalCurrent   = _decodeSigned16(rawCurrent) / 10.0;
    final int rawTemp           = _bigEndian16(bytes, 68);
    final double temperature    = _decodeSigned16(rawTemp).toDouble();
    final int rawPower          = _bigEndian16(bytes, 70);
    final double powerKw        = _decodeSigned16(rawPower) / 10.0;
    final double totalPower     = powerKw * 1000.0;
    final int totalCells        = bytes[72] & 0xFF;
    final int rawCycles         = _bigEndian16(bytes, 73);
    final int rawAvgVoltage     = _bigEndian16(bytes, 75);
    final double avgCellVoltage = rawAvgVoltage / 1000.0;
    final int rawVoltDiff       = _bigEndian16(bytes, 77);
    final double voltageDiff    = rawVoltDiff / 1000.0;
    final int rawMaxVoltage     = _bigEndian16(bytes, 79);
    final double maxCellVoltage = rawMaxVoltage / 1000.0;
    final int rawMinVoltage     = _bigEndian16(bytes, 81);
    final double minCellVoltage = rawMinVoltage / 1000.0;

    debugPrint('📊 Dashboard → '
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
      crc:               receivedCrcLow,
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
  // Structure:
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
  //   Byte 15       : Cell 1 Balancing (0x01=Active, 0x02=Inactive)
  //   [repeat for cells 2–24, each = 3 bytes]
  //   Bytes 85–86   : CRC (big-endian)
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

    // ── Request/response match check ───────────────────────────────────────
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

    // ── CRC validation: covers bytes[1..84] ────────────────────────────────
    // CRC is 2 bytes at [85..86]; use low byte for CRC-8 comparison.
    final crcData         = bytes.sublist(1, BMSProtocol.cellCrcHigh);
    final int computedCrc = BMSCrcService.calculateCRC8(crcData);
    final int receivedCrcLow = bytes[BMSProtocol.cellCrcLow] & 0xFF;

    if (computedCrc != receivedCrcLow) {
      debugPrint('❌ CRC MISMATCH [CellVoltage] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${receivedCrcLow.toRadixString(16).toUpperCase().padLeft(2,"0")} — IGNORED');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${receivedCrcLow.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC OK [Cell Voltage Response]');

    // ── Summary fields ─────────────────────────────────────────────────────
    final int rawMaxVoltage    = _bigEndian16(bytes, BMSProtocol.cellMaxVoltageHigh);
    final double maxVoltage    = rawMaxVoltage / 1000.0;
    final int maxVoltageNo     = bytes[BMSProtocol.cellMaxVoltageCellNo] & 0xFF;

    final int rawMinVoltage    = _bigEndian16(bytes, BMSProtocol.cellMinVoltageHigh);
    final double minVoltage    = rawMinVoltage / 1000.0;
    final int minVoltageNo     = bytes[BMSProtocol.cellMinVoltageCellNo] & 0xFF;

    final int rawAvgVoltage    = _bigEndian16(bytes, BMSProtocol.cellAvgVoltageHigh);
    final double avgVoltage    = rawAvgVoltage / 1000.0;

    final int balancingByte    = bytes[BMSProtocol.cellBalancingByte] & 0xFF;
    final bool balancingActive = balancingByte == BMSProtocol.balancingActive;

    final int totalCells       = bytes[BMSProtocol.cellTotalCellsByte] & 0xFF;

    // ── Per-cell data ──────────────────────────────────────────────────────
    // Guard: max 24 cells, and we must not read past byte 84 (before CRC)
    final int safeCells = totalCells.clamp(0, 24);
    final List<double> voltages   = [];
    final List<bool>   balancing  = [];

    for (int i = 0; i < safeCells; i++) {
      final int base = BMSProtocol.cellDataStart + i * BMSProtocol.cellDataStride;
      // Safety: ensure we don't read past the CRC area (byte 84)
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
      startByte:          start,
      length:             length,
      dataId:             dataId,
      crc:                receivedCrcLow,
      stopByte:           stop,
      rawBytes:           Uint8List.fromList(bytes),
      receivedAt:         DateTime.now(),
      // Cell voltage fields
      cellVoltages:       voltages,
      cellBalancing:      balancing,
      cellMaxVoltage:     maxVoltage,
      cellMaxVoltageNo:   maxVoltageNo,
      cellMinVoltage:     minVoltage,
      cellMinVoltageNo:   minVoltageNo,
      cellAvgVoltage:     avgVoltage,
      cellBalancingActive: balancingActive,
      cellTotalCells:     totalCells,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 19-BYTE DEVICE INFO PACKET
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
      debugPrint('❌ CRC MISMATCH [DeviceInfo 0x${dataId.toRadixString(16).toUpperCase()}] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}');
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