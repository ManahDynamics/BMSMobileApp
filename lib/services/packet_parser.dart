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

    // ── Decode Packet 4 (DataID 0x51) fields ─────────────────────────────
    double? totalVoltage;
    double? totalCurrent;
    int?    soc;
    double? remainingCapacity;

    if (dataId == 0x51) {
      // ── Total Voltage (Byte 3–4) little-endian, always positive ──────────
      // Range: 0 to 100.0V
      final int rawVoltage = (bytes[3] & 0xFF) | ((bytes[4] & 0xFF) << 8);
      totalVoltage = rawVoltage / 10.0;

      // ── Total Current (Byte 5–6) little-endian, SIGNED 16-bit ────────────
      // Range: -3276.8A to +3276.7A
      // MSB (bit 15) = 1 → negative number (2's complement)
      // MSB (bit 15) = 0 → positive number
      //
      // Example: FF97 → MSB=1 → negative
      //   2's complement: 0xFFFF - 0xFF97 + 1 = 0x0069 = 105 → -10.5A
      final int rawCurrent = (bytes[5] & 0xFF) | ((bytes[6] & 0xFF) << 8);
      totalCurrent = _decodeSigned16(rawCurrent) / 10.0;

      // ── SOC (Byte 7) ──────────────────────────────────────────────────────
      // Range: 0 to 100%
      soc = bytes[7] & 0xFF;

      // ── Remaining Capacity (Byte 8–9) little-endian, always positive ──────
      // Range: 0 to 100.0Ah
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

  // ── Signed 16-bit decoder (2's complement) ────────────────────────────────
  //
  // Checks MSB (bit 15):
  //   if (value & 0x8000) → negative → apply 2's complement
  //   else                → positive → return as-is
  //
  // Examples:
  //   0x0001 →  +1   →  +0.1A
  //   0x7FFF → +32767 → +3276.7A
  //   0xFFFF → -1    →  -0.1A
  //   0xFF97 → -105  →  -10.5A
  //   0x8000 → -32768 → -3276.8A
  static int _decodeSigned16(int raw) {
    if (raw & 0x8000 != 0) {
      // Negative: apply 2's complement
      // = -(0xFFFF - raw + 1)
      return -(0xFFFF - raw + 1);
    }
    return raw; // Positive: return as-is
  }

  static BMSParsedPacket? tryParse(List<int> bytes) => parse(bytes).packet;
}