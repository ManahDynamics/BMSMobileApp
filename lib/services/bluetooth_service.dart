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
  disconnected,
  connecting,
  connected,
  discovering,
  handshakeSent,
  waitingAck,
  ready,
  disconnecting,
  error,
}

class BMSBluetoothService extends ChangeNotifier {
  // ── Public state ───────────────────────────────────────────────────────────
  BluetoothDevice? device;
  BMSConnectionState state = BMSConnectionState.disconnected;
  String? errorMessage;
  bool isConnecting = false;

  /// Every sent / received packet (newest first)
  final List<BMSParsedPacket> packetLog = [];

  // ── Private ────────────────────────────────────────────────────────────────
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription? _notifySub;
  Timer? _ackTimer;
  int _sessionId = 0;

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

      state = BMSConnectionState.connected;
      notifyListeners();

      await _discoverServices();
      await sendHandshake();
    } catch (e, st) {
      debugPrint('❌ CONNECT ERROR: $e\n$st');
      errorMessage = e.toString();
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
            '    CHAR : ${c.uuid} | write:${c.properties.write} notify:${c.properties.notify}');
      }
    }
    debugPrint('────────────────────────────────────');

    // Find notify and write characteristics
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.notify) {
          _notifyChar = c;
        }
        if (c.properties.write && _writeChar == null) {
          _writeChar = c;
        }
      }
    }

    // Fallback for write without response
    if (_writeChar == null) {
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.writeWithoutResponse) {
            _writeChar = c;
            break;
          }
        }
        if (_writeChar != null) break;
      }
    }

    if (_notifyChar == null || _writeChar == null) {
      throw Exception('Required BLE characteristics not found on this device.');
    }

    await _startListening();

    state = BMSConnectionState.connected;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // START LISTENING (RX)
  // Every received packet is parsed, logged, and displayed in Packets tab.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    debugPrint('📡 SUBSCRIBING TO NOTIFICATIONS…');
    await _notifyChar!.setNotifyValue(true);

    _notifySub = _notifyChar!.value.listen((raw) {
      if (raw.isEmpty) return;

      final hex = _toHex(raw);
      debugPrint('📥 RX  : $hex');

      final result = BMSPacketParser.parse(Uint8List.fromList(raw));

      if (result.isSuccess && result.packet != null) {
        // Tag as received and add to log → shows in Packets tab immediately
        final packet = result.packet!.copyWith(direction: PacketDirection.receive);
        _addToLog(packet);

        debugPrint('✅ RX Parsed: ${packet.typeName}');

        // Only validate ACK when we are actively waiting for one
        if (state == BMSConnectionState.waitingAck && packet.isAck) {
          _onAckReceived(packet);
        }
      } else {
        debugPrint('❌ RX Parse Failed: ${result.error}');

        // Log raw failed packet so it still appears in Packets tab
        final failedPacket = BMSParsedPacket(
          startByte:  raw.isNotEmpty ? raw[0] & 0xFF : 0,
          length:     raw.length > 1 ? raw[1] & 0xFF : 0,
          dataId:     raw.length > 2 ? raw[2] & 0xFF : 0,
          crc:        raw.length > 3 ? raw[3] & 0xFF : 0,
          stopByte:   raw.length > 4 ? raw[4] & 0xFF : 0,
          rawBytes:   Uint8List.fromList(raw),
          receivedAt: DateTime.now(),
          direction:  PacketDirection.receive,
        );
        _addToLog(failedPacket);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMMON SEND METHOD
  // Every sent packet is parsed and logged → shows in Packets tab.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendPacket(List<int> packetBytes, {String? logName}) async {
    if (_writeChar == null) return;

    final bool useWithResponse = _writeChar!.properties.write;
    final hex = _toHex(packetBytes);

    debugPrint('📤 TX${logName != null ? " ($logName)" : ""} : $hex');

    // Parse and log the sent packet so it appears in Packets tab
    final result = BMSPacketParser.parse(Uint8List.fromList(packetBytes));
    if (result.isSuccess && result.packet != null) {
      final packet = result.packet!.copyWith(direction: PacketDirection.send);
      _addToLog(packet);
    }

    await _writeChar!.write(packetBytes, withoutResponse: !useWithResponse);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HANDSHAKE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendHandshake() async {
    // CRC calculated over [start, length, dataId] = [0xCC, 0x05, 0x90]
    final int crc = BMSCrcService.calculateCRC8([0xCC, 0x05, 0x90]);
    final List<int> packet = [0xCC, 0x05, 0x90, crc, 0xDD];

    debugPrint('🤝 HANDSHAKE packet : ${_toHex(packet)}');

    state = BMSConnectionState.handshakeSent;
    notifyListeners();

    await _sendPacket(packet, logName: 'HANDSHAKE');

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
  // ACK VALIDATION
  //
  // Expected ACK from BMS: [0xAA, 0x05, 0x50, crc, 0xBB]
  // CRC is computed over   [0xAA, 0x05, 0x50]  (start + length + dataId)
  //
  // Both full byte-for-byte match required → redirect to Dashboard.
  // Any mismatch           → error state   → SnackBar shown, no redirect.
  // ─────────────────────────────────────────────────────────────────────────
  void _onAckReceived(BMSParsedPacket packet) {
    _ackTimer?.cancel();

    // ── Build our expected ACK ──────────────────────────────────────────────
    const int expStart  = BMSProtocol.ackStart;    // 0xAA
    const int expLength = BMSProtocol.packetLength; // 0x05
    const int expDataId = BMSProtocol.idAck;        // 0x50
    const int expStop   = BMSProtocol.ackStop;      // 0xBB

    final int expCrc = BMSCrcService.calculateCRC8([expStart, expLength, expDataId]);

    final List<int> expectedAck = [expStart, expLength, expDataId, expCrc, expStop];

    // ── Compare byte-for-byte with received packet ──────────────────────────
    final List<int> receivedAck = packet.rawBytes.toList();

    final bool matches = receivedAck.length == expectedAck.length &&
        List.generate(
          expectedAck.length,
          (i) => receivedAck[i] == expectedAck[i],
        ).every((ok) => ok);

    debugPrint('══════════════════════════════════════════');
    debugPrint('🔐 ACK VALIDATION');
    debugPrint('   Expected : ${_toHex(expectedAck)}');
    debugPrint('   Received : ${_toHex(receivedAck)}');
    debugPrint(
        '   Exp CRC  : 0x${expCrc.toRadixString(16).toUpperCase().padLeft(2, "0")}');
    debugPrint(
        '   Rcv CRC  : 0x${receivedAck[3].toRadixString(16).toUpperCase().padLeft(2, "0")}');
    debugPrint('   Result   : ${matches ? "✅ MATCH — VALID" : "❌ MISMATCH — REJECTED"}');
    debugPrint('══════════════════════════════════════════');

    if (matches) {
      debugPrint('🎉 ACK VALID — Redirecting to Dashboard');
      state = BMSConnectionState.ready;       // → triggers _navigateToDashboard()
    } else {
      debugPrint('🚫 ACK INVALID — Connection rejected');
      errorMessage =
          'ACK validation failed — device not authenticated.\n'
          'Expected : ${_toHex(expectedAck)}\n'
          'Received : ${_toHex(receivedAck)}';
      state = BMSConnectionState.error;       // → shows SnackBar, no redirect
    }

    isConnecting = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    debugPrint('🔌 DISCONNECT');

    state = BMSConnectionState.disconnecting;
    notifyListeners();

    _ackTimer?.cancel();

    if (_writeChar != null) {
      // CRC over [start, length, dataId] = [0xCC, 0x05, 0x91]
      final int crc = BMSCrcService.calculateCRC8([0xCC, 0x05, 0x91]);
      final List<int> packet = [0xCC, 0x05, 0x91, crc, 0xDD];

      await _sendPacket(packet, logName: 'DISCONNECT');
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _notifySub?.cancel();
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

    // CRC over [start, length, dataId]
    final int crc = BMSCrcService.calculateCRC8([0xCC, 0x05, dataId]);
    final List<int> packet = [0xCC, 0x05, dataId, crc, 0xDD];

    await _sendPacket(
        packet, logName: 'CUSTOM 0x${dataId.toRadixString(16).toUpperCase()}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOG HELPER — inserts packet at top, caps at 200, notifies listeners
  // ─────────────────────────────────────────────────────────────────────────
  void _addToLog(BMSParsedPacket packet) {
    packetLog.insert(0, packet);
    if (packetLog.length > 200) packetLog.removeLast();
    notifyListeners();
  }

  void _newSession() {
    _sessionId++;
    packetLog.clear();
    _ackTimer?.cancel();
  }

  void _cleanup() {
    _notifyChar = null;
    _writeChar = null;
    _notifySub = null;
    device = null;
    isConnecting = false;
  }

  String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
      .join(' ');
}