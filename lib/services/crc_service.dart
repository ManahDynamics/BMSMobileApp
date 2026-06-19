// lib/services/bms/bms_crc_service.dart

class BMSCrcService {
  BMSCrcService._();

  /// CRC-8 — polynomial 0x07, initial value 0x00.
  /// Exact Dart port of the embedded C implementation.
  static int calculateCRC8(List<int> data) {
    int crc = 0x00;
    for (int i = 0; i < data.length; i++) {
      crc ^= data[i] & 0xFF;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ 0x07) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
    }
    return crc;
  }

  /// CRC-16 — Modbus style (most common in BMS devices)
  /// Polynomial: 0x8005 (reflected 0xA001), Initial value: 0xFFFF
  static int calculateCRC16(List<int> data) {
    int crc = 0xFFFF;
    const int poly = 0xA001;

    for (int byte in data) {
      crc ^= byte & 0xFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ poly;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc & 0xFFFF;
  }

  /// Returns true if [crcByte] matches the CRC computed over [data].
  static bool verifyCRC8(List<int> data, int crcByte) =>
      calculateCRC8(data) == (crcByte & 0xFF);

  /// CRC-8 as hex string — e.g. "0x37"
  static String crcHex(List<int> data) {
    final int val = calculateCRC8(data);
    return '0x${val.toRadixString(16).toUpperCase().padLeft(2, '0')}';
  }

  /// CRC-16 as hex string — e.g. "0xABCD"
  static String crc16Hex(List<int> data) {
    final int val = calculateCRC16(data);
    return '0x${val.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }
}