// lib/services/bluetooth_service.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:bmsmobileapp/services/parsed_packet.dart';
import 'package:bmsmobileapp/services/packet_parser.dart';
import 'package:bmsmobileapp/services/crc_service.dart';
import 'package:bmsmobileapp/services/protocol.dart';

enum BMSConnectionState {
  disconnected, connecting, connected, discovering,
  handshakeSent, waitingAck, ready, disconnecting, error,
}

class BMSBluetoothService extends ChangeNotifier with WidgetsBindingObserver {
  BluetoothDevice? device;
  BMSConnectionState state = BMSConnectionState.disconnected;
  String? errorMessage;
  bool isConnecting = false;

  /// True once the first Dashboard packet has parsed successfully
  /// (CRC passed). Kept for backward-compat / informational use.
  bool dashboardReady = false;

  bool dashboardNavigationTriggered = false;

  // ── Sequential request flow ─────────────────────────────────────────────
  bool readyForDashboard = false;

  bool isBleNameLoading = false;
  bool isDashboardLoading = false;
  bool isCellVoltageLoading = false;

  String? bleNameError;
  String? dashboardError;
  String? cellVoltageError;

  Completer<bool>? _bleNameCompleter;
  Completer<bool>? _dashboardCompleter;
  Completer<bool>? _cellVoltageCompleter;

  final List<BMSParsedPacket> packetLog = [];

  final List<String> _debugLogs = [];
  List<String> get debugLogs => List.unmodifiable(_debugLogs);
  static const int _maxDebugLogs = 300;

  // ── Latest valid packets ──────────────────────────────────────────────────
  BMSParsedPacket? latestDashboard;
  BMSParsedPacket? latestCellVoltage;
  BMSParsedPacket? latestBatterySettings;
  BMSParsedPacket? latestProtectionSettings;
BMSParsedPacket? latestTemperatureSettings;
  BMSParsedPacket? latestFactorySettings;

  // FIXED: this was parsed correctly by packet_parser.dart but had nowhere
  // to land in the service — no field, no branch in the notify listener.
  BMSParsedPacket? latestDeviceDetails;

  int batterySettingsPulse = 0;
  int protectionSettingsPulse = 0;
  int temperatureSettingsPulse = 0;
  int factorySettingsPulse = 0;
  int deviceDetailsPulse = 0;

  int dashboardPulse = 0;
  int cellVoltagePulse = 0;

  // ── Settings-page "Set Now" / action state ────────────────────────────────
  bool isActionInFlight = false;
  Completer<bool>? _actionAckCompleter;

  // ── Device info ───────────────────────────────────────────────────────────
  String? bleName;
  String? batterySerial;
  String? batteryType;
  String? softwareVersion;
  String? hardwareVersion;
  String? firmwareVersion;
  String? snCode;

  // ── Tracks the Data ID of the most recently sent request ──────────────────
  final Set<int> _pendingRequests = {};
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription? _notifySub;
  StreamSubscription? _connectionStateSub;
  Timer? _ackTimer;

  Timer? _pollTimer;
  Timer? _dashboardPollTimer;
  Timer? _cellVoltagePollTimer;
  Timer? _liveStatusTimer;
  Timer? _liveStatusAckTimer;

  /// Number of consecutive Live Status Acks missed in a row. Reset to 0
  /// whenever an Ack is received. The fatal "BMS Disconnected" popup only
  /// fires once this reaches [_maxLiveStatusMisses] — a single missed Ack
  /// no longer disconnects immediately.
  int _liveStatusMissCount = 0;
  static const int _maxLiveStatusMisses = 3;

  /// Called when the Live Status Ack isn't received within the timeout
  /// window — BMS is considered disconnected. UI (wired in main.dart) shows
  /// a blocking "BMS Disconnected" dialog and closes the app on OK, using
  /// the global navigatorKey so it works regardless of which page the user
  /// is currently on.
  void Function()? onBmsDisconnectedFatal;

  int _sessionId = 0;

  BMSBluetoothService() {
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> requestCellVoltageData() async {
    await requestCellVoltages();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    switch (appState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        debugPrint('📴 App backgrounded — pausing polling');
        _stopPolling();
        break;
      case AppLifecycleState.resumed:
        debugPrint('📲 App foregrounded — resuming polling');
        _startPolling();
        break;
      default:
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONNECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> connect(BluetoothDevice d) async {
    _newSession();
    debugPrint('══════════════════════════════');
    debugPrint('🚀 SESSION $_sessionId — connect to ${d.remoteId.str}');
    addDebugLog('🚀 SESSION $_sessionId — connect to ${d.remoteId.str}');

    try {
      isConnecting = true;
      state = BMSConnectionState.connecting;
      notifyListeners();

      await d.connect(timeout: const Duration(seconds: 15));
      device = d;
      debugPrint('✅ BLE CONNECTED');
      addDebugLog('✅ BLE CONNECTED');

      _connectionStateSub = d.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected &&
            state != BMSConnectionState.disconnecting &&
            state != BMSConnectionState.disconnected) {
          debugPrint('⚠️  Device disconnected unexpectedly (BMS powered off / out of range)');
          addDebugLog('⚠️ Device disconnected unexpectedly (BLE link lost)');
          errorMessage = 'Device disconnected unexpectedly';
          state = BMSConnectionState.error;
          isConnecting = false;

          // Tear down timers/polling and BLE resources. Don't call
          // disconnect() here — the BLE link is already gone (that's why
          // this fired), so writing a disconnect packet to _writeChar
          // would fail. Mirror disconnect()'s cleanup steps instead.
          _stopPolling();
          _stopDashboardPolling();
          _stopCellVoltagePolling();
          stopSettingsPolling();
          stopLiveStatusMonitor();
          _cleanup();
          notifyListeners();

          // Fire the same fatal callback used by the Live Status Ack
          // timeout, so "BMS powered off / went out of range" shows the
          // identical blocking "BMS Disconnected" dialog.
          debugPrint("🔥 Calling disconnect callback (BLE link lost)");
          debugPrint("Callback = $onBmsDisconnectedFatal");
          onBmsDisconnectedFatal?.call();
        }
      });

      state = BMSConnectionState.connected;
      notifyListeners();

      try {
        await d.requestMtu(512);
        debugPrint('📶 MTU negotiated');
        addDebugLog('📶 MTU negotiated');
      } catch (e) {
        debugPrint('⚠️  MTU request failed (non-fatal): $e');
        addDebugLog('⚠️ MTU request failed (non-fatal): $e');
      }

      await _discoverServices();
      await sendHandshake();
    } catch (e, st) {
      debugPrint('❌ CONNECT ERROR: $e\n$st');
      addDebugLog('❌ CONNECT ERROR: $e');
      final msg = e.toString();
      if (msg.contains('android-code: 14') || msg.contains('GATT_UNLIKELY')) {
        errorMessage =
            'Write failed (GATT_UNLIKELY). The device rejected the write.\n'
            'Try reconnecting — the BLE module may need a moment to settle.';
      } else {
        errorMessage = msg;
      }
      state = BMSConnectionState.error;
      isConnecting = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISCOVER SERVICES
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _discoverServices() async {
    debugPrint('🔍 DISCOVERING SERVICES…');
    addDebugLog('🔍 Discovering services…');
    state = BMSConnectionState.discovering;
    notifyListeners();

    final services = await device!.discoverServices();

    _notifyChar = null;
    _writeChar  = null;

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.notify && _notifyChar == null) _notifyChar = c;
        if (_writeChar == null) {
          if (c.properties.writeWithoutResponse) { _writeChar = c; }
          else if (c.properties.write)           { _writeChar = c; }
        }
      }
    }

    if (_notifyChar == null || _writeChar == null) {
      addDebugLog('❌ Required BLE characteristics not found '
          '(notify=${_notifyChar != null}, write=${_writeChar != null})');
      throw Exception('Required BLE characteristics not found.');
    }

    addDebugLog('✅ Characteristics found (notify + write)');
    await _startListening();
    state = BMSConnectionState.connected;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // START LISTENING (RX)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    debugPrint('📡 SUBSCRIBING TO NOTIFICATIONS…');
    addDebugLog('📡 Subscribing to notifications…');
    await _notifyChar!.setNotifyValue(true);

    _notifySub = _notifyChar!.onValueReceived.listen((raw) {
      if (raw.isEmpty) return;
      debugPrint("📥 RAW RX: ${_toHex(raw)}");

final result = BMSPacketParser.parse(
  Uint8List.fromList(raw),
);

debugPrint("Parse success : ${result.isSuccess}");

if (!result.isSuccess) {
  debugPrint("❌ Parse Error : ${result.error}");
  debugPrint("❌ Detail      : ${result.errorDetail}");
} else {
  debugPrint(
    "✅ Parsed DataId : 0x${result.packet!.dataId.toRadixString(16).toUpperCase()}",
  );
}

      if (result.isSuccess && result.packet != null) {
        final packet = result.packet!.copyWith(direction: PacketDirection.receive);
        _addToLog(packet);
        addDebugLog(
          '✅ Response received: 0x${result.packet!.dataId.toRadixString(16).toUpperCase()}',
        );

        if (packet.isCellVoltageResponse) {
          addDebugLog('🔋 Cell Voltage Response received');
          latestCellVoltage = packet;
          cellVoltagePulse++;
          cellVoltageError = null;
          isCellVoltageLoading = false;
          notifyListeners();
          if (_cellVoltageCompleter != null && !_cellVoltageCompleter!.isCompleted) {
            _cellVoltageCompleter!.complete(true);
          }

        } else if (packet.isDashboardResponse) {
          addDebugLog('📊 Dashboard Response received — CRC passed');
          addDebugLog('   Battery Serial = "${packet.batterySerial}"');

          latestDashboard   = packet;
          latestCellVoltage = packet;
          dashboardPulse++;
          cellVoltagePulse++;
          dashboardError = null;
          isDashboardLoading = false;

          if (_cellVoltageCompleter != null && !_cellVoltageCompleter!.isCompleted) {
            _cellVoltageCompleter!.complete(true);
          }

          if (packet.batteryType     != null) batteryType     = packet.batteryType;
          if (packet.batterySerial   != null) batterySerial   = packet.batterySerial;
          if (packet.softwareVersion != null) softwareVersion = packet.softwareVersion;
          if (packet.hardwareVersion != null) hardwareVersion = packet.hardwareVersion;
          if (packet.firmwareVersion != null) firmwareVersion = packet.firmwareVersion;

          if (batterySerial == null || batterySerial!.trim().isEmpty) {
            addDebugLog('⚠️ batterySerial is NULL/EMPTY after extraction');
          } else {
            addDebugLog('✅ batterySerial set: "$batterySerial"');
          }

          if (!dashboardReady) {
            dashboardReady = true;
            debugPrint('🚀 Dashboard Ready');
            addDebugLog('🚀 dashboardReady = true');
          }

          notifyListeners();

          if (_dashboardCompleter != null && !_dashboardCompleter!.isCompleted) {
            _dashboardCompleter!.complete(true);
          }

        } else if (packet.isBleNameResponse) {
          if (packet.bleName != null) {
            bleName = packet.bleName;
            debugPrint('📋 BLE Name: $bleName');
            addDebugLog('📋 BLE Name: $bleName');
          }
          notifyListeners();
          if (_bleNameCompleter != null && !_bleNameCompleter!.isCompleted) {
            _bleNameCompleter!.complete(true);
          }

        } else if (packet.isDeviceDetailsResponse) {
          addDebugLog('ℹ️ Device Details Response received');
          latestDeviceDetails = packet;
          deviceDetailsPulse++;
          notifyListeners();

        } else if (packet.isBatterySettingsResponse) {
          debugPrint("🎉 ENTERED BATTERY SETTINGS RESPONSE");

  addDebugLog('🔋 Battery Settings Response received');

  latestBatterySettings = packet;
  batterySettingsPulse++;

  debugPrint(
      "Battery String : ${packet.batteryString}");
  debugPrint(
      "Rated Capacity : ${packet.ratedCapacity}");
  debugPrint(
      "SOC Set        : ${packet.socSet}");

          notifyListeners();

        } else if (packet.isProtectionSettingsResponse) {
          addDebugLog(' Protection Settings Response received');
          latestProtectionSettings = packet;
          protectionSettingsPulse++;
          notifyListeners();

        } else if (packet.isTemperatureSettingsResponse) {
          addDebugLog(' Temperature Settings Response received');
          latestTemperatureSettings = packet;
          temperatureSettingsPulse++;
          notifyListeners();

        } else if (packet.isFactorySettingsResponse) {
          addDebugLog(' Factory Settings Response received');
          latestFactorySettings = packet;
          factorySettingsPulse++;
          notifyListeners();

        } else if (packet.isLiveStatusAck) {
          addDebugLog('✅ Live Status Ack received');
          _liveStatusAckTimer?.cancel();
          _liveStatusAckTimer = null;
          if (_liveStatusMissCount > 0) {
            addDebugLog('🔁 Live Status Ack recovered — resetting miss count '
                '(was $_liveStatusMissCount)');
          }
          _liveStatusMissCount = 0;

      

        } else if (packet.isCalibrationAck) {
          addDebugLog('✅ Calibrate Now Ack (0xC1) received');
          if (_actionAckCompleter != null && !_actionAckCompleter!.isCompleted) {
            _actionAckCompleter!.complete(true);
          }

        } else if (packet.isAck) {
          if (state == BMSConnectionState.waitingAck) {
            addDebugLog('🤝 ACK packet received — validating handshake');
            _onAckReceived(packet);
          }
          if (_actionAckCompleter != null && !_actionAckCompleter!.isCompleted) {
            addDebugLog('🤝 ACK packet received — completing pending action');
            _actionAckCompleter!.complete(true);
          }
        }
        else {
  debugPrint("======================================");
  debugPrint("❌ Packet Parse Failed");
  debugPrint("Raw Packet : ${_toHex(raw)}");
  debugPrint("Error      : ${result.error}");
  debugPrint("Detail     : ${result.errorDetail}");
  debugPrint("======================================");
}
    }});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEND PACKET
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendPacket(
    List<int> packetBytes, {
    String? logName,
    int?    sentDataId,
  }) async {
    if (_writeChar == null) return;

    if (sentDataId != null) {
      _pendingRequests.add(sentDataId);
      addDebugLog(
        '📤 Pending Requests: ${_pendingRequests.map((e) => "0x${e.toRadixString(16).toUpperCase()}").join(", ")}',
      );
    }

    final bool useWithoutResponse = _writeChar!.properties.writeWithoutResponse;
    debugPrint('📤 TX${logName != null ? " ($logName)" : ""} : ${_toHex(packetBytes)}');
    addDebugLog('📤 TX${logName != null ? " ($logName)" : ""}: ${_toHex(packetBytes)}');

    final result = BMSPacketParser.parse(Uint8List.fromList(packetBytes));
    if (result.isSuccess && result.packet != null) {
      _addToLog(result.packet!.copyWith(direction: PacketDirection.send));
    }

    await _writeChar!.write(packetBytes, withoutResponse: useWithoutResponse);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HANDSHAKE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendHandshake() async {
    final int crc = BMSCrcService.calculateCRC8([0x05, BMSProtocol.idHandshake]);
    final List<int> packet = [
      BMSProtocol.startByte, 0x05, BMSProtocol.idHandshake, crc, BMSProtocol.stopByte,
    ];

    state = BMSConnectionState.handshakeSent;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    await _sendPacket(packet, logName: 'HANDSHAKE', sentDataId: BMSProtocol.idHandshake);

    state = BMSConnectionState.waitingAck;
    isConnecting = true;
    addDebugLog('🤝 Handshake sent — waiting for validated ACK');
    notifyListeners();

    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(seconds: 10), () {
      if (state == BMSConnectionState.waitingAck) {
        addDebugLog('❌ Handshake ACK timeout — no response from BMS');
        errorMessage = 'No response from BMS (handshake ACK timeout)';
        state = BMSConnectionState.error;
        isConnecting = false;
        notifyListeners();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE STATUS PACKET (Mobile → BMS, every 15s)
  // Confirms Mobile App is alive to the BMS. If the corresponding Ack
  // (0x52) is not received within 20s of sending, the connection is
  // considered stale, the app disconnects automatically, and shows a
  // blocking "BMS Disconnected" dialog (wired in main.dart via
  // onBmsDisconnectedFatal) regardless of which page the user is on.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendLiveStatusPacket() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;

    final now = DateTime.now();
    final List<int> body = [
      BMSProtocol.liveStatusPacketLength,   // Length byte (0x0C)
      BMSProtocol.idLiveStatusRequest,      // 0x92
      now.hour & 0xFF,
      now.minute & 0xFF,
      now.second & 0xFF,
      now.day & 0xFF,
      now.month & 0xFF,
      now.year & 0xFF,          // year low byte
      (now.year >> 8) & 0xFF,   // year high byte
    ];

    final int crc = BMSCrcService.calculateCRC8(body);
    final List<int> packet = [
      BMSProtocol.startByte,
      ...body,
      crc,
      BMSProtocol.stopByte,
    ];

    await _sendPacket(packet, logName: 'LIVE_STATUS', sentDataId: BMSProtocol.idLiveStatusRequest);

    // Only start a new timeout if one isn't already pending — a routine
    // periodic send should never reset the clock on an ack we're still
    // waiting for.
    if (_liveStatusAckTimer == null || !_liveStatusAckTimer!.isActive) {
      _liveStatusAckTimer = Timer(const Duration(seconds: 20), _onLiveStatusAckTimeout);
    }
  }

  void _onLiveStatusAckTimeout() {
    _liveStatusMissCount++;
    _liveStatusAckTimer = null;

    if (_liveStatusMissCount < _maxLiveStatusMisses) {
      addDebugLog(
        '⚠️ Live Status Ack not received within 20s '
        '(miss $_liveStatusMissCount/$_maxLiveStatusMisses) — will retry',
      );
      // Don't disconnect yet. The periodic 15s sender is still running and
      // will send the next Live Status packet, which starts a fresh 20s
      // timeout above (since _liveStatusAckTimer is now null).
      return;
    }

    addDebugLog(
      '⛔ Live Status Ack missed $_liveStatusMissCount times in a row — disconnecting',
    );
    debugPrint("🔥 Calling disconnect callback");
    debugPrint("Callback = $onBmsDisconnectedFatal");
    onBmsDisconnectedFatal?.call();
    disconnect();
  }

  void startLiveStatusMonitor() {
    stopLiveStatusMonitor();
    addDebugLog(
      '▶️ Live Status monitor started (interval 15s, ack timeout 20s, '
      'disconnect after $_maxLiveStatusMisses misses)',
    );
    sendLiveStatusPacket();
    _liveStatusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      sendLiveStatusPacket();
    });
  }

  void stopLiveStatusMonitor() {
    _liveStatusTimer?.cancel();
    _liveStatusTimer = null;
    _liveStatusAckTimer?.cancel();
    _liveStatusAckTimer = null;
    _liveStatusMissCount = 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLE NAME REQUEST
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestBleName() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final int crc = BMSCrcService.calculateCRC8([BMSProtocol.packetLength, BMSProtocol.idBleNameRequest]);
    final List<int> packet = [
      BMSProtocol.startByte, BMSProtocol.packetLength, BMSProtocol.idBleNameRequest, crc, BMSProtocol.stopByte,
    ];
    await _sendPacket(packet, logName: 'BLE_NAME_REQUEST', sentDataId: BMSProtocol.idBleNameRequest);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DASHBOARD REQUEST
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestDashboard() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final int crc = BMSCrcService.calculateCRC8([BMSProtocol.packetLength, BMSProtocol.idDashboardRequest]);
    final List<int> packet = [
      BMSProtocol.startByte, BMSProtocol.packetLength, BMSProtocol.idDashboardRequest, crc, BMSProtocol.stopByte,
    ];
    await _sendPacket(packet, logName: 'DASHBOARD_REQUEST', sentDataId: BMSProtocol.idDashboardRequest);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CELL VOLTAGE REQUEST
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestCellVoltages() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final int crc = BMSCrcService.calculateCRC8([BMSProtocol.packetLength, BMSProtocol.idCellVoltageRequest]);
    final List<int> packet = [
      BMSProtocol.startByte, BMSProtocol.packetLength, BMSProtocol.idCellVoltageRequest, crc, BMSProtocol.stopByte,
    ];
    await _sendPacket(packet, logName: 'CELL_VOLTAGE_REQUEST', sentDataId: BMSProtocol.idCellVoltageRequest);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACK HANDLING (handshake path — validated)
  // ─────────────────────────────────────────────────────────────────────────
  void _onAckReceived(BMSParsedPacket packet) {
    _ackTimer?.cancel();

    final bool valid = packet.startByte == BMSProtocol.ackStart &&
        packet.stopByte == BMSProtocol.ackStop &&
        packet.dataId == BMSProtocol.idAck &&
        packet.length == BMSProtocol.packetLength;

    if (!valid) {
      addDebugLog('❌ ACK validation FAILED — rejecting handshake');
      errorMessage = 'Invalid ACK received from BMS';
      state = BMSConnectionState.error;
      isConnecting = false;
      notifyListeners();
      return;
    }

    addDebugLog('✅ ACK validated — handshake confirmed');
    state = BMSConnectionState.ready;
    isConnecting = false;
    notifyListeners();

    _startDataSequence();
    startLiveStatusMonitor();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEQUENTIAL DATA FETCH: BLE Name → Dashboard → Cell Voltage
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startDataSequence() async {
    addDebugLog('▶️ Starting packet sequence');

    readyForDashboard = true;
    notifyListeners();

    final bleOk = await _sendAndWait(
      send: requestBleName,
      name: 'BLE Name',
      setCompleter: (c) => _bleNameCompleter = c,
      setLoading: (v) => isBleNameLoading = v,
      setError: (v) => bleNameError = v,
    );

    if (!bleOk) return;

    final dashOk = await _sendAndWait(
      send: requestDashboard,
      name: 'Dashboard',
      setCompleter: (c) => _dashboardCompleter = c,
      setLoading: (v) => isDashboardLoading = v,
      setError: (v) => dashboardError = v,
    );

    if (!dashOk) return;

    final cellOk = await _sendAndWait(
      send: requestCellVoltages,
      name: 'Cell Voltage',
      setCompleter: (c) => _cellVoltageCompleter = c,
      setLoading: (v) => isCellVoltageLoading = v,
      setError: (v) => cellVoltageError = v,
    );

    if (!cellOk) return;

    addDebugLog('✅ Initial data loaded');
  }

  Future<void> refreshCellVoltages() async {
    await _sendAndWait(
      send: requestCellVoltages,
      name: 'Cell Voltage',
      setCompleter: (c) => _cellVoltageCompleter = c,
      setLoading: (v) => isCellVoltageLoading = v,
      setError: (v) => cellVoltageError = v,
    );
  }

  /// Sends a request and waits (with timeout) for the matching response to
  /// arrive via the notify-listener, which completes the relevant Completer.
  Future<bool> _sendAndWait({
    required Future<void> Function() send,
    required String name,
    required void Function(Completer<bool>) setCompleter,
    required void Function(bool) setLoading,
    required void Function(String?) setError,
  }) async {
    final completer = Completer<bool>();
    setCompleter(completer);
    setLoading(true);
    setError(null);
    notifyListeners();

    try {
      await send();
    } catch (e) {
      setLoading(false);
      setError('$name packet failed to send: $e');
      addDebugLog('❌ $name packet send failed: $e');
      notifyListeners();
      return false;
    }

    final success = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );

    setLoading(false);
    if (!success) {
      setError('$name packet failed to receive');
      addDebugLog('❌ $name packet receive FAILED');
    } else {
      addDebugLog('✅ $name packet received successfully');
    }
    notifyListeners();
    return success;
  }

  Future<void> refreshCellVoltage() async {
    await _sendAndWait(
      send: requestCellVoltages,
      name: 'Cell Voltage',
      setCompleter: (c) => _cellVoltageCompleter = c,
      setLoading: (v) => isCellVoltageLoading = v,
      setError: (v) => cellVoltageError = v,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETTINGS PAGE — REQUEST SENDERS (read-back)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendDeviceDetailsRequest() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idDeviceDetailsRequest,
    ]);
    await _sendPacket(
      [
        BMSProtocol.startByte,
        BMSProtocol.packetLength,
        BMSProtocol.idDeviceDetailsRequest,
        crc,
        BMSProtocol.stopByte,
      ],
      logName: 'DEVICE_DETAILS_REQUEST',
      sentDataId: BMSProtocol.idDeviceDetailsRequest,
    );
  }

  /// Public one-shot request — call this when opening the Device Details
  /// sheet.
  Future<void> requestDeviceDetails() => _sendDeviceDetailsRequest();

  Future<void> _sendBatterySettingsRequest() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idBatterySettingsRequest,
    ]);
    await _sendPacket(
      [
        BMSProtocol.startByte,
        BMSProtocol.packetLength,
        BMSProtocol.idBatterySettingsRequest,
        crc,
        BMSProtocol.stopByte,
      ],
      logName: 'BATTERY_SETTINGS_REQUEST',
      sentDataId: BMSProtocol.idBatterySettingsRequest,
    );
  }

  Future<void> _sendProtectionSettingsRequest() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idProtectionSettingsRequest,
    ]);
    await _sendPacket(
      [
        BMSProtocol.startByte,
        BMSProtocol.packetLength,
        BMSProtocol.idProtectionSettingsRequest,
        crc,
        BMSProtocol.stopByte,
      ],
      logName: 'PROTECTION_SETTINGS_REQUEST',
      sentDataId: BMSProtocol.idProtectionSettingsRequest,
    );
  }

  Future<void> _sendTemperatureSettingsRequest() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idTemperatureSettingsRequest,
    ]);
    await _sendPacket(
      [
        BMSProtocol.startByte,
        BMSProtocol.packetLength,
        BMSProtocol.idTemperatureSettingsRequest,
        crc,
        BMSProtocol.stopByte,
      ],
      logName: 'TEMPERATURE_SETTINGS_REQUEST',
      sentDataId: BMSProtocol.idTemperatureSettingsRequest,
    );
  }

  Future<void> _sendFactorySettingsRequest() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idFactorySettingsRequest,
    ]);
    await _sendPacket(
      [
        BMSProtocol.startByte,
        BMSProtocol.packetLength,
        BMSProtocol.idFactorySettingsRequest,
        crc,
        BMSProtocol.stopByte,
      ],
      logName: 'FACTORY_SETTINGS_REQUEST',
      sentDataId: BMSProtocol.idFactorySettingsRequest,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETTINGS PAGE — "SET NOW" / ACTION SENDERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _sendActionAndWaitAck(
    List<int> packet, {
    required String logName,
    required int dataId,
  }) async {
    if (_writeChar == null) return false;

    final completer = Completer<bool>();
    _actionAckCompleter = completer;
    isActionInFlight = true;
    notifyListeners();

    try {
      await _sendPacket(packet, logName: logName, sentDataId: dataId);
    } catch (e) {
      isActionInFlight = false;
      addDebugLog('❌ $logName send failed: $e');
      notifyListeners();
      return false;
    }

    final success = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );

     isActionInFlight = false;
    addDebugLog(success ? '✅ $logName — ACK received' : '❌ $logName — no ACK received');
    notifyListeners();
    return success;
  }
Future<bool> _sendSettingsWrite(
    List<int> packet, {
    required String logName,
    required int dataId,
  }) async {
    if (_writeChar == null) return false;

    isActionInFlight = true;
    notifyListeners();

    bool sent = true;
    try {
      await _sendPacket(packet, logName: logName, sentDataId: dataId);
    } catch (e) {
      sent = false;
      addDebugLog('❌ $logName send failed: $e');
    }

    isActionInFlight = false;
    if (sent) addDebugLog('✅ $logName — sent (not waiting for response)');
    notifyListeners();
    return sent;
  }
  static List<int> _u16le(int value) {
    final v = value.clamp(0, 0xFFFF);
    return [v & 0xFF, (v >> 8) & 0xFF];
  }

  static int _i8(int value) {
    final v = value.clamp(-128, 127);
    return v < 0 ? (0x100 + v) & 0xFF : v & 0xFF;
  }

  static List<int> _asciiField(String value, int widthBytes) {
    final bytes = value.codeUnits.take(widthBytes).toList();
    while (bytes.length < widthBytes) {
      bytes.add(0x20); // space-pad — matches _decodeAscii's ignore-space logic
    }
    return bytes;
  }

  /// Battery Settings "Set Now" (0xB0, 18 bytes).
  Future<bool> sendBatterySettingsWrite({
    required int batteryString,          // 1-14
    required double ratedCapacityAh,     // 9.0-100.0
    required int socSetPercent,          // 0-100
    required int sleepWaitingTime,       // 0-65535
    required double balancedStartDiffVolt,  // 0.001-4.300
    required double balancedStartVolt,      // 0.001-4.300
    required double nominalCellVolt,        // 0-9.999
    required int cellChemistry,             // BMSProtocol.chemistry*
  }) {
    final buffer = <int>[
      BMSProtocol.startByte,
      BMSProtocol.batterySettingsResponseLength, // 18
      BMSProtocol.idBatterySettingsWrite,
      batteryString & 0xFF,
      ..._u16le((ratedCapacityAh * 10).round()),
      socSetPercent & 0xFF,
      ..._u16le(sleepWaitingTime),
      ..._u16le((balancedStartDiffVolt * 1000).round()),
      ..._u16le((balancedStartVolt * 1000).round()),
      ..._u16le((nominalCellVolt * 1000).round()),
      cellChemistry & 0xFF,
    ];
    final crc = BMSCrcService.calculateCRC8(buffer.sublist(1));
    buffer.add(crc);
    buffer.add(BMSProtocol.stopByte);
    return _sendSettingsWrite(
      buffer,
      logName: 'BATTERY_SETTINGS_SET_NOW',
      dataId: BMSProtocol.idBatterySettingsWrite,
    );
  }

  /// Calibrate Now (0xB1, 5-byte control packet).
  Future<bool> sendCalibration() {
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idCalibration,
    ]);
    final packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      BMSProtocol.idCalibration,
      crc,
      BMSProtocol.stopByte,
    ];
    return _sendActionAndWaitAck(
      packet,
      logName: 'CALIBRATE_NOW',
      dataId: BMSProtocol.idCalibration,
    );
  }

  /// Protection Settings "Set Now" (0xB2, 17 bytes).
  Future<bool> sendProtectionSettingsWrite({
    required double singleCellHighVolt,   // 2.000-4.300
    required double singleCellLowVolt,    // 2.000-4.300
    required double sumVoltHigh,          // 20-99.5
    required double sumVoltLow,           // 20-99.5
    required double chargeOverCurrent,    // 0-80.0
    required double dischargeOverCurrent, // 0-160.0
  }) {
    final buffer = <int>[
      BMSProtocol.startByte,
      BMSProtocol.protectionSettingsResponseLength, // 17
      BMSProtocol.idProtectionSettingsWrite,
      ..._u16le((singleCellHighVolt * 1000).round()),
      ..._u16le((singleCellLowVolt * 1000).round()),
      ..._u16le((sumVoltHigh * 10).round()),
      ..._u16le((sumVoltLow * 10).round()),
      ..._u16le((chargeOverCurrent * 10).round()),
      ..._u16le((dischargeOverCurrent * 10).round()),
    ];
    final crc = BMSCrcService.calculateCRC8(buffer.sublist(1));
    buffer.add(crc);
    buffer.add(BMSProtocol.stopByte);
    return _sendSettingsWrite(
      buffer,
      logName: 'PROTECTION_SETTINGS_SET_NOW',
      dataId: BMSProtocol.idProtectionSettingsWrite,
    );
  }

  /// Temperature Settings "Set Now" (0xB3, 11 bytes, single-byte fields).
  Future<bool> sendTemperatureSettingsWrite({
    required int noOfTempChannels,   // 1-9
    required int chargeHighTemp,     // 0..200
    required int chargeLowTemp,      // 0..-60
    required int dischargeHighTemp,  // 0..200
    required int dischargeLowTemp,   // 0..-60
    required int diffTempProtection, // 0..200
  }) {
    final buffer = <int>[
      BMSProtocol.startByte,
      BMSProtocol.temperatureSettingsResponseLength, // 11
      BMSProtocol.idTemperatureSettingsWrite,
      noOfTempChannels & 0xFF,
      chargeHighTemp & 0xFF,
      _i8(chargeLowTemp),
      dischargeHighTemp & 0xFF,
      _i8(dischargeLowTemp),
      diffTempProtection & 0xFF,
    ];
    final crc = BMSCrcService.calculateCRC8(buffer.sublist(1));
    buffer.add(crc);
    buffer.add(BMSProtocol.stopByte);
     return _sendSettingsWrite(
      buffer,
      logName: 'TEMPERATURE_SETTINGS_SET_NOW',
      dataId: BMSProtocol.idTemperatureSettingsWrite,
    );
  }

  /// Factory Settings "Set Now" (0xB4, 53 bytes).
  Future<bool> sendFactorySettingsWrite({
    required String batterySlNo,
    required String bmsSerialNo,
    required String bleDeviceName,
  }) {
    final buffer = <int>[
      BMSProtocol.startByte,
      BMSProtocol.factorySettingsResponseLength, // 53
      BMSProtocol.idFactorySettingsWrite,
      ..._asciiField(batterySlNo, 16),
      ..._asciiField(bmsSerialNo, 16),
      ..._asciiField(bleDeviceName, 16),
    ];
    final crc = BMSCrcService.calculateCRC8(buffer.sublist(1));
    buffer.add(crc);
    buffer.add(BMSProtocol.stopByte);
    return _sendSettingsWrite(
      buffer,
      logName: 'FACTORY_SETTINGS_SET_NOW',
      dataId: BMSProtocol.idFactorySettingsWrite,
    );
  }

  /// Firmware Upgrade (0xB5, 5-byte control packet).
  Future<bool> sendFirmwareUpgrade() {
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idFirmwareUpgrade,
    ]);
    final packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      BMSProtocol.idFirmwareUpgrade,
      crc,
      BMSProtocol.stopByte,
    ];
    return _sendActionAndWaitAck(
      packet,
      logName: 'FIRMWARE_UPGRADE',
      dataId: BMSProtocol.idFirmwareUpgrade,
    );
  }

  /// Restart (0xB6, 5-byte control packet).
  Future<bool> sendRestart() {
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idRestart,
    ]);
    final packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      BMSProtocol.idRestart,
      crc,
      BMSProtocol.stopByte,
    ];
    return _sendActionAndWaitAck(
      packet,
      logName: 'RESTART',
      dataId: BMSProtocol.idRestart,
    );
  }

  /// Factory Data Reset (0xB7, 5-byte control packet).
  Future<bool> sendFactoryReset() {
    final crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idFactoryReset,
    ]);
    final packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      BMSProtocol.idFactoryReset,
      crc,
      BMSProtocol.stopByte,
    ];
    return _sendActionAndWaitAck(
      packet,
      logName: 'FACTORY_DATA_RESET',
      dataId: BMSProtocol.idFactoryReset,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POLLING
  // ─────────────────────────────────────────────────────────────────────────
  void _startPolling() {
    return;
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startDashboardPolling() {
    _dashboardPollTimer?.cancel();
    _dashboardPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        if (state != BMSConnectionState.ready) return;
        if (isDashboardLoading) return;
        addDebugLog('🔁 Auto Refresh (Dashboard)');
        await requestDashboard();
      },
    );
  }

  void _stopDashboardPolling() {
    _dashboardPollTimer?.cancel();
    _dashboardPollTimer = null;
  }

  void _startCellVoltagePolling() {
    _cellVoltagePollTimer?.cancel();
    _cellVoltagePollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        if (state != BMSConnectionState.ready) return;
        if (isCellVoltageLoading) return;
        addDebugLog('🔁 Auto Refresh (Cell Voltage)');
        await requestCellVoltages();
      },
    );
  }

  void _stopCellVoltagePolling() {
    _cellVoltagePollTimer?.cancel();
    _cellVoltagePollTimer = null;
  }

  void startDashboardPolling() {
    _stopCellVoltagePolling();
    _startDashboardPolling();
  }

  void startCellVoltagePolling() {
    _stopDashboardPolling();
    _startCellVoltagePolling();
  }

  void stopAllPolling() {
    _stopDashboardPolling();
    _stopCellVoltagePolling();
  }

  Timer? _settingsPollingTimer;

  void stopSettingsPolling() {
    _settingsPollingTimer?.cancel();
    _settingsPollingTimer = null;
  }

  void startBatterySettingsPolling() {
    stopSettingsPolling();
    _sendBatterySettingsRequest();
  }

  void startProtectionSettingsPolling() {
    stopSettingsPolling();
    _sendProtectionSettingsRequest();
  }

  void startTempSettingsPolling() {
    stopSettingsPolling();
    _sendTemperatureSettingsRequest();
  }

  void startFactorySettingsPolling() {
    stopSettingsPolling();
    _sendFactorySettingsRequest();
  }
  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    state = BMSConnectionState.disconnecting;
    notifyListeners();

    _ackTimer?.cancel();
    _stopPolling();
    _stopDashboardPolling();
    _stopCellVoltagePolling();
    stopSettingsPolling();
    stopLiveStatusMonitor();

    if (_writeChar != null) {
      final int crc = BMSCrcService.calculateCRC8([BMSProtocol.packetLength, BMSProtocol.idDisconnect]);
      final List<int> packet = [
        BMSProtocol.startByte, BMSProtocol.packetLength, BMSProtocol.idDisconnect, crc, BMSProtocol.stopByte,
      ];
      await _sendPacket(packet, logName: 'DISCONNECT', sentDataId: BMSProtocol.idDisconnect);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _notifySub?.cancel();
    await _connectionStateSub?.cancel();
    await device?.disconnect();
    _cleanup();

    state = BMSConnectionState.disconnected;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CUSTOM PACKET SEND
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendCustom(int dataId) async {
    if (_writeChar == null) return;
    final int crc = BMSCrcService.calculateCRC8([BMSProtocol.packetLength, dataId]);
    final List<int> packet = [
      BMSProtocol.startByte, BMSProtocol.packetLength, dataId, crc, BMSProtocol.stopByte,
    ];
    await _sendPacket(packet, logName: 'CUSTOM 0x${dataId.toRadixString(16).toUpperCase()}', sentDataId: dataId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  void _addToLog(BMSParsedPacket packet) {
    packetLog.insert(0, packet);
    if (packetLog.length > 200) packetLog.removeLast();
    notifyListeners();
  }

  void addDebugLog(String message) {
    debugPrint(message);
    _debugLogs.add('[${_timeNow()}] $message');
    if (_debugLogs.length > _maxDebugLogs) {
      _debugLogs.removeAt(0);
    }
    notifyListeners();
  }

  void clearDebugLogs() {
    _debugLogs.clear();
    notifyListeners();
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void _newSession() {
    _sessionId++;
    packetLog.clear();
    latestDashboard   = null;
    latestCellVoltage = null;
    bleName           = null;
    batterySerial     = null;
    batteryType       = null;
    softwareVersion   = null;
    hardwareVersion   = null;
    firmwareVersion   = null;
    snCode            = null;

    latestBatterySettings = null;
    latestProtectionSettings = null;
    latestTemperatureSettings = null;
    latestFactorySettings = null;
    latestDeviceDetails = null;

    batterySettingsPulse = 0;
    protectionSettingsPulse = 0;
    temperatureSettingsPulse = 0;
    factorySettingsPulse = 0;
    deviceDetailsPulse = 0;

    isActionInFlight = false;
    _actionAckCompleter = null;

    _pendingRequests.clear();
    dashboardReady    = false;
    dashboardNavigationTriggered = false;

    readyForDashboard      = false;
    isBleNameLoading       = false;
    isDashboardLoading     = false;
    isCellVoltageLoading   = false;
    bleNameError           = null;
    dashboardError         = null;
    cellVoltageError       = null;
    _bleNameCompleter      = null;
    _dashboardCompleter    = null;
    _cellVoltageCompleter  = null;

    _ackTimer?.cancel();
    stopLiveStatusMonitor();
    _stopPolling();
  }

  void _cleanup() {
    _stopDashboardPolling();
    _stopCellVoltagePolling();
    stopSettingsPolling();
    stopLiveStatusMonitor();
    _notifyChar = null;
    _writeChar  = null;
    _notifySub?.cancel();
    _notifySub = null;
    _connectionStateSub?.cancel();
    _connectionStateSub = null;
    device = null;
    isConnecting = false;
    _pendingRequests.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _stopDashboardPolling();
    _stopCellVoltagePolling();
    stopSettingsPolling();
    stopLiveStatusMonitor();
    super.dispose();
  }

  String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
      .join(' ');
}