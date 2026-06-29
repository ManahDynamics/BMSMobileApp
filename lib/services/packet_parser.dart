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
  // 115-BYTE DASHBOARD RESPONSE v2 (dataId 0x52)
  //
  // ✅ CONFIRMED FROM LIVE CAPTURE: CRC-16/CCITT (poly 0x1021, init 0xFFFF),
  //    little-endian, computed over bytes[1..110] — i.e. Length through
  //    Cleared Alerts, EXCLUDING Total Alerts (byte 111), the CRC bytes
  //    themselves, and the stop byte.
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

    final List<int> crcData = bytes.sublist(1, BMSProtocol.dashTotalAlertsByte); // 1 to 110
    final int computedCrc   = BMSCrcService.calculateCRC16(crcData);
    final int receivedCrc   =
        (bytes[BMSProtocol.dashCrcLowByte] & 0xFF) |
        ((bytes[BMSProtocol.dashCrcHighByte] & 0xFF) << 8);

    debugPrint('🔍 Dashboard v2 CRC:'
        ' computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}'
        ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(4,"0")}');

    if (computedCrc != receivedCrc) {
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail: 'computed=0x${computedCrc.toRadixString(16).toUpperCase()}'
            ' received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
      );
    }
    debugPrint('✅ CRC16 OK [Dashboard v2]');

    final batteryType   = _decodeAscii(bytes, BMSProtocol.dashBatteryTypeStart,   BMSProtocol.dashBatteryTypeEnd);
    final batterySerial = _decodeAscii(bytes, BMSProtocol.dashBatterySerialStart, BMSProtocol.dashBatterySerialEnd);

    final int soc                  = bytes[BMSProtocol.dashSocByte] & 0xFF;
    final int batteryStatusCode    = bytes[BMSProtocol.dashBatteryStatusByte] & 0xFF;
    final int rawCapacity          = _littleEndian16(bytes, BMSProtocol.dashCapacityHigh);
    final double remainingCapacity = rawCapacity / 10.0;
    final int rawCycles            = _littleEndian16(bytes, BMSProtocol.dashCyclesHigh);
    final int healthCode           = bytes[BMSProtocol.dashHealthByte] & 0xFF;
    final int rawVoltage           = _littleEndian16(bytes, BMSProtocol.dashVoltageHigh);
    final double totalVoltage      = rawVoltage / 10.0;
    final int rawCurrent           = _littleEndian16(bytes, BMSProtocol.dashCurrentHigh);
    final double totalCurrent      = _decodeSigned16(rawCurrent) / 10.0;
    final int rawTemp              = _littleEndian16(bytes, BMSProtocol.dashTempHigh);
    final double temperature       = _decodeSigned16(rawTemp).toDouble();
    final int rawPower             = _littleEndian16(bytes, BMSProtocol.dashPowerHigh);
    final double totalPower        = _decodeSigned16(rawPower) / 10.0 * 1000.0;
    final int totalCells           = bytes[BMSProtocol.dashTotalCellsByte] & 0xFF;

    final int safeCells = totalCells.clamp(0, BMSProtocol.dashCellDataMaxCells);
    final List<double> cellVoltages = [];
    for (int i = 0; i < safeCells; i++) {
      final int base = BMSProtocol.dashCellDataStart + i * BMSProtocol.dashCellDataStride;
      final int rawV = _littleEndian16(bytes, base);
      cellVoltages.add(rawV / 1000.0);
    }

    final int rawAvgVoltage     = _littleEndian16(bytes, BMSProtocol.dashAvgVoltageHigh);
    final double avgCellVoltage = rawAvgVoltage / 1000.0;
    final int rawVoltDiff       = _littleEndian16(bytes, BMSProtocol.dashVoltDiffHigh);
    final double voltageDiff    = rawVoltDiff / 1000.0;
    final int rawMaxVoltage     = _littleEndian16(bytes, BMSProtocol.dashMaxVoltageHigh);
    final double maxCellVoltage = rawMaxVoltage / 1000.0;
    final int rawMinVoltage     = _littleEndian16(bytes, BMSProtocol.dashMinVoltageHigh);
    final double minCellVoltage = rawMinVoltage / 1000.0;

    final int warningAlerts = bytes[BMSProtocol.dashWarningAlertsByte] & 0xFF;
    final int faultAlerts   = bytes[BMSProtocol.dashFaultAlertsByte] & 0xFF;
    final int clearedAlerts = bytes[BMSProtocol.dashClearedAlertsByte] & 0xFF;
    final int totalAlerts   = bytes[BMSProtocol.dashTotalAlertsByte] & 0xFF;

    debugPrint('📊 Dashboard v2 → '
        'Serial=$batterySerial | SOC=$soc% | V=${totalVoltage}V | '
        'A=${totalCurrent}A | Cells=$totalCells | Status=$batteryStatusCode | '
        'Alerts(W/F/C/T)=$warningAlerts/$faultAlerts/$clearedAlerts/$totalAlerts');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:         start,
      length:            length,
      dataId:            dataId,
      crc:               receivedCrc,
      stopByte:          stop,
      rawBytes:          Uint8List.fromList(bytes),
      receivedAt:        DateTime.now(),
      batteryType:       batteryType.isNotEmpty   ? batteryType   : null,
      batterySerial:     batterySerial.isNotEmpty ? batterySerial : null,
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
      cellVoltages:      cellVoltages,
      warningAlerts:     warningAlerts,
      faultAlerts:       faultAlerts,
      clearedAlerts:     clearedAlerts,
      totalAlerts:       totalAlerts,
    ));
  }
  //____________________________________________
  //cell voltages packet
  //_____________________________________________
  static BMSParseResult _parseCellVoltageResponse(
  List<int> bytes, {
  int? lastSentDataId,
}) {
  final int start  = bytes[0] & 0xFF;
  final int length = bytes[1] & 0xFF;
  final int dataId = bytes[2] & 0xFF;
  final int stop   = bytes[BMSProtocol.cellStopByte] & 0xFF;

  if (lastSentDataId != null &&
      !_responseMatchesRequest(lastSentDataId, dataId)) {
    debugPrint('⚠️ RESPONSE MISMATCH [Cell Voltage]');
    return BMSParseResult.failure(
      BMSParseError.unexpectedResponse,
      errorDetail:
          'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2, "0")}'
          ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2, "0")}',
    );
  }

  // CRC16 over bytes[1..83]
  final crcData = bytes.sublist(1, 84);

  final int computedCrc = BMSCrcService.calculateCRC16(crcData);

  final int receivedCrc =
      (bytes[BMSProtocol.cellCrcLow] & 0xFF) |
      ((bytes[BMSProtocol.cellCrcHigh] & 0xFF) << 8);

  debugPrint(
    '🔍 Cell Voltage CRC: '
    'computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(4, "0")} '
    'received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(4, "0")}',
  );

  if (computedCrc != receivedCrc) {
    return BMSParseResult.failure(
      BMSParseError.crcMismatch,
      errorDetail:
          'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
          'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
    );
  }

  debugPrint('✅ CRC16 OK [Cell Voltage]');

  final double maxVoltage =
      _littleEndian16(bytes, BMSProtocol.cellMaxVoltageHigh) / 1000.0;

  final int maxVoltageNo =
      bytes[BMSProtocol.cellMaxVoltageCellNo] & 0xFF;

  final double minVoltage =
      _littleEndian16(bytes, BMSProtocol.cellMinVoltageHigh) / 1000.0;

  final int minVoltageNo =
      bytes[BMSProtocol.cellMinVoltageCellNo] & 0xFF;

  final double avgVoltage =
      _littleEndian16(bytes, BMSProtocol.cellAvgVoltageHigh) / 1000.0;

  final bool balancingActive =
      (bytes[BMSProtocol.cellBalancingByte] &
              0xFF) ==
          BMSProtocol.balancingActive;

  final int totalCells =
      bytes[BMSProtocol.cellTotalCellsByte] & 0xFF;

  final int safeCells = totalCells.clamp(0, 24);

  final List<double> cellVoltages = [];
  final List<bool> cellBalancing = [];

  for (int i = 0; i < safeCells; i++) {
    final int base =
        BMSProtocol.cellDataStart + (i * BMSProtocol.cellDataStride);

    final int rawVoltage = _littleEndian16(bytes, base);

    cellVoltages.add(rawVoltage / 1000.0);

    cellBalancing.add(
      (bytes[base + 2] & 0xFF) ==
          BMSProtocol.balancingActive,
    );
  }

  debugPrint(
      '📊 Cell Voltage Response -> Cells=$safeCells '
      'Max=$maxVoltage '
      'Min=$minVoltage '
      'Avg=$avgVoltage');

  return BMSParseResult.success(
    BMSParsedPacket(
      startByte: start,
      length: length,
      dataId: dataId,
      crc: receivedCrc,
      stopByte: stop,
      rawBytes: Uint8List.fromList(bytes),
      receivedAt: DateTime.now(),
      cellVoltages: cellVoltages,
      cellBalancing: cellBalancing,
      cellMaxVoltage: maxVoltage,
      cellMaxVoltageNo: maxVoltageNo,
      cellMinVoltage: minVoltage,
      cellMinVoltageNo: minVoltageNo,
      cellAvgVoltage: avgVoltage,
      cellBalancingActive: balancingActive,
      cellTotalCells: totalCells,
    ),
  );
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

 static int _littleEndian16(List<int> bytes, int offset) =>
    (bytes[offset] & 0xFF) |
    ((bytes[offset + 1] & 0xFF) << 8);

  static String _decodeAscii(List<int> bytes, int start, int end) =>
      String.fromCharCodes(
        bytes.sublist(start, end).where((b) => b != 0 && b != 0x20),
      ).trim();

  static BMSParsedPacket? tryParse(List<int> bytes,
          {int? lastSentDataId}) =>
      parse(bytes, lastSentDataId: lastSentDataId).packet;
}