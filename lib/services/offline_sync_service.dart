// lib/services/offline_sync_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_auth_db.dart';

class OfflineSyncService {
  OfflineSyncService({
    LocalAuthDB? localAuthDB,
  }) : _localAuthDB = localAuthDB ?? LocalAuthDB();

  final LocalAuthDB _localAuthDB;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  /// Save data locally and try sync.
  ///
  /// Wrapped in try/catch: if the payload can't be JSON-encoded (e.g. it
  /// contains a DateTime, GeoPoint, or other non-JSON-safe type), this will
  /// throw and you'll see it immediately instead of the row silently never
  /// making it into SQLite.
  Future<void> saveAndQueue(
    String collection,
    Map<String, dynamic> payload,
  ) async {
    print('[Sync] saveAndQueue called for collection=$collection');
    print('[Sync] Payload: $payload');

    try {
      await _localAuthDB.enqueueForSync(collection, payload);
      print('[Sync] Row saved locally in SQLite');
    } catch (e, st) {
      print('[Sync] FAILED to save row locally: $e');
      print(st);
      rethrow;
    }

    final pending = await _localAuthDB.getPendingSyncCount();
    print('[Sync] Pending rows in queue: $pending');

    await _trySyncPending();
  }

  /// Start internet listener.
  Future<void> startListening() async {
    print('[Sync] Starting sync listener');

    await _trySyncPending();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((_) async {
      print('[Sync] Connectivity changed, attempting sync');
      await _trySyncPending();
    });
  }

  /// Sync pending SQLite records to Firestore.
  Future<void> _trySyncPending() async {
    // Prevent overlapping sync passes if connectivity flaps rapidly.
    if (_isSyncing) {
      print('[Sync] Sync already in progress, skipping this trigger');
      return;
    }
    _isSyncing = true;

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasInternet =
          connectivityResult.any((e) => e != ConnectivityResult.none);

      print('[Sync] Internet available: $hasInternet');

      if (!hasInternet) {
        print('[Sync] No internet. Data remains in SQLite');
        return;
      }

      final pendingBefore = await _localAuthDB.getPendingSyncCount();
      print('[Sync] Starting sync. Pending rows: $pendingBefore');

      if (pendingBefore == 0) {
        print('[Sync] Nothing to sync');
        return;
      }

      final syncedCount = await _localAuthDB.syncPendingEntries(
        syncFn: (collection, id, payload) async {
          print('========== SYNC START ==========');
          print('Collection: $collection');
          print('Document ID: $id');
          print('Payload: $payload');

          try {
            await _firestore
                .collection(collection)
                .doc(id.toString())
                .set(payload)
                .timeout(const Duration(seconds: 15));

            print('Firebase upload successful');
          } catch (e) {
            print('Firebase upload failed');
            print(e);
            rethrow;
          } finally {
            print('========== SYNC END ==========');
          }
        },
      );

      final pendingAfter = await _localAuthDB.getPendingSyncCount();
      print(
          '[Sync] Sync pass done. Synced: $syncedCount. Still pending: $pendingAfter');
    } catch (e, st) {
      print('[Sync] Sync process error: $e');
      print(st);
    } finally {
      _isSyncing = false;
    }
  }

  /// Manually trigger a sync attempt (e.g. from a pull-to-refresh or a
  /// debug button) without waiting for a connectivity change event.
  Future<void> syncNow() => _trySyncPending();

  /// Dispose listener.
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}