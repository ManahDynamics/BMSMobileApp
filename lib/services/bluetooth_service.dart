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

class BMSBluetoothService extends ChangeNotifier {
  BluetoothDevice? device;
  BMSConnectionState state = BMSConnectionState.disconnected;
  String? errorMessage;
  bool isConnecting = false;

  final List<BMSParsedPacket> packetLog = [];

  // Latest Packet 4 — null until first packet received
  BMSParsedPacket? latestPacket4;

  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription? _notifySub;
  StreamSubscription? _connectionStateSub;
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

      _connectionStateSub = d.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected &&
            state != BMSConnectionState.disconnecting &&
            state != BMSConnectionState.disconnected) {
          debugPrint('⚠️  Device disconnected unexpectedly');
          errorMessage = 'Device disconnected unexpectedly';
          state = BMSConnectionState.error;
          isConnecting = false;
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
        if (c.properties.notify && _notifyChar == null) {
          _notifyChar = c;
        }
        if (_writeChar == null) {
          if (c.properties.writeWithoutResponse) {
            _writeChar = c;
          } else if (c.properties.write) {
            _writeChar = c;
          }
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

      debugPrint('📥 RX : ${_toHex(raw)}');

      final result = BMSPacketParser.parse(Uint8List.fromList(raw));

      if (result.isSuccess && result.packet != null) {
        final packet = result.packet!.copyWith(direction: PacketDirection.receive);
        _addToLog(packet);
        debugPrint('✅ RX Parsed: ${packet.typeName}');

        // Store latest Packet 4 for dashboard
        if (packet.isPacket4) {
          latestPacket4 = packet;
          debugPrint('📊 Packet4: $packet');
        }

        if (state == BMSConnectionState.waitingAck && packet.isAck) {
          _onAckReceived(packet);
        }
      } else {
        debugPrint('❌ RX Parse Failed: ${result.error}');
        _addToLog(BMSParsedPacket(
          startByte:  raw.isNotEmpty ? raw[0] & 0xFF : 0,
          length:     raw.length > 1 ? raw[1] & 0xFF : 0,
          dataId:     raw.length > 2 ? raw[2] & 0xFF : 0,
          crc:        raw.length > 3 ? raw[3] & 0xFF : 0,
          stopByte:   raw.length > 4 ? raw[4] & 0xFF : 0,
          rawBytes:   Uint8List.fromList(raw),
          receivedAt: DateTime.now(),
          direction:  PacketDirection.receive,
        ));
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEND PACKET
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendPacket(List<int> packetBytes, {String? logName}) async {
    if (_writeChar == null) return;

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
  // HANDSHAKE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendHandshake() async {
    final int crc = BMSCrcService.calculateCRC8([0x05, 0x90]);
    final List<int> packet = [0xCC, 0x05, 0x90, crc, 0xDD];

    debugPrint('🤝 HANDSHAKE packet : ${_toHex(packet)}');

    state = BMSConnectionState.handshakeSent;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
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
        List.generate(
          expectedAck.length,
          (i) => receivedAck[i] == expectedAck[i],
        ).every((ok) => ok);

    debugPrint('══════════════════════════════════════════');
    debugPrint('🔐 ACK VALIDATION');
    debugPrint('   Expected : ${_toHex(expectedAck)}');
    debugPrint('   Received : ${_toHex(receivedAck)}');
    debugPrint('   Result   : ${matches ? "✅ MATCH" : "❌ MISMATCH"}');
    debugPrint('══════════════════════════════════════════');

    if (matches) {
      debugPrint('🎉 ACK VALID — Redirecting to Dashboard');
      state = BMSConnectionState.ready;
    } else {
      debugPrint('🚫 ACK INVALID — Connection rejected');
      errorMessage =
          'ACK validation failed — device not authenticated.\n'
          'Expected : ${_toHex(expectedAck)}\n'
          'Received : ${_toHex(receivedAck)}';
      state = BMSConnectionState.error;
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
      final int crc = BMSCrcService.calculateCRC8([0x05, 0x91]);
      final List<int> packet = [0xCC, 0x05, 0x91, crc, 0xDD];
      await _sendPacket(packet, logName: 'DISCONNECT');
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
    final int crc = BMSCrcService.calculateCRC8([0x05, dataId]);
    final List<int> packet = [0xCC, 0x05, dataId, crc, 0xDD];
    await _sendPacket(
      packet,
      logName: 'CUSTOM 0x${dataId.toRadixString(16).toUpperCase()}',
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
    latestPacket4 = null;
    _ackTimer?.cancel();
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
  }

  String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
      .join(' ');
}