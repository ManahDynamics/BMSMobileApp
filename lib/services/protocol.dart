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
  static const int idBleNameRequest     = 0x93;
  static const int idDashboardRequest   = 0x94;
  static const int idCellVoltageRequest = 0x95;
  // NOTE: idAlertsRequest below is INFERRED from the request/response ID
  // offset pattern used everywhere else in this file (request = response +
  // 0x40 — see idDeviceDetailsRequest/Response, idBatterySettingsRequest/
  // Response, etc.). 0x96 was previously an unused gap between
  // idCellVoltageRequest (0x94) and idDeviceDetailsRequest (0x97), which is
  // consistent with this being the missing Alerts request slot. CONFIRM
  // against the firmware/BMS protocol spec before relying on this in the
  // field — a wrong request ID here means the BMS silently never responds.
  static const int idAlertsRequest      = 0x96;



  // ── Data IDs (BMS → Mobile responses) ────────────────────────────────────
  static const int idAck                 = 0x50;
  static const int idBleNameResponse     = 0x53;
  static const int idDashboardResponse   = 0x54; // 120-byte response
  static const int idCellVoltageResponse = 0x55; // 88-byte response
  static const int idAlertsResponse      = 0x56; // 37-byte response

  // ── Packet Structure (5-byte control packets) ─────────────────────────────
  static const int packetLength = 0x05;
  static const int indexStart   = 0;
  static const int indexLength  = 1;
  static const int indexDataId  = 2;
  static const int indexCrc     = 3;
  static const int indexStop    = 4;

  // ── BLE Name Response Packet (21 bytes) ───────────────────────────────────
  static const int bleNameResponseLength = 21;
  static const int bleNameStart          = 3;
  static const int bleNameEnd            = 19; // exclusive (16 ASCII bytes)
  static const int bleNameCrcByte        = 19; // single CRC-8 byte

  // ── Alerts Details Response Packet (37 bytes, dataId 0x56) ────────────────
  // Layout (see packet_parser.dart _parseAlertsResponse for full field-by-
  // field breakdown — most fields are read via raw offsets there since they
  // are single-use; only the frame-level constants needed for dispatch/CRC/
  // framing are declared here, matching the pattern used for other packets):
  //   0      Start byte (0xAA)
  //   1      Length
  //   2      Data ID (0x56)
  //   3-33   Alert fields (cycle count, fault time/date, fault id, voltages,
  //          temps, positions — see packet_parser.dart)
  //   34-35  CRC-16 (little-endian)
  //   36     Stop byte (0xBB)
  static const int alertsResponseLength = 37;
  static const int alertsCrcLow         = 34;
  static const int alertsCrcHigh        = 35;
  static const int alertsStopByte       = 36;

  //________________________________________________
  //live status
  //________________________________________________
  // ── Live Status Heartbeat (Mobile → BMS every 15s) ────────────────────────
static const int idLiveStatusRequest = 0x92;
static const int idLiveStatusAck     = 0x52; // BMS → Mobile, 5-byte control packet

static const int liveStatusPacketLength = 0x0C; // Length byte value (12)
static const int liveStatusTotalBytes   = 12;    // Full frame size

static const int liveStatusHrByte    = 3;
static const int liveStatusMinByte   = 4;
static const int liveStatusSecByte   = 5;
static const int liveStatusDayByte   = 6;
static const int liveStatusMonthByte = 7;
static const int liveStatusYearLow   = 8;
static const int liveStatusYearHigh  = 9;
static const int liveStatusCrcByte   = 10;
static const int liveStatusStopByte  = 11;

  // ═══════════════════════════════════════════════════════════════════════
  // SETTINGS PAGE PROTOCOL
  // ═══════════════════════════════════════════════════════════════════════

  // ================= SETTINGS PACKET LENGTHS =================
  // NOTE: there is no confirmed Battery Settings *request/response* pair in
  // the spec (only a Set Now / write packet, 0xB0) — battery settings
  // length below is used for BOTH the (unconfirmed) 0x58 read-back and the
  // 0xB0 write, since they share the same 18-byte layout.
  static const int batterySettingsResponseLength = 18;

  // FIXED: was 18 — the spec (Protection Settings screenshot) shows a
  // 17-byte total packet: Start,Length,DataID,6×2-byte fields,CRC,Stop
  // = 3 + 12 + 1 + 1 = 17.
  static const int protectionSettingsResponseLength = 17;

  // FIXED: was 17 — the spec (Temperature Settings screenshot) shows an
  // 11-byte total packet with single-BYTE fields (not 2-byte):
  // Start,Length,DataID,5×1-byte fields,CRC,Stop = 3 + 5 + 1 + 1 = 11.
  static const int temperatureSettingsResponseLength = 11;

  static const int factorySettingsResponseLength = 54;

  // ================= BATTERY SETTINGS (0x58 read-back / 0xB0 write) ========
  static const int battStringByte         = 3;
  static const int battRatedCapacityHi    = 4;
  static const int battSocSetByte         = 6;
  static const int battSleepWaitingHi     = 7;
  static const int battBalancedDiffHi     = 9;
  static const int battBalancedStartHi    = 11;
  static const int battNominalCellHi      = 13;
  static const int battCellChemistryByte  = 15;
  static const int batterySettingsCrcByte  = 16;
  static const int batterySettingsStopByte = 17;

  // ================= PROTECTION SETTINGS (0x59 read-back / 0xB2 write) =====
  static const int protSingleCellHighHi = 3;
  static const int protSingleCellLowHi  = 5;
  static const int protSumVoltHighHi    = 7;
  static const int protSumVoltLowHi     = 9;
  static const int protChargeOcHi       = 11;
  static const int protDischargeOcHi    = 13;
  // FIXED: was 16 — moves in lockstep with the corrected 17-byte length.
  static const int protectionSettingsCrcByte  = 15;
  // FIXED: was 17
  static const int protectionSettingsStopByte = 16;

  // ================= TEMPERATURE SETTINGS (0x5A read-back / 0xB3 write) ====
  // FIXED: all single-byte fields (was incorrectly treated as 2-byte
  // little-endian values at the wrong offsets before).
  static const int tempNoOfChannelsByte  = 3;
  static const int tempChargeHighByte    = 4; // uint8, 0..200 °C
  static const int tempChargeLowByte     = 5; // int8,  0..-60 °C
  static const int tempDischargeHighByte = 6; // uint8, 0..200 °C
  static const int tempDischargeLowByte  = 7; // int8,  0..-60 °C
  static const int tempDiffByte          = 8; // uint8, 0..200 °C
  // FIXED: was 15
  static const int temperatureSettingsCrcByte  = 9;
  // FIXED: was 16
  static const int temperatureSettingsStopByte = 10;

  // ================= FACTORY SETTINGS (0x5B read-back / 0xB4 write) ========
  static const int facBatterySlStart = 3,  facBatterySlEnd = 19;
  static const int facBmsSerialStart = 19, facBmsSerialEnd = 35;
  static const int facBleNameStart   = 35, facBleNameEnd   = 51;
  // CHANGED: CRC-16 (2 bytes, little-endian) instead of a single CRC-8 byte.
  // Data field boundaries above (3-51) are unchanged; only the CRC width
  // and everything after it shifted by 1 byte.
  static const int factorySettingsCrcLow   = 51;
  static const int factorySettingsCrcHigh  = 52;
  static const int factorySettingsStopByte = 53;

  // ================= SETTINGS DATA IDs =================
  // Battery Settings
  static const int idBatterySettingsRequest  = 0x98;
  static const int idBatterySettingsResponse = 0x58;
  static const int idBatterySettingsWrite    = 0xB0; // "Set Now"

  // Protection Settings
  static const int idProtectionSettingsRequest  = 0x99;
  static const int idProtectionSettingsResponse = 0x59;
  static const int idProtectionSettingsWrite    = 0xB2; // "Set Now"

  // Temperature Settings
  static const int idTemperatureSettingsRequest  = 0x9A;
  static const int idTemperatureSettingsResponse = 0x5A;
  static const int idTemperatureSettingsWrite    = 0xB3; // "Set Now"

  // Factory Settings
  static const int idFactorySettingsRequest  = 0x9B;
  static const int idFactorySettingsResponse = 0x5B;
  static const int idFactorySettingsWrite    = 0xB4; // "Set Now"

  // Actions (5-byte control packets, Mobile → BMS, ACK'd with 0x50)
  static const int idCalibration     = 0xB1; // Calibrate Now
  static const int idCalibrationAck  = 0xC1;
  static const int idFirmwareUpgrade = 0xB5;
  static const int idRestart         = 0xB6;
  static const int idFactoryReset    = 0xB7;

  // Device Details
  static const int idDeviceDetailsRequest  = 0x97;
  static const int idDeviceDetailsResponse = 0x57;

  static const int deviceDetailsResponseLength = 70;

  static const int deviceSerialStart = 3;
  static const int deviceSerialEnd   = 19;

  static const int softwareVersionStart = 19;
  static const int softwareVersionEnd   = 35;

  static const int hardwareVersionStart = 35;
  static const int hardwareVersionEnd   = 51;

  static const int firmwareVersionStart = 51;
  static const int firmwareVersionEnd   = 67;

  static const int deviceDetailsCrcLow  = 67;
  static const int deviceDetailsCrcHigh = 68;
  static const int deviceDetailsStop    = 69;

  // ── Cell chemistry enum values (Battery Settings, Byte 15) ────────────────
  static const int chemistryLiIon      = 0x01;
  static const int chemistryLiHv       = 0x02;
  static const int chemistryLipO       = 0x03;
  static const int chemistrySolidState = 0x04;
  static const int chemistryLFP        = 0x05;
  static const int chemistryNMC        = 0x06;

  static String chemistryName(int code) {
    switch (code) {
      case chemistryLiIon:      return 'Li-Ion';
      case chemistryLiHv:       return 'LiHv';
      case chemistryLipO:       return 'LipO';
      case chemistrySolidState: return 'Solid State';
      case chemistryLFP:        return 'LFP';
      case chemistryNMC:        return 'NMC';
      default:                  return 'Unknown';
    }
  }

  static int chemistryCode(String name) {
    switch (name) {
      case 'Li-Ion':      return chemistryLiIon;
      case 'LiHv':        return chemistryLiHv;
      case 'LipO':        return chemistryLipO;
      case 'Solid State': return chemistrySolidState;
      case 'LFP':         return chemistryLFP;
      case 'NMC':         return chemistryNMC;
      default:            return chemistryLiIon;
    }
  }

  // ── Dashboard Response Packet v2 (115 bytes) ──────────────────────────────
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
      case idLiveStatusRequest: return 'Live Status Packet';
      case idLiveStatusAck:     return 'Live Status Ack';
      case idBleNameRequest:       return 'BLE Name Request';
      case idDashboardRequest:     return 'Dashboard Request';
      case idCellVoltageRequest:   return 'Cell Voltage Request';
      case idBleNameResponse:      return 'BLE Name Response';
      case idDashboardResponse:    return 'Dashboard Response (full)';
      case idCellVoltageResponse:  return 'Cell Voltage Response';
      case idAlertsRequest:         return 'Alerts Request';
      case idAlertsResponse:        return 'Alerts Response';
      case idDeviceDetailsRequest:  return 'Device Details Request';
      case idDeviceDetailsResponse: return 'Device Details Response';
      case idBatterySettingsRequest:  return 'Battery Settings Request';
      case idBatterySettingsResponse: return 'Battery Settings Response';
      case idBatterySettingsWrite:    return 'Battery Settings Set Now';
      case idProtectionSettingsRequest:  return 'Protection Settings Request';
      case idProtectionSettingsResponse: return 'Protection Settings Response';
      case idProtectionSettingsWrite:    return 'Protection Settings Set Now';
      case idTemperatureSettingsRequest:  return 'Temperature Settings Request';
      case idTemperatureSettingsResponse: return 'Temperature Settings Response';
      case idTemperatureSettingsWrite:    return 'Temperature Settings Set Now';
      case idFactorySettingsRequest:  return 'Factory Settings Request';
      case idFactorySettingsResponse: return 'Factory Settings Response';
      case idFactorySettingsWrite:    return 'Factory Settings Set Now';
      case idCalibration:     return 'Calibration';
      case idCalibrationAck:  return 'Calibration Ack';
      case idFirmwareUpgrade: return 'Firmware Upgrade';
      case idRestart:         return 'Restart';
      case idFactoryReset:    return 'Factory Reset';
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