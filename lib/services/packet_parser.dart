// lib/services/packet_parser.dart

import 'dart:typed_data';
import 'protocol.dart';
import 'crc_service.dart';
import 'parsed_packet.dart';
// ← No packet4_data.dart import needed anymore

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
      totalVoltage      = (bytes[3] | (bytes[4] << 8)) / 10.0;  // 602  → 60.2 V
      totalCurrent      = (bytes[5] | (bytes[6] << 8)) / 10.0;  // 306  → 30.6 A
      soc               =  bytes[7];                             // 52   → 52 %
      remainingCapacity = (bytes[8] | (bytes[9] << 8)) / 10.0;  // 220  → 22.0 Ah
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

  static BMSParsedPacket? tryParse(List<int> bytes) => parse(bytes).packet;
}