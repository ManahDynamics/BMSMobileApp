// lib/services/bms/bms_packet_formatter.dart

import 'protocol.dart';
import 'parsed_packet.dart';
import 'packet_parser.dart';

class BMSPacketFormatter {
  BMSPacketFormatter._();

  // ── Raw byte helpers ───────────────────────────────────────────────────────

  static String toHexDump(List<int> bytes) => bytes
      .map((b) => (b & 0xFF).toRadixString(16).toUpperCase().padLeft(2, '0'))
      .join(' ');

  static String byteToHex(int byte) =>
      '0x${(byte & 0xFF).toRadixString(16).toUpperCase().padLeft(2, '0')}';

  static String byteToDec(int byte) => '${byte & 0xFF}';

  static String byteToBin(int byte) =>
      (byte & 0xFF).toRadixString(2).padLeft(8, '0');

  // ── Parsed packet helpers ──────────────────────────────────────────────────

  static String toOneLine(BMSParsedPacket p) =>
      '[${BMSProtocol.dataIdName(p.dataId)}]  '
      '${toHexDump(p.rawBytes)}  '
      '(${p.directionLabel})  '
      '${timeString(p.receivedAt)}';

  static Map<String, String> toFieldMap(BMSParsedPacket p) {
    final map = <String, String>{
      'Type':      BMSProtocol.dataIdName(p.dataId),
      'Raw (hex)': toHexDump(p.rawBytes),
      'Start':     byteToHex(p.startByte),
      'Length':    '${p.length} bytes',
      'Data ID':   byteToHex(p.dataId),
      'CRC-8':     byteToHex(p.crc),
      'Stop':      byteToHex(p.stopByte),
      'Time':      timeString(p.receivedAt),
    };
    if (p.isDashboardResponse) {
      if (p.batteryType != null) map['Battery Type'] = p.batteryType!;
      if (p.batterySerial != null) map['Battery Serial'] = p.batterySerial!;
      if (p.softwareVersion != null) map['SW Version'] = p.softwareVersion!;
      if (p.hardwareVersion != null) map['HW Version'] = p.hardwareVersion!;
      if (p.firmwareVersion != null) map['FW Version'] = p.firmwareVersion!;
    }
    return map;
  }

  static String toFullDetail(BMSParsedPacket p) {
    final lines = [
      'Type      : ${BMSProtocol.dataIdName(p.dataId)}',
      'Direction : ${p.directionLabel}',
      'Raw (hex) : ${toHexDump(p.rawBytes)}',
      '─────────────────────────',
      'Byte 0 – Start  : ${byteToHex(p.startByte)}',
      'Byte 1 – Length : ${p.length} bytes',
      'Byte 2 – Data ID: ${byteToHex(p.dataId)}',
      'Byte 3 – CRC-8  : ${byteToHex(p.crc)}',
      'Byte 4 – Stop   : ${byteToHex(p.stopByte)}',
    ];

    if (p.isDashboardResponse) {
      lines.addAll([
        '─────────────────────────',
        'Battery Type    : ${p.batteryType ?? "–"}',
        'Battery Serial  : ${p.batterySerial ?? "–"}',
        'SW Version      : ${p.softwareVersion ?? "–"}',
        'HW Version      : ${p.hardwareVersion ?? "–"}',
        'FW Version      : ${p.firmwareVersion ?? "–"}',
        'SOC             : ${p.soc ?? "–"}%',
        'Status          : ${p.batteryStatusLabel}',
        'Capacity        : ${p.capacityDisplay}',
        'Cycles          : ${p.chargeCyclesDisplay}',
        'Health          : ${p.healthLabel}',
        'Voltage         : ${p.voltageDisplay}',
        'Current         : ${p.currentDisplay}',
        'Temperature     : ${p.temperatureDisplay}',
        'Power           : ${p.powerDisplay}',
        'Total Cells     : ${p.totalCellsDisplay}',
        'Avg Cell Volt   : ${p.avgCellVoltageDisplay}',
        'Volt Difference : ${p.voltageDiffDisplay}',
        'Max Cell Volt   : ${p.maxCellVoltageDisplay}',
        'Min Cell Volt   : ${p.minCellVoltageDisplay}',
      ]);
    }

    lines.addAll([
      '─────────────────────────',
      'Received at : ${timeString(p.receivedAt)}',
    ]);

    return lines.join('\n');
  }

  // ── Error message ──────────────────────────────────────────────────────────
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
  static String timeString(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  static String _timeString(DateTime dt) => timeString(dt);
}