// lib/services/bms/bms_packet_formatter.dart

import 'protocol.dart';
import 'parsed_packet.dart';
import 'packet_parser.dart';

class BMSPacketFormatter {
  BMSPacketFormatter._();

  // ── Raw byte helpers ───────────────────────────────────────────────────────

  /// `[0xAA, 0x05, 0x90, 0x37, 0xBB]` → `"AA 05 90 37 BB"`
  static String toHexDump(List<int> bytes) => bytes
      .map((b) => (b & 0xFF).toRadixString(16).toUpperCase().padLeft(2, '0'))
      .join(' ');

  /// Single byte → `"0xAA"`
  static String byteToHex(int byte) =>
      '0x${(byte & 0xFF).toRadixString(16).toUpperCase().padLeft(2, '0')}';

  /// Single byte → decimal string, e.g. `"170"`
  static String byteToDec(int byte) => '${byte & 0xFF}';

  /// Single byte → binary string, e.g. `"10101010"`
  static String byteToBin(int byte) =>
      (byte & 0xFF).toRadixString(2).padLeft(8, '0');

  // ── Parsed packet helpers ──────────────────────────────────────────────────

  /// One-line summary:
  /// `"[ACK]  CC 05 50 xx DD  (BMS → Mobile)  12:34:56"`
  static String toOneLine(BMSParsedPacket p) =>
      '[${BMSProtocol.dataIdName(p.dataId)}]  '
      '${toHexDump(p.rawBytes)}  '
      '(${p.direction})  '          // ← was p.direction
      '${_timeString(p.receivedAt)}';

  static Map<String, String> toFieldMap(BMSParsedPacket p) => {
        'Type':      BMSProtocol.dataIdName(p.dataId),
        'Raw (hex)': toHexDump(p.rawBytes),
        'Start':     byteToHex(p.startByte),
        'Length':    '${p.length} bytes',
        'Data ID':   byteToHex(p.dataId),
        'CRC-8':     byteToHex(p.crc),
        'Stop':      byteToHex(p.stopByte),
        'Time':      _timeString(p.receivedAt),
      };

  /// Full multi-line text block — useful for debug logs or dialogs.
  static String toFullDetail(BMSParsedPacket p) => [
        'Type      : ${BMSProtocol.dataIdName(p.dataId)}',
        'Direction : ${p.direction}',  // ← was p.direction
        'Raw (hex) : ${toHexDump(p.rawBytes)}',
        '─────────────────────────',
        'Byte 0 – Start  : ${byteToHex(p.startByte)}',
        'Byte 1 – Length : ${p.length} bytes',
        'Byte 2 – Data ID: ${byteToHex(p.dataId)}',
        'Byte 3 – CRC-8  : ${byteToHex(p.crc)}',
        'Byte 4 – Stop   : ${byteToHex(p.stopByte)}',
        '─────────────────────────',
        'Received at : ${_timeString(p.receivedAt)}',
      ].join('\n');

  // ── Error message ──────────────────────────────────────────────────────────

  /// User-friendly message for a [BMSParseError].
  static String errorMessage(BMSParseError error) {
    switch (error) {
      case BMSParseError.tooShort:
        return 'Packet too short — need at least 5 bytes.';
      case BMSParseError.invalidFraming:
        return 'Invalid start/stop bytes — not a BMS packet.';
      case BMSParseError.invalidLength:
        return 'Length field mismatch.';
      case BMSParseError.crcMismatch:
        return 'CRC-8 mismatch — packet may be corrupted.';
        default:
         return 'Unknown Error';
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────
  static String _timeString(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}