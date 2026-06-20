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

  // ── Dashboard Response Packet (120 bytes) ─────────────────────────────────
  // Byte 0        : Start byte (0xAA)
  // Byte 1        : Length (0x78)
  // Byte 2        : Data ID (0x52)
  // Bytes 3–19    : Battery Type (17 ASCII bytes)
  // Byte 20       : SOC (0–100%)
  // Byte 21       : Battery Status (0x01=Charging, 0x02=Idle, 0x03=Load Connected)
  // Bytes 22–23   : Remaining Capacity (×0.1 Ah, big-endian)
  // Bytes 24–25   : No of Charge/Discharge Cycles (big-endian)
  // Byte 26       : Health (0x01=Good, 0x02=Poor)
  // Bytes 27–28   : Total Voltage (×0.1 V, big-endian)
  // Bytes 29–30   : Total Current (signed ×0.1 A, big-endian)
  // Bytes 31–32   : Temperature (signed °C, big-endian)
  // Bytes 33–34   : Power in KW (signed ×0.1 KW, big-endian)
  // Byte 35       : Total Cells (min 6, max 24)
  // Bytes 36–37   : Avg Cell Voltage (×0.001 V, big-endian)
  // Bytes 38–39   : Voltage Difference (×0.001 V, big-endian)
  // Bytes 40–41   : Max Cell Voltage (×0.001 V, big-endian)
  // Bytes 42–43   : Min Cell Voltage (×0.001 V, big-endian)
  // Bytes 44–59   : Battery Serial No (16 ASCII bytes)
  // Bytes 60–78   : Software Version (19 ASCII bytes)
  // Bytes 79–97   : Hardware Version (19 ASCII bytes)
  // Bytes 98–116  : Firmware Version (19 ASCII bytes)
  // Byte 117      : CRC-8 (single byte, computed over bytes[1..116])
  // Byte 118      : Unknown/reserved — NOT part of CRC (purpose unconfirmed)
  // Byte 119      : Stop byte (0xBB)
  //
  // ⚠️ CONFIRMED FROM LIVE CAPTURE: CRC is a single CRC-8 byte at index 117,
  // NOT a 2-byte CRC-16 as previously assumed. Byte 118 is unrelated to CRC.
  static const int dashboardResponseLength  = 120;

  static const int dashBatteryTypeStart     = 3;
  static const int dashBatteryTypeEnd       = 20; // exclusive (17 bytes)
  static const int dashSocByte              = 20;
  static const int dashBatteryStatusByte    = 21;
  static const int dashCapacityHigh         = 22;
  static const int dashCapacityLow          = 23;
  static const int dashCyclesHigh           = 24;
  static const int dashCyclesLow            = 25;
  static const int dashHealthByte           = 26;
  static const int dashVoltageHigh          = 27;
  static const int dashVoltageLow           = 28;
  static const int dashCurrentHigh          = 29;
  static const int dashCurrentLow           = 30;
  static const int dashTempHigh             = 31;
  static const int dashTempLow              = 32;
  static const int dashPowerHigh            = 33;
  static const int dashPowerLow             = 34;
  static const int dashTotalCellsByte       = 35;
  static const int dashAvgVoltageHigh       = 36;
  static const int dashAvgVoltageLow        = 37;
  static const int dashVoltDiffHigh         = 38;
  static const int dashVoltDiffLow          = 39;
  static const int dashMaxVoltageHigh       = 40;
  static const int dashMaxVoltageLow        = 41;
  static const int dashMinVoltageHigh       = 42;
  static const int dashMinVoltageLow        = 43;
  static const int dashBatterySerialStart   = 44;
  static const int dashBatterySerialEnd     = 60; // exclusive (16 bytes)
  static const int dashSoftwareVersionStart = 60;
  static const int dashSoftwareVersionEnd   = 79; // exclusive (19 bytes)
  static const int dashHardwareVersionStart = 79;
  static const int dashHardwareVersionEnd   = 98; // exclusive (19 bytes)
  static const int dashFirmwareVersionStart = 98;
  static const int dashFirmwareVersionEnd   = 117; // exclusive (19 bytes)
  static const int dashCrcByte              = 117; // single CRC-8 byte
  static const int dashStopByte             = 119;

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
  // Bytes 85–86   : CRC (exact algorithm/position NOT YET CONFIRMED — see note)
  // Byte 87       : Stop byte (0xBB)
  //
  // ⚠️ UNRESOLVED: live-capture testing shows neither CRC-8 nor CRC-16 over
  // bytes[1..84] matches byte 85/86 cleanly yet. Left as CRC-16 for now so it
  // fails closed (rejects packets) rather than silently accepting bad data.
  // This does NOT block the dashboard navigation flow — only cell-voltage
  // detail display is affected. Needs additional live captures to solve.
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
  static const int cellCrcHigh          = 85;
  static const int cellCrcLow           = 86;
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