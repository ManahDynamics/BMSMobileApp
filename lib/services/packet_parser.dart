// lib/services/packet_parser.dart

import 'package:flutter/foundation.dart';
import 'dart:typed_data';

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

    // 115-byte dashboard response
    if (bytes.length == BMSProtocol.dashboardResponseLength && isBmsFrame) {
      return _parseDashboardResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 21-byte BLE Name response
    if (bytes.length == BMSProtocol.bleNameResponseLength && isBmsFrame) {
      return _parseBleNameResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // 70-byte Device Details response
    if (bytes.length == BMSProtocol.deviceDetailsResponseLength && isBmsFrame) {
      return _parseDeviceDetailsPacket(bytes, lastSentDataId: lastSentDataId);
    }

    // 37-byte Alerts Details response (dataId 0x56)
    // NOTE: gated on both exact length AND dataId, following the same
    // pattern as the settings packets below — this protects against any
    // other 37-byte family colliding on length alone.
    if (bytes.length == BMSProtocol.alertsResponseLength &&
        isBmsFrame &&
        (bytes[2] & 0xFF) == BMSProtocol.idAlertsResponse) {
      return _parseAlertsResponse(bytes, lastSentDataId: lastSentDataId);
    }

    // ── Settings packets ─────────────────────────────────────────────────
    // FIXED: this dispatch previously switched on dataId ALONE, with no
    // length check. Since these settings IDs (0x58/0x59/0x5A/0x5B) reuse
    // byte values from other parts of the protocol, a same-ID-but-wrong-
    // length packet would have been parsed by the wrong function and could
    // index past the end of `bytes` (RangeError) or silently produce
    // garbage. Every case below now also confirms the exact expected length
    // before dispatching, exactly like the length checks above.
    if (bytes.length == BMSProtocol.batterySettingsResponseLength &&
        (bytes[2] & 0xFF) == BMSProtocol.idBatterySettingsResponse) {
      return _parseBatterySettingsPacket(bytes);
    }
    if (bytes.length == BMSProtocol.protectionSettingsResponseLength &&
        (bytes[2] & 0xFF) == BMSProtocol.idProtectionSettingsResponse) {
      return _parseProtectionSettingsPacket(bytes);
    }
    if (bytes.length == BMSProtocol.temperatureSettingsResponseLength &&
        (bytes[2] & 0xFF) == BMSProtocol.idTemperatureSettingsResponse) {
      return _parseTemperatureSettingsPacket(bytes);
    }
    if (bytes.length == BMSProtocol.factorySettingsResponseLength &&
        (bytes[2] & 0xFF) == BMSProtocol.idFactorySettingsResponse) {
      return _parseFactorySettingsPacket(bytes);
    }

    // 5-byte control packet (handshake/ACK/disconnect/requests/actions)
    if (bytes.length == 5) {
      return _parseControlPacket(bytes);
    }

    return BMSParseResult.failure(
      BMSParseError.invalidLength,
      errorDetail: 'Unexpected length: ${bytes.length}',
    );
  }

  static BMSParseResult _parseBatterySettingsPacket(List<int> bytes) {
    final int receivedCrc = bytes[BMSProtocol.batterySettingsCrcByte] & 0xFF;

    final int computedCrc = BMSCrcService.calculateCRC8(
      bytes.sublist(1, BMSProtocol.batterySettingsCrcByte),
    );

    if (receivedCrc != computedCrc) {
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail:
            'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
            'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
      );
    }

    return BMSParseResult.success(
      BMSParsedPacket(
        startByte: bytes[0],
        length: bytes[1],
        dataId: bytes[2],
        crc: receivedCrc,
        stopByte: bytes[BMSProtocol.batterySettingsStopByte],
        rawBytes: Uint8List.fromList(bytes),
        receivedAt: DateTime.now(),

        batteryString: bytes[BMSProtocol.battStringByte] & 0xFF,
        ratedCapacity: _littleEndian16(bytes, BMSProtocol.battRatedCapacityHi) / 10.0,
        socSet: bytes[BMSProtocol.battSocSetByte] & 0xFF,
        sleepWaitingTime: _littleEndian16(bytes, BMSProtocol.battSleepWaitingHi),
        balancedStartDiffVolt: _littleEndian16(bytes, BMSProtocol.battBalancedDiffHi) / 1000.0,
        balancedStartVolt: _littleEndian16(bytes, BMSProtocol.battBalancedStartHi) / 1000.0,
        nominalCellVoltage: _littleEndian16(bytes, BMSProtocol.battNominalCellHi) / 1000.0,
        cellChemistry: bytes[BMSProtocol.battCellChemistryByte] & 0xFF,
      ),
    );
  }

  static BMSParseResult _parseProtectionSettingsPacket(List<int> bytes) {
    final int receivedCrc = bytes[BMSProtocol.protectionSettingsCrcByte] & 0xFF;

    final int computedCrc = BMSCrcService.calculateCRC8(
      bytes.sublist(1, BMSProtocol.protectionSettingsCrcByte),
    );

    if (computedCrc != receivedCrc) {
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail:
            'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
            'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
      );
    }

    final packet = BMSParsedPacket(
      startByte: bytes[0],
      length: bytes[1],
      dataId: bytes[2],
      crc: receivedCrc,
      stopByte: bytes[BMSProtocol.protectionSettingsStopByte],
      rawBytes: Uint8List.fromList(bytes),
      receivedAt: DateTime.now(),

      singleCellHighVoltProtection:
          _littleEndian16(bytes, BMSProtocol.protSingleCellHighHi) / 1000.0,
      singleCellLowVoltProtection:
          _littleEndian16(bytes, BMSProtocol.protSingleCellLowHi) / 1000.0,
      sumVoltHighProtection:
          _littleEndian16(bytes, BMSProtocol.protSumVoltHighHi) / 10.0,
      sumVoltLowProtection:
          _littleEndian16(bytes, BMSProtocol.protSumVoltLowHi) / 10.0,
      chargeOverCurrentProtection:
          _littleEndian16(bytes, BMSProtocol.protChargeOcHi) / 10.0,
      dischargeOverCurrentProtection:
          _littleEndian16(bytes, BMSProtocol.protDischargeOcHi) / 10.0,
    );

    return BMSParseResult.success(packet);
  }

  // as a 2-byte little-endian value at offsets that didn't match the
  // spec's 11-byte packet at all (it read past where the CRC/Stop actually
  // are). Per the screenshot, every field here is a single BYTE — the high
  // fields (charge/discharge-high, diff) are 0..200°C (fits uint8), and the
  // low fields (charge/discharge-low) are 0..-60°C, so they're decoded as
  // signed 8-bit (two's complement).
  static BMSParseResult _parseTemperatureSettingsPacket(List<int> bytes) {
    final int receivedCrc = bytes[BMSProtocol.temperatureSettingsCrcByte] & 0xFF;

    final int computedCrc = BMSCrcService.calculateCRC8(
      bytes.sublist(1, BMSProtocol.temperatureSettingsCrcByte),
    );

    if (computedCrc != receivedCrc) {
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail:
            'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
            'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
      );
    }

    final packet = BMSParsedPacket(
      startByte: bytes[0],
      length: bytes[1],
      dataId: bytes[2],
      crc: receivedCrc,
      stopByte: bytes[BMSProtocol.temperatureSettingsStopByte],
      rawBytes: Uint8List.fromList(bytes),
      receivedAt: DateTime.now(),

      noOfTempChannels: bytes[BMSProtocol.tempNoOfChannelsByte] & 0xFF,
      chargeHighTempProtection: bytes[BMSProtocol.tempChargeHighByte] & 0xFF,
      chargeLowTempProtection: _decodeSigned8(bytes[BMSProtocol.tempChargeLowByte] & 0xFF),
      dischargeHighTempProtection: bytes[BMSProtocol.tempDischargeHighByte] & 0xFF,
      dischargeLowTempProtection: _decodeSigned8(bytes[BMSProtocol.tempDischargeLowByte] & 0xFF),
      diffTempProtection: bytes[BMSProtocol.tempDiffByte] & 0xFF,
    );

    return BMSParseResult.success(packet);
  }
static BMSParseResult _parseFactorySettingsPacket(List<int> bytes) {
  final receivedCrc =
      (bytes[BMSProtocol.factorySettingsCrcLow] & 0xFF) |
      ((bytes[BMSProtocol.factorySettingsCrcHigh] & 0xFF) << 8);

  final computedCrc = BMSCrcService.calculateCRC16(
    bytes.sublist(1, BMSProtocol.factorySettingsCrcLow),
  );

  if (receivedCrc != computedCrc) {
    return BMSParseResult.failure(
      BMSParseError.crcMismatch,
      errorDetail:
          'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
          'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
    );
  }

  final packet = BMSParsedPacket(
    startByte: bytes[0],
    length: bytes[1],
    dataId: bytes[2],
    crc: receivedCrc,
    stopByte: bytes[BMSProtocol.factorySettingsStopByte],
    rawBytes: Uint8List.fromList(bytes),
    receivedAt: DateTime.now(),

    batterySlNo: _decodeAscii(bytes, BMSProtocol.facBatterySlStart, BMSProtocol.facBatterySlEnd),
    bmsSerialNo: _decodeAscii(bytes, BMSProtocol.facBmsSerialStart, BMSProtocol.facBmsSerialEnd),
    bleDeviceName: _decodeAscii(bytes, BMSProtocol.facBleNameStart, BMSProtocol.facBleNameEnd),
  );

  return BMSParseResult.success(packet);
}
  // ─────────────────────────────────────────────────────────────────────────
  // 37-BYTE ALERTS DETAILS RESPONSE (dataId 0x56) — CRC-16, little-endian
  //
  // Layout (per protocol screenshot):
  //   0     Start byte (0xAA)
  //   1     Length (0x0D at spec position, but full frame is 37 bytes)
  //   2     Data ID (0x56)
  //   3-4   Cycle Count            (LE16)
  //   5-6   Cycle Time @ Fault     (LE16)
  //   7     Battery Status @ Fault (1=Charging,2=Discharging,3=Storage,
  //                                  4=Ideal,5=Sleep)
  //   8     Failure date
  //   9     Failure month
  //   10-11 Failure year           (LE16)
  //   12    Failure hour
  //   13    Failure minute
  //   15    Fault ID / Alert ID    (1 to 38 — see BMSAlertCatalogue)
  //   16    Fault Action           (0x01 = Disappear)
  //   17-18 Total Voltage          (LE16, ×0.1 V)
  //   19-20 Current                (LE16 signed, ×0.1 A)
  //   21    SoC                    (%)
  //   22-23 Max Cell Voltage       (LE16, ×0.001 V)
  //   24    Max Cell Voltage Position
  //   25-26 Min Cell Voltage       (LE16, ×0.001 V)
  //   27    Min Cell Voltage Position
  //   28-29 Max Temp               (LE16 signed, ×0.1 °C)
  //   30    Max Temp Position
  //   31-32 Lowest Temp            (LE16 signed, ×0.1 °C)
  //   33    Min Temp Position
  //   34-35 CRC-16                 (LE16)
  //   36    Stop byte (0xBB)
  //
  // Byte 14 is unused/reserved per the spec table and is skipped.
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseAlertsResponse(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final int start  = bytes[0] & 0xFF;
    final int length = bytes[1] & 0xFF;
    final int dataId = bytes[2] & 0xFF;
    final int stop   = bytes[BMSProtocol.alertsStopByte] & 0xFF;

    if (lastSentDataId != null &&
        !_responseMatchesRequest(lastSentDataId, dataId)) {
      debugPrint('⚠️ RESPONSE MISMATCH [Alerts]');
      return BMSParseResult.failure(
        BMSParseError.unexpectedResponse,
        errorDetail:
            'sent=0x${lastSentDataId.toRadixString(16).toUpperCase().padLeft(2, "0")}'
            ' got=0x${dataId.toRadixString(16).toUpperCase().padLeft(2, "0")}',
      );
    }

    final int receivedCrc =
        (bytes[BMSProtocol.alertsCrcLow] & 0xFF) |
        ((bytes[BMSProtocol.alertsCrcHigh] & 0xFF) << 8);
    final int computedCrc =
        BMSCrcService.calculateCRC16(bytes.sublist(1, BMSProtocol.alertsCrcLow));

    debugPrint('🔍 Alerts CRC:'
        ' computed=0x${computedCrc.toRadixString(16).toUpperCase().padLeft(4, "0")}'
        ' received=0x${receivedCrc.toRadixString(16).toUpperCase().padLeft(4, "0")}');

    if (computedCrc != receivedCrc) {
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail:
            'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
            'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
      );
    }
    debugPrint('✅ CRC16 OK [Alerts Details Response]');

    final int cycleCount        = _littleEndian16(bytes, 3);
    final int cycleTimeAtFault  = _littleEndian16(bytes, 5);
    final int batteryStatusCode = bytes[7] & 0xFF;
    final int failureDate       = bytes[8] & 0xFF;
    final int failureMonth      = bytes[9] & 0xFF;
    final int failureYear       = _littleEndian16(bytes, 10);
    final int failureHour       = bytes[12] & 0xFF;
    final int failureMinute     = bytes[13] & 0xFF;
    final int faultId           = bytes[15] & 0xFF;
    final int faultActionCode   = bytes[16] & 0xFF;

    final double totalVoltage = _littleEndian16(bytes, 17) / 10.0;
    final double current      = _decodeSigned16(_littleEndian16(bytes, 19)) / 10.0;
    final int soc              = bytes[21] & 0xFF;

    final double maxCellVoltage    = _littleEndian16(bytes, 22) / 1000.0;
    final int maxCellVoltagePos    = bytes[24] & 0xFF;
    final double minCellVoltage    = _littleEndian16(bytes, 25) / 1000.0;
    final int minCellVoltagePos    = bytes[27] & 0xFF;

    final double maxTemp    = _decodeSigned16(_littleEndian16(bytes, 28)) / 10.0;
    final int maxTempPos    = bytes[30] & 0xFF;
    final double lowestTemp = _decodeSigned16(_littleEndian16(bytes, 31)) / 10.0;
    final int minTempPos    = bytes[33] & 0xFF;

    return BMSParseResult.success(
      BMSParsedPacket(
        startByte: start,
        length: length,
        dataId: dataId,
        crc: receivedCrc,
        stopByte: stop,
        rawBytes: Uint8List.fromList(bytes),
        receivedAt: DateTime.now(),

        alertCycleCount: cycleCount,
        alertCycleTimeAtFault: cycleTimeAtFault,
        alertBatteryStatusCode: batteryStatusCode,
        alertFailureDate: failureDate,
        alertFailureMonth: failureMonth,
        alertFailureYear: failureYear,
        alertFailureHour: failureHour,
        alertFailureMinute: failureMinute,
        alertFaultId: faultId,
        alertFaultActionCode: faultActionCode,
        alertTotalVoltage: totalVoltage,
        alertCurrent: current,
        alertSoc: soc,
        alertMaxCellVoltage: maxCellVoltage,
        alertMaxCellVoltagePos: maxCellVoltagePos,
        alertMinCellVoltage: minCellVoltage,
        alertMinCellVoltagePos: minCellVoltagePos,
        alertMaxTemp: maxTemp,
        alertMaxTempPos: maxTempPos,
        alertLowestTemp: lowestTemp,
        alertMinTempPos: minTempPos,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REQUEST / RESPONSE ID MATCHING
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<int, int> _expectedResponseId = {
    BMSProtocol.idHandshake: BMSProtocol.idAck,
    BMSProtocol.idBleNameRequest: BMSProtocol.idBleNameResponse,
    BMSProtocol.idDashboardRequest: BMSProtocol.idDashboardResponse,
    BMSProtocol.idCellVoltageRequest: BMSProtocol.idCellVoltageResponse,
    BMSProtocol.idDeviceDetailsRequest: BMSProtocol.idDeviceDetailsResponse,
    BMSProtocol.idBatterySettingsRequest: BMSProtocol.idBatterySettingsResponse,
    BMSProtocol.idProtectionSettingsRequest: BMSProtocol.idProtectionSettingsResponse,
    BMSProtocol.idTemperatureSettingsRequest: BMSProtocol.idTemperatureSettingsResponse,
    BMSProtocol.idFactorySettingsRequest: BMSProtocol.idFactorySettingsResponse,
    BMSProtocol.idAlertsRequest: BMSProtocol.idAlertsResponse,
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
    final double temperature       = _decodeSigned16(rawTemp) / 10.0;
    final int rawPower             = _littleEndian16(bytes, BMSProtocol.dashPowerHigh);
    final double totalPower        = _decodeSigned16(rawPower) / 1000.0;
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

  // ─────────────────────────────────────────────────────────────────────────
  // 88-BYTE CELL VOLTAGE RESPONSE
  // ─────────────────────────────────────────────────────────────────────────
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

    final crcData = bytes.sublist(1, 84);
    final int computedCrc = BMSCrcService.calculateCRC16(crcData);
    final int receivedCrc =
        (bytes[BMSProtocol.cellCrcLow] & 0xFF) |
        ((bytes[BMSProtocol.cellCrcHigh] & 0xFF) << 8);

    if (computedCrc != receivedCrc) {
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail:
            'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
            'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
      );
    }

    final double maxVoltage =
        _littleEndian16(bytes, BMSProtocol.cellMaxVoltageHigh) / 1000.0;
    final int maxVoltageNo = bytes[BMSProtocol.cellMaxVoltageCellNo] & 0xFF;
    final double minVoltage =
        _littleEndian16(bytes, BMSProtocol.cellMinVoltageHigh) / 1000.0;
    final int minVoltageNo = bytes[BMSProtocol.cellMinVoltageCellNo] & 0xFF;
    final double avgVoltage =
        _littleEndian16(bytes, BMSProtocol.cellAvgVoltageHigh) / 1000.0;
    final bool balancingActive =
        (bytes[BMSProtocol.cellBalancingByte] & 0xFF) == BMSProtocol.balancingActive;
    final int totalCells = bytes[BMSProtocol.cellTotalCellsByte] & 0xFF;
    final int safeCells = totalCells.clamp(0, 24);

    final List<double> cellVoltages = [];
    final List<bool> cellBalancing = [];
    for (int i = 0; i < safeCells; i++) {
      final int base = BMSProtocol.cellDataStart + (i * BMSProtocol.cellDataStride);
      final int rawVoltage = _littleEndian16(bytes, base);
      cellVoltages.add(rawVoltage / 1000.0);
      cellBalancing.add((bytes[base + 2] & 0xFF) == BMSProtocol.balancingActive);
    }

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
  // 70-BYTE DEVICE DETAILS RESPONSE (dataId 0x57) — CRC-16, little-endian
  // ─────────────────────────────────────────────────────────────────────────
  static BMSParseResult _parseDeviceDetailsPacket(
    List<int> bytes, {
    int? lastSentDataId,
  }) {
    final receivedCrc =
        (bytes[BMSProtocol.deviceDetailsCrcLow] & 0xFF) |
        ((bytes[BMSProtocol.deviceDetailsCrcHigh] & 0xFF) << 8);

    final computedCrc =
        BMSCrcService.calculateCRC16(bytes.sublist(1, BMSProtocol.deviceDetailsCrcLow-1));

    if (receivedCrc != computedCrc) {
      return BMSParseResult.failure(
        BMSParseError.crcMismatch,
        errorDetail:
            'computed=0x${computedCrc.toRadixString(16).toUpperCase()} '
            'received=0x${receivedCrc.toRadixString(16).toUpperCase()}',
      );
    }

    return BMSParseResult.success(
      BMSParsedPacket(
        startByte: bytes[0],
        length: bytes[1],
        dataId: bytes[2],
        crc: receivedCrc,
        stopByte: bytes[BMSProtocol.deviceDetailsStop],
        rawBytes: Uint8List.fromList(bytes),
        receivedAt: DateTime.now(),

        batterySerial: _decodeAscii(bytes, BMSProtocol.deviceSerialStart, BMSProtocol.deviceSerialEnd),
        softwareVersion: _decodeAscii(bytes, BMSProtocol.softwareVersionStart, BMSProtocol.softwareVersionEnd),
        hardwareVersion: _decodeAscii(bytes, BMSProtocol.hardwareVersionStart, BMSProtocol.hardwareVersionEnd),
        firmwareVersion: _decodeAscii(bytes, BMSProtocol.firmwareVersionStart, BMSProtocol.firmwareVersionEnd),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  static int _decodeSigned16(int raw) {
    final r = raw & 0xFFFF;
    return (r & 0x8000) != 0 ? -(0x10000 - r) : r;
  }

  static int _decodeSigned8(int raw) {
    final r = raw & 0xFF;
    return (r & 0x80) != 0 ? -(0x100 - r) : r;
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
