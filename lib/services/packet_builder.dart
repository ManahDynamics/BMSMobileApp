// lib/services/bms/bms_packet_builder.dart

import 'dart:typed_data';
import 'protocol.dart';
import 'crc_service.dart';

class BMSPacketBuilder {
  BMSPacketBuilder._();

  /// Internal — assembles [start, length, dataId, crc, stop].
  /// CRC is computed over the first three bytes.
  static Uint8List _build({
    required int start,
    required int dataId,
    required int stop,
  }) {
    final List<int> crcInput = [
      start,
      BMSProtocol.packetLength,
      dataId,
    ];
    final int crc = BMSCrcService.calculateCRC8(crcInput);
    return Uint8List.fromList([
      start,
      BMSProtocol.packetLength,
      dataId,
      crc,
      stop,
    ]);
  }

  /// `AA 05 90 <crc> BB` — initiate BLE connection.
  static Uint8List handshake() => _build(
        start:  BMSProtocol.startByte,
        dataId: BMSProtocol.idHandshake,
        stop:   BMSProtocol.stopByte,
      );

  /// `AA 05 91 <crc> BB` — close BLE connection.
  static Uint8List disconnect() => _build(
        start:  BMSProtocol.startByte,
        dataId: BMSProtocol.idDisconnect,
        stop:   BMSProtocol.stopByte,
      );

  /// Build any Mobile → BMS packet with a custom [dataId].
  static Uint8List custom(int dataId) => _build(
        start:  BMSProtocol.startByte,
        dataId: dataId,
        stop:   BMSProtocol.stopByte,
      );
}