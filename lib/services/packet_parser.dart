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
  //
  // [lastSentDataId] — the Data ID of the most recently sent request packet.
  //   Pass it so the parser can reject responses that don't match the request.
  //   Pass null to skip the request/response matching check (e.g. for ACK).
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
  //
  // Maps each request Data ID to the expected response Data ID.
  // ACK (0x50) is always accepted regardless of last sent ID.
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<int, int> _expectedResponseId = {
    BMSProtocol.idHandshake:        BMSProtocol.idAck,
    BMSProtocol.idAutoRefresh:      BMSProtocol.idPacket4,
    BMSProtocol.idDashboardRequest: BMSProtocol.idDashboardResponse,
    BMSProtocol.idBatterySerial:    BMSProtocol.idBatterySerial,
    BMSProtocol.idSoftwareVersion:  BMSProtocol.idSoftwareVersion,
    BMSProtocol.idHardwareVersion:  BMSProtocol.idHardwareVersion,
    BMSProtocol.idSnCode:           BMSProtocol.idSnCode,
  };

  /// Returns true if the incoming [responseDataId] is valid for [sentDataId].
  static bool _responseMatchesRequest(int sentDataId, int responseDataId) {
    // ACK is always valid (e.g. after handshake)
    if (responseDataId == BMSProtocol.idAck) return true;
    final expected = _expectedResponseId[sentDataId];
    return expected == responseDataId;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5-BYTE CONTROL PACKET  (ACK / Handshake / Disconnect)
  // Structure: [start] [length=0x05] [dataId] [CRC] [stop]
  // CRC covers: [length, dataId]
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

    // ── CRC validation ─────────────────────────────────────────────────────
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
  // 12-BYTE LEGACY PACKET4  (dataId 0x51)
  // Structure: [0xAA] [len] [0x51] [V_L] [V_H] [A_L] [A_H] [SOC]
  //            [Cap_L] [Cap_H] [CRC] [0xBB]
  // CRC covers: bytes[1..9]
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

    // ── Request/response match check ───────────────────────────────────────
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

    // ── CRC validation: covers bytes[1..9] ─────────────────────────────────
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

    // ── Parse fields ───────────────────────────────────────────────────────
    final int rawVoltage  = (bytes[3] & 0xFF) | ((bytes[4] & 0xFF) << 8);
    final double totalVoltage = rawVoltage / 10.0;

    final int rawCurrent  = (bytes[5] & 0xFF) | ((bytes[6] & 0xFF) << 8);
    final double totalCurrent = _decodeSigned16(rawCurrent) / 10.0;

    final int soc = bytes[7] & 0xFF;

    final int rawCapacity = (bytes[8] & 0xFF) | ((bytes[9] & 0xFF) << 8);
    final double remainingCapacity = rawCapacity / 10.0;

    final double totalPower = totalVoltage * totalCurrent;

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
  //
  // Structure (per spec):
  //   Byte 0        : 0xAA (start)
  //   Byte 1        : Length
  //   Byte 2        : 0x52 (Data ID)
  //   Bytes  3–16   : Battery Serial No  (14 ASCII bytes)
  //   Bytes 17–30   : Software Version   (14 ASCII bytes)
  //   Bytes 31–44   : Hardware Version   (14 ASCII bytes)
  //   Bytes 45–58   : SN Code            (14 ASCII bytes)
  //   Byte 59       : SOC (0–100)
  //   Byte 60       : Battery Status (0x01/0x02/0x03)
  //   Bytes 61–62   : Remaining Capacity (×0.1 Ah, big-endian)
  //   Byte 63       : Health (0x01/0x02)
  //   Bytes 64–65   : Total Voltage (×0.1 V, big-endian)
  //   Bytes 66–67   : Total Current (signed ×0.1 A, big-endian)
  //   Bytes 68–69   : Temperature (signed °C, big-endian)
  //   Bytes 70–71   : Power in KW (signed ×0.1 KW, big-endian) → stored as W
  //   Byte 72       : Total Cells
  //   Bytes 73–74   : Charge/Discharge Cycles (big-endian)
  //   Bytes 75–76   : Avg Cell Voltage (×0.001 V, big-endian)
  //   Bytes 77–78   : Voltage Difference (×0.001 V, big-endian)
  //   Bytes 79–80   : Max Cell Voltage (×0.001 V, big-endian)
  //   Bytes 81–82   : Min Cell Voltage (×0.001 V, big-endian)
  //   Bytes 83–84   : CRC (covers bytes 1–82)
  //   Byte 85       : 0xBB (stop)
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseDashboardResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int stop   = bytes[85] & 0xFF;

    // ── Request/response match check ───────────────────────────────────────
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

    // ── CRC validation ─────────────────────────────────────────────────────
    // Spec: CRC covers bytes 1–82 (length + dataId + all data, before CRC bytes)
    // CRC is stored as 2 bytes at [83..84]; we treat them as a 16-bit value.
    // For CRC-8: use only byte[83] as the received CRC; byte[84] may be padding.
    // Adjust if your firmware uses a 16-bit CRC across both bytes.
    final crcData        = bytes.sublist(1, 83); // bytes[1] to bytes[82] inclusive
    final int computedCrc = BMSCrcService.calculateCRC8(crcData);

    // Compare low byte first (CRC-8 result); if firmware uses 16-bit CRC,
    // compare the full receivedCrc against computedCrc (which will be 0–255).
    // Using low-byte comparison for CRC-8:
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

    // ── ASCII device info fields ───────────────────────────────────────────
    final batterySerial   = _decodeAscii(bytes, 3,  17);
    final softwareVersion = _decodeAscii(bytes, 17, 31);
    final hardwareVersion = _decodeAscii(bytes, 31, 45);
    final snCode          = _decodeAscii(bytes, 45, 59);

    // ── Numeric fields ─────────────────────────────────────────────────────
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

    // Power in KW (signed ×0.1 KW) → convert to Watts for display
    final int rawPower          = _bigEndian16(bytes, 70);
    final double powerKw        = _decodeSigned16(rawPower) / 10.0;
    final double totalPower     = powerKw * 1000.0; // W

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
      // Store low byte of CRC field for reference
      crc:               receivedCrcLow,
      stopByte:          stop,
      rawBytes:          Uint8List.fromList(bytes),
      receivedAt:        DateTime.now(),
      // Shared fields
      soc:               soc,
      totalVoltage:      totalVoltage,
      totalCurrent:      totalCurrent,
      remainingCapacity: remainingCapacity,
      totalPower:        totalPower,
      // Dashboard-only fields
      batteryStatusCode: batteryStatusCode,
      healthCode:        healthCode,
      temperature:       temperature,
      totalCells:        totalCells,
      chargeCycles:      rawCycles,
      avgCellVoltage:    avgCellVoltage,
      voltageDiff:       voltageDiff,
      maxCellVoltage:    maxCellVoltage,
      minCellVoltage:    minCellVoltage,
      // Device info embedded in dashboard packet
      batterySerial:     batterySerial.isNotEmpty   ? batterySerial   : null,
      softwareVersion:   softwareVersion.isNotEmpty ? softwareVersion : null,
      hardwareVersion:   hardwareVersion.isNotEmpty ? hardwareVersion : null,
      snCode:            snCode.isNotEmpty           ? snCode           : null,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 19-BYTE DEVICE INFO PACKET  (dataId 0x59–0x5C)
  // Structure: [0xAA] [0x13] [dataId] [14 ASCII bytes] [CRC] [0xBB]
  // CRC covers: bytes[1..16]
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

    // ── Request/response match check ───────────────────────────────────────
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

    // ── CRC validation: covers bytes[1..16] ────────────────────────────────
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

  /// Signed 16-bit (two's complement)
  static int _decodeSigned16(int raw) {
    final r = raw & 0xFFFF;
    return (r & 0x8000) != 0 ? -(0x10000 - r) : r;
  }

  /// Big-endian 16-bit unsigned from [bytes] starting at [offset]
  static int _bigEndian16(List<int> bytes, int offset) =>
      ((bytes[offset] & 0xFF) << 8) | (bytes[offset + 1] & 0xFF);

  /// Decode ASCII from bytes[start..end) stripping null/space padding
  static String _decodeAscii(List<int> bytes, int start, int end) =>
      String.fromCharCodes(
        bytes.sublist(start, end).where((b) => b != 0 && b != 0x20),
      ).trim();

  static BMSParsedPacket? tryParse(List<int> bytes, {int? lastSentDataId}) =>
      parse(bytes, lastSentDataId: lastSentDataId).packet;
}