// lib/services/master_data_service.dart
//
// Fetches "master" (factory-default) BMS parameter values, used to
// repopulate the Settings screen after a Factory Data Reset.
//
// TODO(you): wire this up to your actual Firestore schema. The shape below
// is a reasonable default — a single collection ("master_settings") with one
// document per device (or a "default" document for a shared default) — but
// swap in whatever matches your project. The important part for the rest of
// the app is just the *return shape*: a Map<String, dynamic> using the same
// keys the Settings screen already persists locally (see
// SettingsScreen._persistSettings), so no other code needs to change once
// this is implemented.
//
// Expected keys in the returned map (all optional — any missing key simply
// leaves that field unchanged after a reset):
//   Battery:   batteryStringCount, ratedCapacity, socSet, sleepWaitingTime,
//              balancedStartDifferenceVolt, balancedStartVolt,
//              nominalCellVolt, cellChemistry
//   Protection: singleCellHighVoltProtection, singleCellLowVoltProtection,
//              sumVoltHighProtection, sumVoltLowProtection,
//              chargeOverCurrentProtection, dischargeOverCurrentProtection
//   Temp:      noOfTempChannels, chargeHighTempProtection,
//              chargeLowTempProtection, dischargeHighTempProtection,
//              dischargeLowTempProtection, diffTempProtection
//   Factory:   batterySerialNo, bmsSerialNo, bleDeviceName
//
// NOTE: this file intentionally does NOT import cloud_firestore yet, so it
// compiles standalone before you've added the dependency / wired up your
// project. Uncomment the Firestore-backed implementation below once you're
// ready, and remove the stub implementation.

abstract class MasterDataService {
  /// Returns the master/default parameter set to restore after a factory
  /// reset, or null if no master data is available (e.g. offline, no
  /// matching document, or the feature isn't wired up yet).
  ///
  /// [deviceId] can be used to look up a device-specific master record
  /// (e.g. by BMS serial number) — pass null to fall back to a generic
  /// default record if your schema supports one.
  Future<Map<String, dynamic>?> fetchMasterSettings({String? deviceId});

  factory MasterDataService() = _StubMasterDataService;
}

/// Temporary stub — returns null (no master data available) until the
/// Firebase-backed implementation below is wired in.
class _StubMasterDataService implements MasterDataService {
  @override
  Future<Map<String, dynamic>?> fetchMasterSettings({String? deviceId}) async {
    // TODO(you): replace this whole class body with the Firestore
    // implementation once cloud_firestore is set up in this project.
    return null;
  }
}

/* ─────────────────────────────────────────────────────────────────────────
   Firestore-backed implementation (reference).

   1. Add the dependency in pubspec.yaml:
        cloud_firestore: ^5.0.0   // or whatever version matches firebase_core

   2. Uncomment the block below.

   3. Change the `factory MasterDataService() = _StubMasterDataService;`
      line above to:
        factory MasterDataService() = FirebaseMasterDataService;

   4. Adjust the collection/document path and field names to match your
      actual Firestore schema.
   ─────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseMasterDataService implements MasterDataService {
  final FirebaseFirestore _firestore;
  final String collectionPath;
  final String defaultDocId;

  FirebaseMasterDataService({
    FirebaseFirestore? firestore,
    this.collectionPath = 'master_settings',
    this.defaultDocId = 'default',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>?> fetchMasterSettings({String? deviceId}) async {
    final collection = _firestore.collection(collectionPath);

    // Prefer a device-specific master record if one exists.
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      final deviceDoc = await collection.doc(deviceId.trim()).get();
      if (deviceDoc.exists && deviceDoc.data() != null) {
        return _normalize(deviceDoc.data()!);
      }
    }

    // Fall back to a shared default record.
    final defaultDoc = await collection.doc(defaultDocId).get();
    if (defaultDoc.exists && defaultDoc.data() != null) {
      return _normalize(defaultDoc.data()!);
    }

    return null;
  }

  /// Coerces Firestore's dynamic numeric types (int/double/String) into the
  /// types the Settings screen expects, without throwing on unexpected data.
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    double? asDouble(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    int? asInt(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
    String? asString(dynamic v) => v?.toString();

    return {
      if (raw.containsKey('batteryStringCount')) 'batteryStringCount': asInt(raw['batteryStringCount']),
      if (raw.containsKey('ratedCapacity')) 'ratedCapacity': asDouble(raw['ratedCapacity']),
      if (raw.containsKey('socSet')) 'socSet': asInt(raw['socSet']),
      if (raw.containsKey('sleepWaitingTime')) 'sleepWaitingTime': asInt(raw['sleepWaitingTime']),
      if (raw.containsKey('balancedStartDifferenceVolt'))
        'balancedStartDifferenceVolt': asDouble(raw['balancedStartDifferenceVolt']),
      if (raw.containsKey('balancedStartVolt')) 'balancedStartVolt': asDouble(raw['balancedStartVolt']),
      if (raw.containsKey('nominalCellVolt')) 'nominalCellVolt': asDouble(raw['nominalCellVolt']),
      if (raw.containsKey('cellChemistry')) 'cellChemistry': asString(raw['cellChemistry']),
      if (raw.containsKey('singleCellHighVoltProtection'))
        'singleCellHighVoltProtection': asDouble(raw['singleCellHighVoltProtection']),
      if (raw.containsKey('singleCellLowVoltProtection'))
        'singleCellLowVoltProtection': asDouble(raw['singleCellLowVoltProtection']),
      if (raw.containsKey('sumVoltHighProtection')) 'sumVoltHighProtection': asDouble(raw['sumVoltHighProtection']),
      if (raw.containsKey('sumVoltLowProtection')) 'sumVoltLowProtection': asDouble(raw['sumVoltLowProtection']),
      if (raw.containsKey('chargeOverCurrentProtection'))
        'chargeOverCurrentProtection': asDouble(raw['chargeOverCurrentProtection']),
      if (raw.containsKey('dischargeOverCurrentProtection'))
        'dischargeOverCurrentProtection': asDouble(raw['dischargeOverCurrentProtection']),
      if (raw.containsKey('noOfTempChannels')) 'noOfTempChannels': asInt(raw['noOfTempChannels']),
      if (raw.containsKey('chargeHighTempProtection')) 'chargeHighTempProtection': asInt(raw['chargeHighTempProtection']),
      if (raw.containsKey('chargeLowTempProtection')) 'chargeLowTempProtection': asInt(raw['chargeLowTempProtection']),
      if (raw.containsKey('dischargeHighTempProtection'))
        'dischargeHighTempProtection': asInt(raw['dischargeHighTempProtection']),
      if (raw.containsKey('dischargeLowTempProtection'))
        'dischargeLowTempProtection': asInt(raw['dischargeLowTempProtection']),
      if (raw.containsKey('diffTempProtection')) 'diffTempProtection': asInt(raw['diffTempProtection']),
      if (raw.containsKey('batterySerialNo')) 'batterySerialNo': asString(raw['batterySerialNo']),
      if (raw.containsKey('bmsSerialNo')) 'bmsSerialNo': asString(raw['bmsSerialNo']),
      if (raw.containsKey('bleDeviceName')) 'bleDeviceName': asString(raw['bleDeviceName']),
    };
  }
}
*/