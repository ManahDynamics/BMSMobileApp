class BMSCrcService {
  BMSCrcService._();

  /// CRC-8 — polynomial 0x07, initial value 0x00.
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

  /// CRC-16-CCITT (exact match to the C code you provided)
  /// Polynomial: 0x1021, Initial value: 0xFFFF
  static int calculateCRC16(List<int> data) {
    int crc = 0xFFFF;

    for (int i = 0; i < data.length; i++) {
      crc ^= (data[i] & 0xFF) << 8;

      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc = crc << 1;
        }
        crc &= 0xFFFF;
      }
    }
    return crc;
  }

  /// Verify CRC16 (2 bytes)
  static bool verifyCRC16(List<int> data, int crcWord) =>
      calculateCRC16(data) == (crcWord & 0xFFFF);

  /// CRC-16 as hex string — e.g. "0xABCD"
  static String crc16Hex(List<int> data) {
    final int val = calculateCRC16(data);
    return '0x${val.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }
}