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
  bool dashboardReady = false;

  bool dashboardNavigationTriggered = false;

  final List<BMSParsedPacket> packetLog = [];

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
  int? _lastSentDataId;

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

    try {
      isConnecting = true;
      state = BMSConnectionState.connecting;
      notifyListeners();

      await d.connect(timeout: const Duration(seconds: 15));
      device = d;
      debugPrint('✅ BLE CONNECTED');

      _connectionStateSub = d.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected &&
            state != BMSConnectionState.disconnecting &&
            state != BMSConnectionState.disconnected) {
          debugPrint('⚠️  Device disconnected unexpectedly');
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
      } catch (e) {
        debugPrint('⚠️  MTU request failed (non-fatal): $e');
      }

      await _discoverServices();
      await sendHandshake();
    } catch (e, st) {
      debugPrint('❌ CONNECT ERROR: $e\n$st');
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
      throw Exception('Required BLE characteristics not found.');
    }

    await _startListening();
    state = BMSConnectionState.connected;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // START LISTENING (RX)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    debugPrint('📡 SUBSCRIBING TO NOTIFICATIONS…');
    await _notifyChar!.setNotifyValue(true);

    _notifySub = _notifyChar!.value.listen((raw) {
      if (raw.isEmpty) return;

      debugPrint('📥 RX [${raw.length} bytes] : ${_toHex(raw)}');

      final result = BMSPacketParser.parse(
        Uint8List.fromList(raw),
        lastSentDataId: _lastSentDataId,
      );

      if (result.isSuccess && result.packet != null) {
        final packet = result.packet!.copyWith(direction: PacketDirection.receive);
        _addToLog(packet);
        debugPrint('✅ RX Parsed: ${packet.typeName}');

        if (packet.isCellVoltageResponse) {
          addDebugLog('Cell Voltage Response Received');
  latestCellVoltage = packet;

  if (!dashboardReady) {
    dashboardReady = true;
    debugPrint('🚀 Dashboard Ready from Cell Voltage');
  }
  notifyListeners();
        } else if (packet.isDashboardResponse) {
  addDebugLog('Dashboard Response Received');
  addDebugLog('Battery Serial = ${packet.batterySerial}');

  latestDashboard = packet;
if (!dashboardReady) {
  dashboardReady = true;
}
 notifyListeners();
  if (packet.batteryType != null) {
    batteryType = packet.batteryType;
  }

  if (packet.batterySerial != null) {
    batterySerial = packet.batterySerial;
  }

  if (packet.softwareVersion != null) {
    softwareVersion = packet.softwareVersion;
  }

  if (packet.hardwareVersion != null) {
    hardwareVersion = packet.hardwareVersion;
  }

  if (packet.firmwareVersion != null) {
    firmwareVersion = packet.firmwareVersion;
  }

  dashboardReady = true;

  debugPrint('🚀 Dashboard Ready');

  notifyListeners();

        } else if (packet.isBleNameResponse) {
          if (packet.bleName != null) {
            bleName = packet.bleName;
            debugPrint('📋 BLE Name: $bleName');
          }
          notifyListeners();

        } else if (packet.isDeviceInfo) {
          _updateDeviceInfo(packet);

        } else if (state == BMSConnectionState.waitingAck && packet.isAck) {
          _onAckReceived(packet);
        }

      } else {
        final reason = result.error?.name ?? 'unknown';
        final detail = result.errorDetail ?? '';
        debugPrint('❌ RX Parse Failed [$reason] $detail — last valid data retained');
      }
    });
  }

  void _updateDeviceInfo(BMSParsedPacket packet) {
    switch (packet.dataId) {
      case 0x59:
        batterySerial   = packet.batterySerial;
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
      _lastSentDataId = sentDataId;
    }

    final bool useWithoutResponse = _writeChar!.properties.writeWithoutResponse;
    debugPrint('📤 TX${logName != null ? " ($logName)" : ""} : ${_toHex(packetBytes)}');

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
      state = BMSConnectionState.ready;
      isConnecting = false;
      notifyListeners();
      _requestBleNameThenStartPolling();
    } else {
      errorMessage = 'ACK validation failed — device not authenticated.';
      state = BMSConnectionState.error;
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> _requestBleNameThenStartPolling() async {
    await requestBleName();
    await Future.delayed(const Duration(milliseconds: 500));
    _startPolling();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POLLING
  // ─────────────────────────────────────────────────────────────────────────
  void _startPolling() {
    _stopPolling();
    _doPollCycle();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _doPollCycle());
  }

  Future<void> _doPollCycle() async {
    await requestDashboard();
    await Future.delayed(const Duration(seconds: 1));
    await requestCellVoltages();
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

  void addDebugLog(String message) {
    debugPrint(message);
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
    _lastSentDataId   = null;
    dashboardReady = false;
    dashboardNavigationTriggered = false;
    _ackTimer?.cancel();
    _stopPolling();
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
    _lastSentDataId = null;
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