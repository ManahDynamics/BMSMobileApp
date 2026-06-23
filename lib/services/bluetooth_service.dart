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
  // readyForDashboard becomes true right after the BLE Name step finishes
  // (success OR failure) — this is the single signal the scan screen uses
  // to navigate to the Dashboard screen.
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

  // ── On-screen debug log ────────────────────────────────────────────────
  // Stores human-readable trace lines for the DebugLogOverlay widget.
  // Capped so it doesn't grow unbounded during long sessions.
  final List<String> _debugLogs = [];
  List<String> get debugLogs => List.unmodifiable(_debugLogs);
  static const int _maxDebugLogs = 300;

  // ── Latest valid packets ──────────────────────────────────────────────────
  BMSParsedPacket? latestDashboard;
  BMSParsedPacket? latestCellVoltage;

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

  int _sessionId = 0;

  BMSBluetoothService() {
    WidgetsBinding.instance.addObserver(this);
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
          debugPrint('⚠️  Device disconnected unexpectedly');
          addDebugLog('⚠️ Device disconnected unexpectedly');
          errorMessage = 'Device disconnected unexpectedly';
          state = BMSConnectionState.error;
          isConnecting = false;
          _stopPolling();
          _cleanup();
          notifyListeners();
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

    _notifySub = _notifyChar!.value.listen((raw) {
      if (raw.isEmpty) return;

      debugPrint('📥 RX [${raw.length} bytes] : ${_toHex(raw)}');
      addDebugLog('📥 RX [${raw.length}B]: ${_toHex(raw)}');

      final result = BMSPacketParser.parse(
        Uint8List.fromList(raw),
      );

      if (result.isSuccess && result.packet != null) {
        final packet = result.packet!.copyWith(direction: PacketDirection.receive);
        _addToLog(packet);
        debugPrint('✅ RX Parsed: ${packet.typeName}');
        addDebugLog('✅ Parsed: ${packet.typeName}');
        addDebugLog(
          '✅ Response received: 0x${result.packet!.dataId.toRadixString(16).toUpperCase()}',
        );

        if (packet.isCellVoltageResponse) {
          addDebugLog('🔋 Cell Voltage Response received');
          latestCellVoltage = packet;
          notifyListeners();
          if (_cellVoltageCompleter != null && !_cellVoltageCompleter!.isCompleted) {
            _cellVoltageCompleter!.complete(true);
          }

        } else if (packet.isDashboardResponse) {
          addDebugLog('📊 Dashboard Response received — CRC passed');
          addDebugLog('   Battery Serial = "${packet.batterySerial}"');

          latestDashboard = packet;

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

        } else if (packet.isDeviceInfo) {
          addDebugLog('ℹ️ Device info packet: 0x${packet.dataId.toRadixString(16)}');
          _updateDeviceInfo(packet);

        } else if (state == BMSConnectionState.waitingAck && packet.isAck) {
          addDebugLog('🤝 ACK packet received — validating…');
          _onAckReceived(packet);
        }

      } else {
        final reason = result.error?.name ?? 'unknown';
        final detail = result.errorDetail ?? '';
        debugPrint('❌ RX Parse Failed [$reason] $detail — last valid data retained');
        addDebugLog('❌ Parse FAILED [$reason] $detail');
      }
    });
  }

  void _updateDeviceInfo(BMSParsedPacket packet) {
    switch (packet.dataId) {
      case 0x59:
        batterySerial   = packet.batterySerial;
        addDebugLog('ℹ️ batterySerial (from 0x59) = "$batterySerial"');
      case 0x5A:
        softwareVersion = packet.softwareVersion;
      case 0x5B:
        hardwareVersion = packet.hardwareVersion;
      case 0x5C:
        snCode          = packet.snCode;
    }
    notifyListeners();
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
    notifyListeners();

    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(seconds: 5), () {
      if (state == BMSConnectionState.waitingAck) {
        addDebugLog('⏰ ACK TIMEOUT — no response within 5s');
        errorMessage = 'Handshake timeout — no response from device';
        state = BMSConnectionState.error;
        isConnecting = false;
        notifyListeners();
      }
    });
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
  // ACK VALIDATION
  // ─────────────────────────────────────────────────────────────────────────
  void _onAckReceived(BMSParsedPacket packet) {
    _ackTimer?.cancel();

    const int expStart  = BMSProtocol.ackStart;
    const int expLength = BMSProtocol.packetLength;
    const int expDataId = BMSProtocol.idAck;
    const int expStop   = BMSProtocol.ackStop;
    final int  expCrc   = BMSCrcService.calculateCRC8([expLength, expDataId]);

    final List<int> expectedAck = [expStart, expLength, expDataId, expCrc, expStop];
    final List<int> receivedAck = packet.rawBytes.toList();

    final bool matches = receivedAck.length == expectedAck.length &&
        List.generate(expectedAck.length, (i) => receivedAck[i] == expectedAck[i]).every((ok) => ok);

    if (matches) {
      addDebugLog('✅ ACK validated — state = ready');
      state = BMSConnectionState.ready;
      isConnecting = false;
      notifyListeners();
      _startDataSequence();
    } else {
      addDebugLog('❌ ACK validation FAILED — '
          'expected=${_toHex(expectedAck)} received=${_toHex(receivedAck)}');
      errorMessage = 'ACK validation failed — device not authenticated.';
      state = BMSConnectionState.error;
      isConnecting = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEQUENTIAL DATA FETCH: BLE Name → Dashboard → Cell Voltages
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Flow:
  //   1. ACK validated → request BLE Name.
  //   2. Whether BLE Name succeeds or fails, `readyForDashboard` is set so
  //      the scan screen navigates to the Dashboard screen.
  //   3. If BLE Name FAILED  -> stop here. Dashboard screen shows the BLE
  //      Name error and the Dashboard / Cell Voltage sections never start
  //      loading (they stay in their initial "waiting" state).
  //   4. If BLE Name SUCCEEDED -> request Dashboard packet (Dashboard
  //      screen shows a loading indicator for that section until it
  //      arrives or times out).
  //   5. If Dashboard FAILED -> stop here (Cell Voltage section stays
  //      "waiting").
  //   6. If Dashboard SUCCEEDED -> request Cell Voltage packet (loading
  //      indicator shown until it arrives or times out).
  Future<void> _startDataSequence() async {
    addDebugLog('▶️ ACK validated — requesting BLE name…');

    final bleOk = await _sendAndWait(
      send: requestBleName,
      name: 'BLE Name',
      setCompleter: (c) => _bleNameCompleter = c,
      setLoading: (v) => isBleNameLoading = v,
      setError: (v) => bleNameError = v,
    );

    // Navigate to the Dashboard screen regardless of the outcome — any
    // BLE Name error will be displayed there instead of on the scan screen.
    readyForDashboard = true;
    notifyListeners();

    if (!bleOk) {
      addDebugLog('❌ BLE Name failed — stopping sequence, error shown on dashboard');
      return;
    }

    final dashOk = await _sendAndWait(
      send: requestDashboard,
      name: 'Dashboard',
      setCompleter: (c) => _dashboardCompleter = c,
      setLoading: (v) => isDashboardLoading = v,
      setError: (v) => dashboardError = v,
    );
    if (!dashOk) {
      addDebugLog('❌ Dashboard packet failed — stopping sequence');
      return;
    }

    final cellOk = await _sendAndWait(
      send: requestCellVoltages,
      name: 'Cell Voltage',
      setCompleter: (c) => _cellVoltageCompleter = c,
      setLoading: (v) => isCellVoltageLoading = v,
      setError: (v) => cellVoltageError = v,
    );
    if (!cellOk) {
      addDebugLog('❌ Cell Voltage packet failed — stopping sequence');
      return;
    }

    addDebugLog('✅ Sequential data fetch complete — all packets received');
  }
/// Re-requests cell voltages outside the initial sequence (e.g. when the
  /// Cells screen opens or the user pulls to refresh). Goes through the
  /// same loading/error tracking as the initial sequence so both screens
  /// stay in sync.
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
  const Duration(seconds: 20),
  onTimeout: () {
    addDebugLog('⏰ $name timed out after 20s');
    return false;
  },
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

  // ─────────────────────────────────────────────────────────────────────────
  // POLLING (disabled — replaced by sequential one-shot fetch above)
  // ─────────────────────────────────────────────────────────────────────────
  void _startPolling() {
    return;
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void startCellVoltagePolling() {}
  void stopCellVoltagePolling()  {}

  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    state = BMSConnectionState.disconnecting;
    notifyListeners();

    _ackTimer?.cancel();
    _stopPolling();

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

  /// Appends a line to the on-screen debug log (used by DebugLogOverlay)
  /// AND prints it to the regular debug console, so both views stay in sync.
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
    _stopPolling();
    // Note: _debugLogs is intentionally NOT cleared on new session, so you
    // can see the full history across a reconnect attempt. Use the trash
    // icon in DebugLogOverlay (or call clearDebugLogs()) to reset manually.
  }

  void _cleanup() {
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
    super.dispose();
  }

  String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
      .join(' ');
}