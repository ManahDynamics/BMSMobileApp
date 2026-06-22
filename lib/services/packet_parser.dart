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

    // 120-byte dashboard response
    if (bytes.length == BMSProtocol.dashboardResponseLength && isBmsFrame) {
      return _parseDashboardResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 21-byte BLE Name response
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
  // 5-BYTE CONTROL PACKET (both directions)
  // Incoming ACK (BMS → Mobile) : CRC-8 over [length, dataId]
  // Outgoing    (Mobile → BMS)  : CRC-8 over [length, dataId]
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
      debugPrint('❌ CRC8 MISMATCH [control] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC8 OK [control] dataId=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}');

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
  // 21-BYTE BLE NAME RESPONSE (dataId 0x51)
  // CRC-8 over bytes[1..18] (everything except start byte, up to CRC byte)
  // CRC byte is at index 19 (BMSProtocol.bleNameCrcByte)
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseBleNameResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0] & 0xFF;
    final int length = bytes[1] & 0xFF;
    final int dataId = bytes[2] & 0xFF;
    final int crc    = bytes[BMSProtocol.bleNameCrcByte] & 0xFF; // byte 19
    final int stop   = bytes[bytes.length - 1] & 0xFF;

    // if (lastSentDataId != null &&
    //     !_responseMatchesRequest(lastSentDataId, dataId)) {
    //   return BMSParseResult.failure(
    //     BMSParseError.unexpectedResponse,
    //     errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
    //         ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
    //   );
    // }

    // CRC-8 over bytes[1..18] — everything except the start byte, up to
    // (but not including) the CRC byte itself.
    final crcData     = bytes.sublist(1, BMSProtocol.bleNameCrcByte);
    final computedCrc = BMSCrcService.calculateCRC8(crcData);
    if (computedCrc != crc) {
      debugPrint('❌ CRC8 MISMATCH [BLE Name] '
          'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")} '
          'received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC8 OK [BLE Name Response]');
    final String bleName =
        _decodeAscii(bytes, BMSProtocol.bleNameStart, BMSProtocol.bleNameEnd);

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
  // 120-BYTE DASHBOARD RESPONSE (dataId 0x52)
  //
  // ✅ CONFIRMED FROM LIVE CAPTURE: CRC is a SINGLE CRC-8 byte at index 117
  //    (BMSProtocol.dashCrcByte), computed over bytes[1..116] — i.e. every
  //    byte except the start byte, up to (not including) the CRC byte.
  //    Byte 118 is NOT part of the CRC (purpose unconfirmed, ignored here).
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseDashboardResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0] & 0xFF;
    final int length = bytes[1] & 0xFF;
    final int dataId = bytes[2] & 0xFF;
    final int stop   = bytes[BMSProtocol.dashStopByte] & 0xFF;

    if (lastSentDataId != null &&
        !_responseMatchesRequest(lastSentDataId, dataId)) {
      debugPrint('⚠️ RESPONSE MISMATCH [Dashboard]');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    // CRC-8 over bytes[1..116] (everything except the start byte, up to the
    // CRC byte itself).
    // CRC-16 Modbus (poly 0xA001, init 0xFFFF) over bytes[1..116].
// Byte 117 = low byte, Byte 118 = high byte (confirmed: B9 13 → 0x13B9).
final List<int> crcData = bytes.sublist(1, BMSProtocol.dashCrcLow);
final int computedCrc   = BMSCrcService.calculateCRC16(crcData);
final int receivedCrc   = ((bytes[BMSProtocol.dashCrcHigh] & 0xFF) << 8) |
                            (bytes[BMSProtocol.dashCrcLow]  & 0xFF);

debugPrint('🔍 Dashboard CRC check:'
    ' computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}'
    ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}');

if (computedCrc != receivedCrc) {
  return BMSParseResult.failure(
    BMSParseError.crcMismatch,
    errorDetail: 'Dashboard CRC16 mismatch. '
        'Computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
        'Received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
  );
}
debugPrint('✅ CRC16 OK [Dashboard Response]');

    // ── ASCII fields ────────────────────────────────────────────────────────
    final batteryType     = _decodeAscii(bytes, BMSProtocol.dashBatteryTypeStart,     BMSProtocol.dashBatteryTypeEnd);
    final batterySerial   = _decodeAscii(bytes, BMSProtocol.dashBatterySerialStart,   BMSProtocol.dashBatterySerialEnd);
    final softwareVersion = _decodeAscii(bytes, BMSProtocol.dashSoftwareVersionStart, BMSProtocol.dashSoftwareVersionEnd);
    final hardwareVersion = _decodeAscii(bytes, BMSProtocol.dashHardwareVersionStart, BMSProtocol.dashHardwareVersionEnd);
    final firmwareVersion = _decodeAscii(bytes, BMSProtocol.dashFirmwareVersionStart, BMSProtocol.dashFirmwareVersionEnd);

    // ── Numeric fields ──────────────────────────────────────────────────────
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
        'Serial=$batterySerial | SOC=$soc% | V=${totalVoltage}V | '
        'A=${totalCurrent}A | Cells=$totalCells | Status=$batteryStatusCode');

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
  // 88-BYTE CELL VOLTAGE RESPONSE (dataId 0x53)
  //
  // ⚠️ UNRESOLVED: CRC algorithm/position for this packet type has not been
  // confirmed against live captures yet (CRC-8 over bytes[1..84] came close
  // — 0xF7 computed vs 0xF0 actual — but did not match exactly). Left as
  // CRC-16 over bytes[1..84] for now so it fails closed rather than silently
  // accepting unverified data. This does NOT block dashboard navigation —
  // only cell-voltage detail display is affected until solved.
  // TODO: capture 2-3 more live cell-voltage packets and re-derive the CRC.
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseCellVoltageResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0] & 0xFF;
    final int length = bytes[1] & 0xFF;
    final int dataId = bytes[2] & 0xFF;
    final int stop   = bytes[BMSProtocol.cellStopByte] & 0xFF;

    // if (lastSentDataId != null &&
    //     !_responseMatchesRequest(lastSentDataId, dataId)) {
    //   debugPrint('⚠️ RESPONSE MISMATCH [CellVoltage]');
    //   return BMSParseResult.failure(
    //     BMSParseError.unexpectedResponse,
    //     errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
    //         ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
    //   );
    // }

    // CRC-16 over bytes[1..84] — NOT YET CONFIRMED, see note above.
   final List<int> crcData = bytes.sublist(1, BMSProtocol.cellCrcHigh);
final int computedCrc   = BMSCrcService.calculateCRC16(crcData);
final int receivedCrc   = ((bytes[BMSProtocol.cellCrcHigh] & 0xFF) << 8) |
                            (bytes[BMSProtocol.cellCrcLow]  & 0xFF);

debugPrint('🔍 CellVoltage CRC check:'
    ' computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}'
    ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}');

if (computedCrc != receivedCrc) {
  debugPrint('❌ CRC16 MISMATCH [CellVoltage]');
  return BMSParseResult.failure(
    BMSParseError.crcMismatch,
    errorDetail: 'CRC16 computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}'
        ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}',
  );
}
debugPrint('✅ CRC16 OK [Cell Voltage Response]');

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

    final int totalCells         = bytes[BMSProtocol.cellTotalCellsByte] & 0xFF;
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

    debugPrint('🔋 Cell Voltage → Cells=$totalCells'
        ' | Max=${maxVoltage}V(#$maxVoltageNo)'
        ' | Min=${minVoltage}V(#$minVoltageNo)'
        ' | Avg=${avgVoltage}V');

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
  // 19-BYTE DEVICE INFO PACKET (dataId 0x59–0x5C)
  // CRC-8 over bytes[1..16]
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

    if (lastSentDataId != null &&
        !_responseMatchesRequest(lastSentDataId, dataId)) {
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail: 'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    final crcData     = bytes.sublist(1, 17);
    final computedCrc = BMSCrcService.calculateCRC8(crcData);
    if (computedCrc != crc) {
      debugPrint('❌ CRC8 MISMATCH [DeviceInfo 0x${dataId.toRadixString(16).toUpperCase()}]');
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(2,"0")}'
            ' received=0x${crc.toRadixString(16).toUpperCase().padLeft(2,"0")}',
      );
    }

    debugPrint('✅ CRC8 OK [DeviceInfo 0x${dataId.toRadixString(16).toUpperCase()}]');
    final value = _decodeAscii(bytes, 3, 17);

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

  static BMSParsedPacket? tryParse(List<int> bytes,
          {int? lastSentDataId}) =>
      parse(bytes, lastSentDataId: lastSentDataId).packet;
}