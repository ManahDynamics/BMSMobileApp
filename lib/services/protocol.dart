// lib/services/bms/bms_protocol.dart

class BMSProtocol {
  BMSProtocol._();

  // ── Framing Bytes ─────────────────────────────────────────────────────────
  static const int startByte  = 0xAA; // Mobile → BMS
  static const int stopByte   = 0xBB;
  static const int ackStart   = 0xCC; // BMS → Mobile
  static const int ackStop    = 0xDD;

  // ── Data IDs ──────────────────────────────────────────────────────────────
  static const int idHandshake  = 0x90;
  static const int idAck        = 0x50;
  static const int idDisconnect = 0x91;

  // ── Packet Structure ──────────────────────────────────────────────────────
  static const int packetLength   = 0x05;
  static const int indexStart     = 0;
  static const int indexLength    = 1;
  static const int indexDataId    = 2;
  static const int indexCrc       = 3;
  static const int indexStop      = 4;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String dataIdName(int id) {
    switch (id) {
      case idHandshake:  return 'Handshake';
      case idAck:        return 'ACK';
      case idDisconnect: return 'Disconnect';
      default:           return 'Unknown (0x${id.toRadixString(16).toUpperCase().padLeft(2, '0')})';
    }
  }
}