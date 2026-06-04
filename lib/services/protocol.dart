// lib/services/protocol.dart

class BMSProtocol {
  BMSProtocol._();

  // ── Framing Bytes ─────────────────────────────────────────────────────────
  static const int startByte = 0xCC; // Mobile → BMS
  static const int stopByte  = 0xDD;
  static const int ackStart  = 0xAA; // BMS → Mobile
  static const int ackStop   = 0xBB;

  // ── Data IDs (Mobile → BMS requests) ─────────────────────────────────────
  static const int idHandshake        = 0x90;
  static const int idDisconnect       = 0x91;
  static const int idAutoRefresh      = 0x92; // Old Packet4 request (SOC/V/A only)
  static const int idDashboardRequest = 0x93; // NEW: Dashboard full data request

  // ── Data IDs (BMS → Mobile responses) ────────────────────────────────────
  static const int idAck               = 0x50; // ACK to handshake
  static const int idPacket4           = 0x51; // Old Packet4 response (12 bytes)
  static const int idDashboardResponse = 0x52; // NEW: Dashboard full response (86 bytes)

  // ── Device Info IDs (both directions) ────────────────────────────────────
  static const int idBatterySerial   = 0x59;
  static const int idSoftwareVersion = 0x5A;
  static const int idHardwareVersion = 0x5B;
  static const int idSnCode         = 0x5C;

  // ── Packet Structure (5-byte control packets) ─────────────────────────────
  static const int packetLength = 0x05;
  static const int indexStart   = 0;
  static const int indexLength  = 1;
  static const int indexDataId  = 2;
  static const int indexCrc     = 3;
  static const int indexStop    = 4;

  // ── Dashboard Response Packet (86 bytes) byte positions ───────────────────
  // Byte 0  : Start byte (0xAA)
  // Byte 1  : Length
  // Byte 2  : Data ID (0x52)
  // Bytes 3–16   : Battery Serial No (14 ASCII bytes)
  // Bytes 17–30  : Software Version  (14 ASCII bytes)
  // Bytes 31–44  : Hardware Version  (14 ASCII bytes)
  // Bytes 45–58  : SN Code           (14 ASCII bytes)
  // Byte 59      : SOC (0–100%)
  // Byte 60      : Battery Status (0x01=Charging, 0x02=Idle, 0x03=Load Connected)
  // Bytes 61–62  : Remaining Capacity (×0.1 Ah)
  // Byte 63      : Health (0x01=Good, 0x02=Poor)
  // Bytes 64–65  : Total Voltage (×0.1 V)
  // Bytes 66–67  : Total Current (signed ×0.1 A)
  // Bytes 68–69  : Temperature (signed, °C offset by 20)
  // Bytes 70–71  : Power in KW (signed ×0.1 KW)
  // Byte 72      : Total Cells
  // Bytes 73–74  : No of Charge/Discharge Cycles
  // Bytes 75–76  : Avg Voltage (×0.001 V)
  // Bytes 77–78  : Voltage Difference (×0.001 V)
  // Bytes 79–80  : Max Voltage (×0.001 V)
  // Bytes 81–82  : Min Voltage (×0.001 V)
  // Bytes 83–84  : CRC
  // Byte 85      : Stop byte (0xBB)
  static const int dashboardResponseLength = 86;

  static const int dashBatterySerialStart  = 3;
  static const int dashBatterySerialEnd    = 17; // exclusive
  static const int dashSoftwareVersionStart= 17;
  static const int dashSoftwareVersionEnd  = 31;
  static const int dashHardwareVersionStart= 31;
  static const int dashHardwareVersionEnd  = 45;
  static const int dashSnCodeStart         = 45;
  static const int dashSnCodeEnd           = 59;
  static const int dashSocByte            = 59;
  static const int dashBatteryStatusByte  = 60;
  static const int dashCapacityHigh       = 61;
  static const int dashCapacityLow        = 62;
  static const int dashHealthByte         = 63;
  static const int dashVoltageHigh        = 64;
  static const int dashVoltageLow         = 65;
  static const int dashCurrentHigh        = 66;
  static const int dashCurrentLow         = 67;
  static const int dashTempHigh           = 68;
  static const int dashTempLow            = 69;
  static const int dashPowerHigh          = 70;
  static const int dashPowerLow           = 71;
  static const int dashTotalCellsByte     = 72;
  static const int dashCyclesHigh         = 73;
  static const int dashCyclesLow          = 74;
  static const int dashAvgVoltageHigh     = 75;
  static const int dashAvgVoltageLow      = 76;
  static const int dashVoltDiffHigh       = 77;
  static const int dashVoltDiffLow        = 78;
  static const int dashMaxVoltageHigh     = 79;
  static const int dashMaxVoltageLow      = 80;
  static const int dashMinVoltageHigh     = 81;
  static const int dashMinVoltageLow      = 82;
  static const int dashCrcHigh            = 83;
  static const int dashCrcLow            = 84;
  static const int dashStopByte           = 85;

  // ── Battery Status values ─────────────────────────────────────────────────
  static const int batteryStatusCharging       = 0x01;
  static const int batteryStatusIdle           = 0x02;
  static const int batteryStatusLoadConnected  = 0x03;

  // ── Health values ─────────────────────────────────────────────────────────
  static const int healthGood = 0x01;
  static const int healthPoor = 0x02;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String dataIdName(int id) {
    switch (id) {
      case idHandshake:         return 'Handshake';
      case idAck:               return 'ACK';
      case idDisconnect:        return 'Disconnect';
      case idAutoRefresh:       return 'Auto Refresh (legacy)';
      case idDashboardRequest:  return 'Dashboard Request';
      case idPacket4:           return 'Packet4 (SOC/V/A) legacy';
      case idDashboardResponse: return 'Dashboard Response (full)';
      case idBatterySerial:     return 'Battery Serial No';
      case idSoftwareVersion:   return 'Software Version';
      case idHardwareVersion:   return 'Hardware Version';
      case idSnCode:            return 'SN Code';
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
}