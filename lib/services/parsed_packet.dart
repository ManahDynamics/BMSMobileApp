// lib/services/bms/bms_parsed_packet.dart

import 'dart:typed_data';
import 'protocol.dart';

enum PacketDirection { send, receive }

class BMSParsedPacket {
  final int             startByte;
  final int             length;
  final int             dataId;
  final int             crc;
  final int             stopByte;
  final Uint8List       rawBytes;
  final DateTime        receivedAt;
  final PacketDirection? direction;

  const BMSParsedPacket({
    required this.startByte,
    required this.length,
    required this.dataId,
    required this.crc,
    required this.stopByte,
    required this.rawBytes,
    required this.receivedAt,
    this.direction,
  });

  bool get isHandshake  => dataId == BMSProtocol.idHandshake;
  bool get isAck        => dataId == BMSProtocol.idAck;
  bool get isDisconnect => dataId == BMSProtocol.idDisconnect;

  // Always returns a String — no type mismatch possible
  String get directionLabel {
    if (direction == PacketDirection.send)    return 'Mobile → BMS';
    if (direction == PacketDirection.receive) return 'BMS → Mobile';
    return (startByte == BMSProtocol.startByte) ? 'Mobile → BMS' : 'BMS → Mobile';
  }

  String get typeName => BMSProtocol.dataIdName(dataId);

  BMSParsedPacket copyWith({
    int?             startByte,
    int?             length,
    int?             dataId,
    int?             crc,
    int?             stopByte,
    Uint8List?       rawBytes,
    DateTime?        receivedAt,
    PacketDirection? direction,
  }) {
    return BMSParsedPacket(
      startByte:  startByte  ?? this.startByte,
      length:     length     ?? this.length,
      dataId:     dataId     ?? this.dataId,
      crc:        crc        ?? this.crc,
      stopByte:   stopByte   ?? this.stopByte,
      rawBytes:   rawBytes   ?? this.rawBytes,
      receivedAt: receivedAt ?? this.receivedAt,
      direction:  direction  ?? this.direction,
    );
  }
}