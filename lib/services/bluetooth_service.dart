// lib/services/bluetooth_service.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:bmsmobileapp/services/parsed_packet.dart';
import 'package:bmsmobileapp/services/packet_parser.dart';
import 'package:bmsmobileapp/services/crc_service.dart';
import 'package:bmsmobileapp/services/packet_formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Connection states
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// BMSBluetoothService
// ─────────────────────────────────────────────────────────────────────────────
class BMSBluetoothService extends ChangeNotifier {

  // ── Public state ───────────────────────────────────────────────────────────
  BluetoothDevice?   device;
  BMSConnectionState state        = BMSConnectionState.disconnected;
  String?            errorMessage;
  bool               isConnecting = false;

  /// Every sent / received packet, newest first.
  final List<BMSParsedPacket> packetLog = [];

  // ── Private ────────────────────────────────────────────────────────────────
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription?      _notifySub;
  Timer?                   _ackTimer;
  int                      _sessionId = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // CONNECT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> connect(BluetoothDevice d) async {
    _newSession();

    debugPrint('══════════════════════════════');
    debugPrint('🚀 SESSION $_sessionId — connect to ${d.remoteId.str}');

    try {
      isConnecting = true;
      state        = BMSConnectionState.connecting;
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
      state        = BMSConnectionState.error;
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

    // ── Print ALL services and characteristics so you can identify UUIDs ──
    debugPrint('────────────────────────────────────');
    debugPrint('📋 ALL CHARACTERISTICS ON THIS DEVICE:');
    for (final s in services) {
      debugPrint('  SERVICE: ${s.uuid}');
      for (final c in s.characteristics) {
        debugPrint('    CHAR : ${c.uuid}');
        debugPrint('           write            = ${c.properties.write}');
        debugPrint('           writeWithoutResp = ${c.properties.writeWithoutResponse}');
        debugPrint('           notify           = ${c.properties.notify}');
        debugPrint('           read             = ${c.properties.read}');
      }
    }
    debugPrint('────────────────────────────────────');

    // ── Pick best write characteristic ────────────────────────────────────
    // Prefer write-with-response; fall back to write-without-response.
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.notify) {
          _notifyChar = c;
          debugPrint('✔ NOTIFY CHAR : ${c.uuid}');
        }
        // Prefer write WITH response (more reliable)
        if (c.properties.write && _writeChar == null) {
          _writeChar = c;
          debugPrint('✔ WRITE CHAR (with-response) : ${c.uuid}');
        }
      }
    }

    // If no write-with-response found, fall back to write-without-response
    if (_writeChar == null) {
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.writeWithoutResponse) {
            _writeChar = c;
            debugPrint('✔ WRITE CHAR (no-response fallback) : ${c.uuid}');
            break;
          }
        }
        if (_writeChar != null) break;
      }
    }

    if (_notifyChar == null || _writeChar == null) {
      throw Exception(
        'Required BLE characteristics not found.\n'
        'This does not appear to be a BMS device.\n'
        'Check logcat for the list of available characteristics.',
      );
    }

    await _startListening();

    state = BMSConnectionState.connected;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RX LISTENER
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    debugPrint('📡 SUBSCRIBING TO NOTIFICATIONS…');

    await _notifyChar!.setNotifyValue(true);

    _notifySub = _notifyChar!.value.listen((raw) {
      if (raw.isEmpty) return;

      final hex = _toHex(raw);
      debugPrint('──────────────────────────────');
      debugPrint('📥 RX  HEX : $hex');

      final result = BMSPacketParser.parse(Uint8List.fromList(raw));

      if (result.isSuccess) {
        final packet = result.packet!;

        packetLog.insert(0, packet);

        debugPrint('✅ PARSED   : ${packet.typeName}');
        debugPrint('   Direction: ${packet.direction}');
        debugPrint('   Data ID  : 0x${packet.dataId.toRadixString(16).toUpperCase().padLeft(2,'0')}');
        debugPrint('   CRC-8    : 0x${packet.crc.toRadixString(16).toUpperCase().padLeft(2,'0')}');

        if (state == BMSConnectionState.waitingAck && packet.isAck) {
          debugPrint('🎯 ACK MATCHED → handshake accepted');
          _onAckReceived();
        }
      } else {
        debugPrint('❌ PARSE FAIL: ${result.error}');
        debugPrint('   Reason   : ${BMSPacketFormatter.errorMessage(result.error!)}');
      }

      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HANDSHAKE  (Mobile → BMS)
  //   Packet: AA  05  90  <crc8 of [AA,05,90]>  BB
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendHandshake() async {
    if (_writeChar == null) return;

    final List<int> header = [0xAA, 0x05, 0x90];
    final int       crc    = BMSCrcService.calculateCRC8(header);
    final List<int> packet = [...header, crc, 0xBB];

    debugPrint('══════════════════════════════');
    debugPrint('📤 HANDSHAKE TX : ${_toHex(packet)}');
    debugPrint('   CRC-8        : 0x${crc.toRadixString(16).toUpperCase().padLeft(2,'0')}');

    // Log the sent packet
    final parsed = BMSPacketParser.parse(packet);
    if (parsed.isSuccess) packetLog.insert(0, parsed.packet!);

    state = BMSConnectionState.handshakeSent;
    notifyListeners();

    // ── FIX: auto-detect write mode ───────────────────────────────────────
    // Use write-with-response when supported; otherwise use without-response.
    final bool useWithResponse = _writeChar!.properties.write;
    debugPrint('   writeWithResponse = $useWithResponse');

    await _writeChar!.write(packet, withoutResponse: !useWithResponse);

    state = BMSConnectionState.waitingAck;
    notifyListeners();

    debugPrint('📡 WAITING FOR ACK…');

    // Timeout guard
    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(seconds: 5), () {
      if (state == BMSConnectionState.waitingAck) {
        debugPrint('⏰ ACK TIMEOUT');
        errorMessage = 'Handshake timeout — no response from device';
        state        = BMSConnectionState.error;
        isConnecting = false;
        notifyListeners();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACK HANDLER
  // ─────────────────────────────────────────────────────────────────────────
  void _onAckReceived() {
    _ackTimer?.cancel();
    debugPrint('🎉 DEVICE READY');
    state        = BMSConnectionState.ready;
    isConnecting = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISCONNECT  (Mobile → BMS)
  //   Packet: AA  05  91  <crc8 of [AA,05,91]>  BB
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    debugPrint('🔌 DISCONNECT');

    state = BMSConnectionState.disconnecting;
    notifyListeners();

    _ackTimer?.cancel();

    if (_writeChar != null) {
      try {
        final List<int> header = [0xAA, 0x05, 0x91];
        final int       crc    = BMSCrcService.calculateCRC8(header);
        final List<int> packet = [...header, crc, 0xBB];

        final bool useWithResponse = _writeChar!.properties.write;
        debugPrint('📤 DISCONNECT TX: ${_toHex(packet)}');
        await _writeChar!.write(packet, withoutResponse: !useWithResponse);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {}
    }

    await _notifySub?.cancel();
    await device?.disconnect();

    _notifyChar  = null;
    _writeChar   = null;
    _notifySub   = null;
    device       = null;
    isConnecting = false;
    state        = BMSConnectionState.disconnected;

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CUSTOM PACKET SEND
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> sendCustom(int dataId) async {
    if (_writeChar == null) return;

    final List<int> header = [0xAA, 0x05, dataId];
    final int       crc    = BMSCrcService.calculateCRC8(header);
    final List<int> packet = [...header, crc, 0xBB];

    final bool useWithResponse = _writeChar!.properties.write;
    debugPrint('📤 CUSTOM TX: ${_toHex(packet)}');
    await _writeChar!.write(packet, withoutResponse: !useWithResponse);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  void _newSession() {
    _sessionId++;
    packetLog.clear();
    _ackTimer?.cancel();
  }

  String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
      .join(' ');
}