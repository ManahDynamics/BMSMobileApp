// lib/services/bms/bms_parsed_packet.dart

import 'dart:typed_data';
import 'protocol.dart';

class BMSParsedPacket {
  final int       startByte;
  final int       length;
  final int       dataId;
  final int       crc;
  final int       stopByte;
  final Uint8List rawBytes;
  final DateTime  receivedAt;

  const BMSParsedPacket({
    required this.startByte,
    required this.length,
    required this.dataId,
    required this.crc,
    required this.stopByte,
    required this.rawBytes,
    required this.receivedAt,
  });

  // ── Packet type checks ────────────────────────────────────────────────────
  bool get isHandshake  => dataId == BMSProtocol.idHandshake;
  bool get isAck        => dataId == BMSProtocol.idAck;
  bool get isDisconnect => dataId == BMSProtocol.idDisconnect;

  /// "Mobile → BMS" or "BMS → Mobile"
  String get direction =>
      (startByte == BMSProtocol.startByte) ? 'Mobile → BMS' : 'BMS → Mobile';

  /// Human-readable packet type name
  String get typeName => BMSProtocol.dataIdName(dataId);
}