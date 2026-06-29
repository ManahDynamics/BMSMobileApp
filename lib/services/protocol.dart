// lib/services/protocol.dart

class BMSProtocol {
  BMSProtocol._();

  // ── Framing Bytes ─────────────────────────────────────────────────────────
  static const int startByte = 0xCC; // Mobile → BMS
  static const int stopByte  = 0xDD;
  static const int ackStart  = 0xAA; // BMS → Mobile
  static const int ackStop   = 0xBB;

  // ── Data IDs (Mobile → BMS requests) ─────────────────────────────────────
  static const int idHandshake          = 0x90;
  static const int idDisconnect         = 0x91;
  static const int idBleNameRequest     = 0x92;
  static const int idDashboardRequest   = 0x93;
  static const int idCellVoltageRequest = 0x94;

  // ── Data IDs (BMS → Mobile responses) ────────────────────────────────────
  static const int idAck                 = 0x50;
  static const int idBleNameResponse     = 0x51;
  static const int idDashboardResponse   = 0x52; // 120-byte response
  static const int idCellVoltageResponse = 0x53; // 88-byte response

  // ── Device Info IDs ───────────────────────────────────────────────────────
  static const int idBatterySerial   = 0x59;
  static const int idSoftwareVersion = 0x5A;
  static const int idHardwareVersion = 0x5B;
  static const int idSnCode          = 0x5C;

  // ── Packet Structure (5-byte control packets) ─────────────────────────────
  static const int packetLength = 0x05;
  static const int indexStart   = 0;
  static const int indexLength  = 1;
  static const int indexDataId  = 2;
  static const int indexCrc     = 3;
  static const int indexStop    = 4;

  // ── BLE Name Response Packet (21 bytes) ───────────────────────────────────
  // Byte 0       : Start byte (0xAA)
  // Byte 1       : Length (0x15 = 21)
  // Byte 2       : Data ID (0x51)
  // Bytes 3–18   : BLE Name (16 ASCII bytes)
  // Byte 19      : CRC-8 (single byte, computed over bytes[1..18])
  // Byte 20      : Stop byte (0xBB)
  //
  // ⚠️ CONFIRMED FROM LIVE CAPTURE (previously documented as 19 bytes / 14
  // char name — that was wrong). Real packet is 21 bytes, name is 16 chars.
  static const int bleNameResponseLength = 21;
  static const int bleNameStart          = 3;
  static const int bleNameEnd            = 19; // exclusive (16 ASCII bytes)
  static const int bleNameCrcByte        = 19; // single CRC-8 byte

  // ── Dashboard Response Packet v2 (115 bytes) ──────────────────────────────
  // ✅ CONFIRMED FROM LIVE CAPTURE (new firmware format — replaces the old
  // 120-byte layout with software/hardware/firmware version strings).
  //
  // Byte 0        : Start byte (0xAA)
  // Byte 1        : Length (0x73 = 115)
  // Byte 2        : Data ID (0x52)
  // Bytes 3–19    : Battery Type (17 ASCII bytes)
  // Bytes 20–35   : Battery Serial No (16 ASCII bytes)
  // Byte 36       : SOC (0–100%)
  // Byte 37       : Battery Status (0x01=Charging, 0x02=Idle, 0x03=Load Connected)
  // Bytes 38–39   : Remaining Capacity (×0.1 Ah, little-endian)
  // Bytes 40–41   : No of Charge/Discharge Cycles (little-endian)
  // Byte 42       : Health (0x01=Good, 0x02=Poor)
  // Bytes 43–44   : Total Voltage (×0.1 V, little-endian)
  // Bytes 45–46   : Total Current (signed ×0.1 A, little-endian)
  // Bytes 47–48   : Temperature (signed °C, little-endian)
  // Bytes 49–50   : Power in KW (signed ×0.1 KW, little-endian)
  // Byte 51       : Total Cells (min 6, max 24)
  // Bytes 52–99   : Cell 1–24 Voltage (×0.001 V each, 2 bytes/cell, little-endian,
  //                 NO per-cell balancing byte in this format)
  // Bytes 100–101 : Avg Cell Voltage (×0.001 V, little-endian)
  // Bytes 102–103 : Voltage Difference (×0.001 V, little-endian)
  // Bytes 104–105 : Max Cell Voltage (×0.001 V, little-endian)
  // Bytes 106–107 : Min Cell Voltage (×0.001 V, little-endian)
  // Byte 108      : Warning Alerts count (max 38)
  // Byte 109      : Fault Alerts count (max 38)
  // Byte 110      : Cleared Alerts count (max 38)
  // Byte 111      : Total Alerts count (= Warning+Fault+Cleared; NOT covered by CRC)
  // Bytes 112–113 : CRC-16/CCITT (poly 0x1021, init 0xFFFF), LITTLE-ENDIAN
  //                 byte112=low, byte113=high. Computed over bytes[1..110]
  //                 (Dart: sublist(1, 111)) — i.e. everything from Length
  //                 through Cleared Alerts, explicitly EXCLUDING Total
  //                 Alerts, the CRC bytes, and the stop byte.
  // Byte 114      : Stop byte (0xBB)
  //
  // ✅ CONFIRMED FROM LIVE CAPTURE: CRC16-CCITT(poly=0x1021, init=0xFFFF)
  // over bytes[1:111] produces 0x1089 for the captured packet, matching
  // byte112=0x89 (low) / byte113=0x10 (high) exactly.
  static const int dashboardResponseLength  = 115;

  static const int dashBatteryTypeStart     = 3;
  static const int dashBatteryTypeEnd       = 20;  // exclusive (17 bytes)
  static const int dashBatterySerialStart   = 20;
  static const int dashBatterySerialEnd     = 36;  // exclusive (16 bytes)
  static const int dashSocByte              = 36;
  static const int dashBatteryStatusByte    = 37;
  static const int dashCapacityHigh         = 38;
  static const int dashCapacityLow          = 39;
  static const int dashCyclesHigh           = 40;
  static const int dashCyclesLow            = 41;
  static const int dashHealthByte           = 42;
  static const int dashVoltageHigh          = 43;
  static const int dashVoltageLow           = 44;
  static const int dashCurrentHigh          = 45;
  static const int dashCurrentLow           = 46;
  static const int dashTempHigh             = 47;
  static const int dashTempLow              = 48;
  static const int dashPowerHigh            = 49;
  static const int dashPowerLow             = 50;
  static const int dashTotalCellsByte       = 51;
  static const int dashCellDataStart        = 52;
  static const int dashCellDataStride       = 2;   // 2 bytes/cell, NO balancing byte
  static const int dashCellDataMaxCells     = 24;
  static const int dashAvgVoltageHigh       = 100;
  static const int dashAvgVoltageLow        = 101;
  static const int dashVoltDiffHigh         = 102;
  static const int dashVoltDiffLow          = 103;
  static const int dashMaxVoltageHigh       = 104;
  static const int dashMaxVoltageLow        = 105;
  static const int dashMinVoltageHigh       = 106;
  static const int dashMinVoltageLow        = 107;
  static const int dashWarningAlertsByte    = 108;
  static const int dashFaultAlertsByte      = 109;
  static const int dashClearedAlertsByte    = 110;
  static const int dashTotalAlertsByte      = 111;
  static const int dashCrcLowByte           = 112;
  static const int dashCrcHighByte          = 113;
  static const int dashStopByte             = 114;
  // ── Cell Voltage Response Packet (88 bytes) ───────────────────────────────
  // Byte 0        : Start byte (0xAA)
  // Byte 1        : Length (0x58)
  // Byte 2        : Data ID (0x53)
  // Bytes 3–4     : Max Voltage (×0.001 V, big-endian)
  // Byte 5        : Max Voltage Cell No (1–24)
  // Bytes 6–7     : Min Voltage (×0.001 V, big-endian)
  // Byte 8        : Min Voltage Cell No (1–24)
  // Bytes 9–10    : Avg Voltage (×0.001 V, big-endian)
  // Byte 11       : Overall Balancing (0x01=Active, 0x02=Inactive)
  // Byte 12       : Total Cells (min 6, max 24)
  // Bytes 13–14   : Cell 1 Voltage (×0.001 V, big-endian)
  // Byte 15       : Cell 1 Balancing
  // [Each cell = 3 bytes: volt_H, volt_L, balancing. Repeat for cells 2–24]
  // Bytes 85–86   : CRC-16/CCITT (poly 0x1021, init 0xFFFF), LITTLE-ENDIAN
  //                 byte 85 = CRC low byte, byte 86 = CRC high byte.
  //                 Computed over bytes[1..83] (Dart: sublist(1, 84)) —
  //                 i.e. everything except the start byte, up to (not
  //                 including) the CRC bytes themselves.
  // Byte 87       : Stop byte (0xBB)
  //
  // ✅ CONFIRMED FROM LIVE CAPTURE: CRC16-CCITT(poly=0x1021, init=0xFFFF)
  // over bytes[1:84] produces 0x39F0 for the captured packet, matching
  // byte85=0xF0 (low) / byte86=0x39 (high) exactly. This is a DIFFERENT
  // algorithm and byte order than Dashboard/BLE Name (which use a single
  // CRC-8 byte) — confirmed independently, not assumed to be consistent
  // across packet types.
  static const int cellVoltageResponseLength = 88;

  static const int cellMaxVoltageHigh   = 3;
  static const int cellMaxVoltageLow    = 4;
  static const int cellMaxVoltageCellNo = 5;
  static const int cellMinVoltageHigh   = 6;
  static const int cellMinVoltageLow    = 7;
  static const int cellMinVoltageCellNo = 8;
  static const int cellAvgVoltageHigh   = 9;
  static const int cellAvgVoltageLow    = 10;
  static const int cellBalancingByte    = 11;
  static const int cellTotalCellsByte   = 12;
  static const int cellDataStart        = 13;
  static const int cellDataStride       = 3;
  static const int cellCrcLow           = 85;
  static const int cellCrcHigh          = 86;
  static const int cellStopByte         = 87;  

  // ── Balancing values ──────────────────────────────────────────────────────
  static const int balancingActive   = 0x01;
  static const int balancingInactive = 0x02;

  // ── Battery Status values ─────────────────────────────────────────────────
  static const int batteryStatusCharging      = 0x01;
  static const int batteryStatusIdle          = 0x02;
  static const int batteryStatusLoadConnected = 0x03;

  // ── Health values ─────────────────────────────────────────────────────────
  static const int healthGood = 0x01;
  static const int healthPoor = 0x02;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String dataIdName(int id) {
    switch (id) {
      case idHandshake:            return 'Handshake';
      case idAck:                  return 'ACK';
      case idDisconnect:           return 'Disconnect';
      case idBleNameRequest:       return 'BLE Name Request';
      case idDashboardRequest:     return 'Dashboard Request';
      case idCellVoltageRequest:   return 'Cell Voltage Request';
      case idBleNameResponse:      return 'BLE Name Response';
      case idDashboardResponse:    return 'Dashboard Response (full)';
      case idCellVoltageResponse:  return 'Cell Voltage Response';
      case idBatterySerial:        return 'Battery Serial No';
      case idSoftwareVersion:      return 'Software Version';
      case idHardwareVersion:      return 'Hardware Version';
      case idSnCode:               return 'SN Code';
      default:
        return 'Unknown (0x${id.toRadixString(16).toUpperCase().padLeft(2, '0')})';
    }
  }

  static String batteryStatusLabel(int code) {
    switch (code) {
      case batteryStatusCharging:      return 'Charging';
      case batteryStatusIdle:          return 'Idle';
      case batteryStatusLoadConnected: return 'Load Connected';
      default:                         return 'Unknown';
    }
  }

  static String healthLabel(int code) {
    switch (code) {
      case healthGood: return 'Good';
      case healthPoor: return 'Poor';
      default:         return 'Unknown';
    }
  }

  static String balancingLabel(int code) {
    switch (code) {
      case balancingActive:   return 'Active';
      case balancingInactive: return 'Inactive';
      default:                return 'Unknown';
    }
  }
}