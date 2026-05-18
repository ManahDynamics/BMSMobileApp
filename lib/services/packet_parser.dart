// lib/services/bms/bms_packet_parser.dart

import 'dart:typed_data';
import 'protocol.dart';
import 'crc_service.dart';
import 'parsed_packet.dart';

// ── Parse error reasons ───────────────────────────────────────────────────────
enum BMSParseError {
  tooShort,
  invalidFraming,
  invalidLength,
  crcMismatch,
}

// ── Parse result wrapper ──────────────────────────────────────────────────────
class BMSParseResult {
  final BMSParsedPacket? packet;
  final BMSParseError?   error;

  const BMSParseResult.success(this.packet) : error = null;
  const BMSParseResult.failure(this.error)  : packet = null;

  bool get isSuccess => packet != null;
}

// ── Parser ────────────────────────────────────────────────────────────────────
class BMSPacketParser {
  BMSPacketParser._();

  /// Parse [bytes] and return a [BMSParseResult].
  ///
  /// Validates in order:
  ///   1. Minimum 5 bytes present.
  ///   2. Start + stop bytes match a known frame direction.
  ///   3. Length field equals [BMSProtocol.packetLength].
  ///   4. CRC-8 over [start, length, dataId] matches stored CRC byte.
  static BMSParseResult parse(List<int> bytes) {
    // 1. Length guard
    if (bytes.length < 5) {
      return const BMSParseResult.failure(BMSParseError.tooShort);
    }

    final int start  = bytes[BMSProtocol.indexStart]  & 0xFF;
    final int length = bytes[BMSProtocol.indexLength]  & 0xFF;
    final int dataId = bytes[BMSProtocol.indexDataId]  & 0xFF;
    final int crc    = bytes[BMSProtocol.indexCrc]     & 0xFF;
    final int stop   = bytes[BMSProtocol.indexStop]    & 0xFF;

    // 2. Framing guard
    final bool mobileFrame =
        (start == BMSProtocol.startByte && stop == BMSProtocol.stopByte);
    final bool bmsFrame =
        (start == BMSProtocol.ackStart  && stop == BMSProtocol.ackStop);

    if (!mobileFrame && !bmsFrame) {
      return const BMSParseResult.failure(BMSParseError.invalidFraming);
    }

    // 3. Length guard
    if (length != BMSProtocol.packetLength) {
      return const BMSParseResult.failure(BMSParseError.invalidLength);
    }

    // 4. CRC guard
    if (!BMSCrcService.verifyCRC8([start, length, dataId], crc)) {
      return const BMSParseResult.failure(BMSParseError.crcMismatch);
    }

    return BMSParseResult.success(
      BMSParsedPacket(
        startByte:  start,
        length:     length,
        dataId:     dataId,
        crc:        crc,
        stopByte:   stop,
        rawBytes:   Uint8List.fromList(bytes.take(5).toList()),
        receivedAt: DateTime.now(),
      ),
    );
  }

  /// Convenience — returns the packet directly, or null on any error.
  static BMSParsedPacket? tryParse(List<int> bytes) => parse(bytes).packet;
}