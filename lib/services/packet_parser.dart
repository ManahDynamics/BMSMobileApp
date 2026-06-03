// lib/services/packet_parser.dart
import 'protocol.dart';
import 'crc_service.dart';
import 'parsed_packet.dart';
import 'package:flutter/foundation.dart';

enum BMSParseError { tooShort, invalidFraming, invalidLength, crcMismatch }

class BMSParseResult {
  final BMSParsedPacket? packet;
  final BMSParseError?   error;

  const BMSParseResult.success(this.packet) : error = null;
  const BMSParseResult.failure(this.error)  : packet = null;

  bool get isSuccess => packet != null;
}

class BMSPacketParser {
  BMSPacketParser._();

  static BMSParseResult parse(List<int> bytes) {
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

    // ── 19-byte device-info packet (BMS → mobile) ─────────────────────────
    // Structure: 0xAA 0x13 <dataId 0x59–0x5C> <14 ASCII bytes> <CRC> 0xBB
    if (bytes.length == 19 && isBmsFrame) {
      return _parseDeviceInfoPacket(bytes);
    }

    // ── 12-byte data packet (BMS → mobile) ───────────────────────────────
    if (bytes.length == 12 && isBmsFrame) {
      return _parseDataPacket(bytes);
    }

    // ── 5-byte control packet (ACK / Handshake / Disconnect) ─────────────
    if (bytes.length == 5) {
      return _parseControlPacket(bytes);
    }

    return const BMSParseResult.failure(BMSParseError.invalidLength);
  }

  // ── 5-byte control packet ─────────────────────────────────────────────────
  static BMSParseResult _parseControlPacket(List<int> bytes) {
    final int length = bytes[BMSProtocol.indexLength] & 0xFF;
    final int dataId = bytes[BMSProtocol.indexDataId] & 0xFF;
    final int crc    = bytes[BMSProtocol.indexCrc]    & 0xFF;
    final int start  = bytes[BMSProtocol.indexStart]  & 0xFF;
    final int stop   = bytes[BMSProtocol.indexStop]   & 0xFF;

    if (length != BMSProtocol.packetLength) {
      return const BMSParseResult.failure(BMSParseError.invalidLength);
    }
    if (!BMSCrcService.verifyCRC8([length, dataId], crc)) {
      return const BMSParseResult.failure(BMSParseError.crcMismatch);
    }

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

  // ── 12-byte data packet ───────────────────────────────────────────────────
  static BMSParseResult _parseDataPacket(List<int> bytes) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int crc    = bytes[10] & 0xFF;
    final int stop   = bytes[11] & 0xFF;

    // CRC covers bytes[1..9] — Length + DataId + 7 data bytes
    if (!BMSCrcService.verifyCRC8(bytes.sublist(1, 10), crc)) {
      return const BMSParseResult.failure(BMSParseError.crcMismatch);
    }

    double? totalVoltage;
    double? totalCurrent;
    int?    soc;
    double? remainingCapacity;

    if (dataId == 0x51) {
      final int rawVoltage  = (bytes[3] & 0xFF) | ((bytes[4] & 0xFF) << 8);
      totalVoltage = rawVoltage / 10.0;

      final int rawCurrent  = (bytes[5] & 0xFF) | ((bytes[6] & 0xFF) << 8);
      totalCurrent = _decodeSigned16(rawCurrent) / 10.0;

      soc = bytes[7] & 0xFF;

      final int rawCapacity = (bytes[8] & 0xFF) | ((bytes[9] & 0xFF) << 8);
      remainingCapacity = rawCapacity / 10.0;

      debugPrint('🔢 Raw Current bytes: '
          '${(bytes[5] & 0xFF).toRadixString(16).toUpperCase().padLeft(2,"0")} '
          '${(bytes[6] & 0xFF).toRadixString(16).toUpperCase().padLeft(2,"0")} '
          '→ rawCurrent=0x${rawCurrent.toRadixString(16).toUpperCase().padLeft(4,"0")} '
          '→ ${totalCurrent}A');
    }

    return BMSParseResult.success(BMSParsedPacket(
      startByte:         start,
      length:            length,
      dataId:            dataId,
      crc:               crc,
      stopByte:          stop,
      rawBytes:          Uint8List.fromList(bytes),
      receivedAt:        DateTime.now(),
      totalVoltage:      totalVoltage,
      totalCurrent:      totalCurrent,
      soc:               soc,
      remainingCapacity: remainingCapacity,
    ));
  }

  // ── 19-byte device-info packet ────────────────────────────────────────────
  // Structure: 0xAA 0x13 <dataId> <14 ASCII bytes (Byte 3–16)> <CRC> 0xBB
  // Supported dataIds: 0x59 (Battery Serial), 0x5A (SW Version),
  //                    0x5B (HW Version),     0x5C (SN Code)
  static BMSParseResult _parseDeviceInfoPacket(List<int> bytes) {
    final int start  = bytes[0]  & 0xFF;
    final int length = bytes[1]  & 0xFF;
    final int dataId = bytes[2]  & 0xFF;
    final int crc    = bytes[17] & 0xFF;
    final int stop   = bytes[18] & 0xFF;

    // Validate dataId is one of the four known device-info IDs
    const validIds = {0x59, 0x5A, 0x5B, 0x5C};
    if (!validIds.contains(dataId)) {
      return const BMSParseResult.failure(BMSParseError.invalidLength);
    }

    // CRC covers bytes[1..16] — Length + DataId + 14 ASCII bytes
    if (!BMSCrcService.verifyCRC8(bytes.sublist(1, 17), crc)) {
      return const BMSParseResult.failure(BMSParseError.crcMismatch);
    }

    // Decode bytes 3–16 as ASCII, stripping null padding
    final asciiBytes = bytes.sublist(3, 17);
    final value = String.fromCharCodes(asciiBytes.where((b) => b != 0)).trim();

    debugPrint('📋 Device Info [0x${dataId.toRadixString(16).toUpperCase()}]: "$value"');

    return BMSParseResult.success(BMSParsedPacket(
      startByte:         start,
      length:            length,
      dataId:            dataId,
      crc:               crc,
      stopByte:          stop,
      rawBytes:          Uint8List.fromList(bytes),
      receivedAt:        DateTime.now(),
      batterySerial:     dataId == 0x59 ? value : null,
      softwareVersion:   dataId == 0x5A ? value : null,
      hardwareVersion:   dataId == 0x5B ? value : null,
      snCode:            dataId == 0x5C ? value : null,
    ));
  }

  // ── Signed 16-bit decoder (2's complement) ────────────────────────────────
  static int _decodeSigned16(int raw) {
    if (raw & 0x8000 != 0) return -(0xFFFF - raw + 1);
    return raw;
  }

  static BMSParsedPacket? tryParse(List<int> bytes) => parse(bytes).packet;
}