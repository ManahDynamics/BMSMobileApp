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

  final List<BMSParsedPacket> packetLog = [];

  // ── Latest valid packets ──────────────────────────────────────────────────
  BMSParsedPacket? latestDashboard;
  BMSParsedPacket? latestCellVoltage;

  // ── Device info ───────────────────────────────────────────────────────────
  // bleName   : from 0x51 BLE Name Response (sent once after ACK)
  // batterySerial, softwareVersion, hardwareVersion : from 0x52 Dashboard
  String? bleName;
  String? batterySerial;
  String? softwareVersion;
  String? hardwareVersion;
  String? snCode;

  // ── Tracks the Data ID of the most recently sent request ──────────────────
  int? _lastSentDataId;

  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription? _notifySub;
  StreamSubscription? _connectionStateSub;
  Timer? _ackTimer;

  // Single combined poll timer — fires every 5s
  // Each tick: send dashboard, wait 1s, send cell voltage
  Timer? _pollTimer;

  int _sessionId = 0;

  BMSBluetoothService() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        debugPrint('📴 App backgrounded — pausing polling');
        _stopPolling();
        break;
      case AppLifecycleState.resumed:
        if (state == AppLifecycleState.resumed) {
          debugPrint('📲 App foregrounded — resuming polling');
          _startPolling();
        }
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

    debugPrint('────────────────────────────────────');
    for (final s in services) {
      debugPrint('  SERVICE: ${s.uuid}');
      for (final c in s.characteristics) {
        debugPrint(
          '    CHAR : ${c.uuid}'
          ' | write:${c.properties.write}'
          ' | writeNoResp:${c.properties.writeWithoutResponse}'
          ' | notify:${c.properties.notify}'
          ' | read:${c.properties.read}',
        );
      }
    }
    debugPrint('────────────────────────────────────');

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

    debugPrint('✅ Using notify char : ${_notifyChar!.uuid}');
    debugPrint('✅ Using write  char : ${_writeChar!.uuid}');

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
          // 88-byte cell voltage packet (0x53)
          latestCellVoltage = packet;
          debugPrint('🔋 Cell Voltage updated: $packet');
          notifyListeners();

        } else if (packet.isDashboardResponse) {
          // 86-byte dashboard packet (0x52)
          latestDashboard = packet;
          if (packet.batterySerial   != null) batterySerial   = packet.batterySerial;
          if (packet.softwareVersion != null) softwareVersion = packet.softwareVersion;
          if (packet.hardwareVersion != null) hardwareVersion = packet.hardwareVersion;
          if (packet.snCode          != null) snCode          = packet.snCode;
          debugPrint('📊 Dashboard updated: $packet');
          notifyListeners();

        } else if (packet.isBleNameResponse) {
          // 19-byte BLE Name packet (0x51)
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

        _addToLog(BMSParsedPacket(
          startByte:  raw.isNotEmpty ? raw[0] & 0xFF : 0,
          length:     raw.length > 1 ? raw[1] & 0xFF : 0,
          dataId:     raw.length > 2 ? raw[2] & 0xFF : 0,
          crc:        raw.length > 3 ? raw[3] & 0xFF : 0,
          stopByte:   raw.isNotEmpty ? raw[raw.length - 1] & 0xFF : 0,
          rawBytes:   Uint8List.fromList(raw),
          receivedAt: DateTime.now(),
          direction:  PacketDirection.receive,
        ));
      }
    });
  }

  // ── Device info routing ────────────────────────────────────────────────────
  void _updateDeviceInfo(BMSParsedPacket packet) {
    switch (packet.dataId) {
      case 0x59:
        batterySerial   = packet.batterySerial;
        debugPrint('📋 Battery Serial: $batterySerial');
      case 0x5A:
        softwareVersion = packet.softwareVersion;
        debugPrint('📋 Software Version: $softwareVersion');
      case 0x5B:
        hardwareVersion = packet.hardwareVersion;
        debugPrint('📋 Hardware Version: $hardwareVersion');
      case 0x5C:
        snCode          = packet.snCode;
        debugPrint('📋 SN Code: $snCode');
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEND PACKET (internal)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendPacket(
    List<int> packetBytes, {
    String? logName,
    int?    sentDataId,
  }) async {
    if (_writeChar == null) return;

    if (sentDataId != null) {
      _lastSentDataId = sentDataId;
      debugPrint('📌 lastSentDataId → 0x${sentDataId.toRadixString(16).toUpperCase().padLeft(2,"0")}');
    }

    final bool useWithoutResponse = _writeChar!.properties.writeWithoutResponse;

    debugPrint(
      '📤 TX${logName != null ? " ($logName)" : ""}'
      ' [withoutResponse=$useWithoutResponse] : ${_toHex(packetBytes)}',
    );

    final result = BMSPacketParser.parse(Uint8List.fromList(packetBytes));
    if (result.isSuccess && result.packet != null) {
      _addToLog(result.packet!.copyWith(direction: PacketDirection.send));
    }

    await _writeChar!.write(packetBytes, withoutResponse: useWithoutResponse);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HANDSHAKE  →  CC 05 90 <crc> DD
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendHandshake() async {
    final int crc = BMSCrcService.calculateCRC8([0x05, BMSProtocol.idHandshake]);
    final List<int> packet = [
      BMSProtocol.startByte,
      0x05,
      BMSProtocol.idHandshake,
      crc,
      BMSProtocol.stopByte,
    ];

    debugPrint('🤝 HANDSHAKE packet : ${_toHex(packet)}');

    state = BMSConnectionState.handshakeSent;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    await _sendPacket(
      packet,
      logName: 'HANDSHAKE',
      sentDataId: BMSProtocol.idHandshake,
    );

    state = BMSConnectionState.waitingAck;
    notifyListeners();

    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(seconds: 5), () {
      if (state == BMSConnectionState.waitingAck) {
        debugPrint('⏰ ACK TIMEOUT');
        errorMessage = 'Handshake timeout — no response from device';
        state = BMSConnectionState.error;
        isConnecting = false;
        notifyListeners();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLE NAME REQUEST  →  CC 05 92 <crc> DD
  // Sent once immediately after ACK is validated.
  // Response: AA 13 51 [14 bytes BLE name] <crc> BB
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestBleName() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;

    final int crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idBleNameRequest,
    ]);
    final List<int> packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      BMSProtocol.idBleNameRequest,
      crc,
      BMSProtocol.stopByte,
    ];

    debugPrint('📤 BLE NAME REQUEST (0x92) : ${_toHex(packet)}');
    await _sendPacket(
      packet,
      logName: 'BLE_NAME_REQUEST',
      sentDataId: BMSProtocol.idBleNameRequest,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DASHBOARD REQUEST  →  CC 05 93 <crc> DD
  // Response: AA 55 52 [82 bytes data] <crc_h> <crc_l> BB  (86 bytes total)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestDashboard() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;

    final int crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idDashboardRequest,
    ]);
    final List<int> packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      BMSProtocol.idDashboardRequest,
      crc,
      BMSProtocol.stopByte,
    ];

    debugPrint('📤 DASHBOARD REQUEST (0x93) : ${_toHex(packet)}');
    await _sendPacket(
      packet,
      logName: 'DASHBOARD_REQUEST',
      sentDataId: BMSProtocol.idDashboardRequest,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CELL VOLTAGE REQUEST  →  CC 05 94 <crc> DD
  // Response: AA 57 53 [84 bytes data] <crc_h> <crc_l> BB  (88 bytes total)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestCellVoltages() async {
    if (_writeChar == null || state != BMSConnectionState.ready) return;

    final int crc = BMSCrcService.calculateCRC8([
      BMSProtocol.packetLength,
      BMSProtocol.idCellVoltageRequest,
    ]);
    final List<int> packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      BMSProtocol.idCellVoltageRequest,
      crc,
      BMSProtocol.stopByte,
    ];

    debugPrint('📤 CELL VOLTAGE REQUEST (0x94) : ${_toHex(packet)}');
    await _sendPacket(
      packet,
      logName: 'CELL_VOLTAGE_REQUEST',
      sentDataId: BMSProtocol.idCellVoltageRequest,
    );
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
        List.generate(expectedAck.length, (i) => receivedAck[i] == expectedAck[i])
            .every((ok) => ok);

    debugPrint('══════════════════════════════════════════');
    debugPrint('🔐 ACK VALIDATION');
    debugPrint('   Expected : ${_toHex(expectedAck)}');
    debugPrint('   Received : ${_toHex(receivedAck)}');
    debugPrint('   Result   : ${matches ? "✅ MATCH" : "❌ MISMATCH"}');
    debugPrint('══════════════════════════════════════════');

    if (matches) {
      debugPrint('🎉 ACK VALID — Requesting BLE name, then starting polling');
      state = BMSConnectionState.ready;
      isConnecting = false;
      notifyListeners();

      // Step 1: request BLE name immediately after ACK
      // Step 2: start the combined dashboard + cell polling
      _requestBleNameThenStartPolling();
    } else {
      debugPrint('🚫 ACK INVALID — Connection rejected');
      errorMessage =
          'ACK validation failed — device not authenticated.\n'
          'Expected : ${_toHex(expectedAck)}\n'
          'Received : ${_toHex(receivedAck)}';
      state = BMSConnectionState.error;
      isConnecting = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST-ACK SEQUENCE
  //  1. Send BLE name request (0x92)
  //  2. Wait 500ms for response
  //  3. Start combined polling
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _requestBleNameThenStartPolling() async {
    await requestBleName();
    // Give the device 500ms to respond with BLE name before we start
    // firing dashboard + cell requests
    await Future.delayed(const Duration(milliseconds: 500));
    _startPolling();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMBINED POLLING
  //
  // Every 5 seconds:
  //   t+0s : send Dashboard request  (0x93)
  //   t+1s : send Cell Voltage request (0x94)
  //
  // This ensures both requests are always active (not just when
  // CellsScreen is open) so cell data is ready for the graph.
  // ─────────────────────────────────────────────────────────────────────────
  void _startPolling() {
    _stopPolling();
    debugPrint('⏱️  Starting combined poll (dashboard @ 0s, cells @ +1s, every 5s)');

    // Fire immediately
    _doPollCycle();

    // Then every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _doPollCycle());
  }

  Future<void> _doPollCycle() async {
    // Dashboard first
    await requestDashboard();
    // Wait 1 second, then request cell voltages
    await Future.delayed(const Duration(seconds: 1));
    await requestCellVoltages();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    debugPrint('⏹️  Polling stopped');
  }

  // ── Legacy stubs kept so CellsScreen compile doesn't break ────────────────
  // CellsScreen calls these in initState/dispose but polling is now always on.
  void startCellVoltagePolling() {
    debugPrint('ℹ️  startCellVoltagePolling() called — cell polling is always active');
  }

  void stopCellVoltagePolling() {
    debugPrint('ℹ️  stopCellVoltagePolling() called — cell polling continues in background');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    debugPrint('🔌 DISCONNECT');
    state = BMSConnectionState.disconnecting;
    notifyListeners();

    _ackTimer?.cancel();
    _stopPolling();

    if (_writeChar != null) {
      final int crc = BMSCrcService.calculateCRC8([
        BMSProtocol.packetLength,
        BMSProtocol.idDisconnect,
      ]);
      final List<int> packet = [
        BMSProtocol.startByte,
        BMSProtocol.packetLength,
        BMSProtocol.idDisconnect,
        crc,
        BMSProtocol.stopByte,
      ];
      await _sendPacket(
        packet,
        logName: 'DISCONNECT',
        sentDataId: BMSProtocol.idDisconnect,
      );
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
  // CUSTOM PACKET SEND (public)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendCustom(int dataId) async {
    if (_writeChar == null) return;
    final int crc = BMSCrcService.calculateCRC8([BMSProtocol.packetLength, dataId]);
    final List<int> packet = [
      BMSProtocol.startByte,
      BMSProtocol.packetLength,
      dataId,
      crc,
      BMSProtocol.stopByte,
    ];
    await _sendPacket(
      packet,
      logName: 'CUSTOM 0x${dataId.toRadixString(16).toUpperCase()}',
      sentDataId: dataId,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  void _addToLog(BMSParsedPacket packet) {
    packetLog.insert(0, packet);
    if (packetLog.length > 200) packetLog.removeLast();
    notifyListeners();
  }

  void _newSession() {
    _sessionId++;
    packetLog.clear();
    latestDashboard   = null;
    latestCellVoltage = null;
    bleName           = null;
    batterySerial     = null;
    softwareVersion   = null;
    hardwareVersion   = null;
    snCode            = null;
    _lastSentDataId   = null;
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