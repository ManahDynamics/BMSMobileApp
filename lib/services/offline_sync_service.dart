import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_auth_db.dart';

class OfflineSyncService {
  OfflineSyncService({
    LocalAuthDB? localAuthDB,
  }) : _localAuthDB = localAuthDB ?? LocalAuthDB();

  final LocalAuthDB _localAuthDB;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final Connectivity _connectivity =
      Connectivity();

  StreamSubscription? _connectivitySubscription;

  /// Save data locally and try sync
  Future<void> saveAndQueue(
    String collection,
    Map<String, dynamic> payload,
  ) async {

    debugPrint("Saving to SQLite...");
    debugPrint("Collection: $collection");
    debugPrint("Payload: $payload");

    await _localAuthDB.enqueueForSync(
      collection,
      payload,
    );

    debugPrint("Saved locally");

    await _trySyncPending();
  }

  /// Start internet listener
  Future<void> startListening() async {

    debugPrint("Starting sync listener");

    await _trySyncPending();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(
      (_) async {

        debugPrint("Connectivity changed");

        await _trySyncPending();
      },
    );
  }

  /// Sync pending SQLite records
  Future<void> _trySyncPending() async {

    try {

      final connectivity =
          await _connectivity.checkConnectivity();

      bool hasInternet = false;

      hasInternet = connectivity.any(
        (e) => e != ConnectivityResult.none,
      );
    
      debugPrint(
          "Internet available: $hasInternet");

      if (!hasInternet) {
        debugPrint(
            "No internet. Data remains in SQLite");
        return;
      }

      debugPrint(
          "Internet available. Starting sync...");

      await _localAuthDB.syncPendingEntries(
        syncFn:
            (collection, id, payload) async {

          try {

            debugPrint(
                "========== SYNC START ==========");
            debugPrint(
                "Collection: $collection");
            debugPrint(
                "Document ID: $id");
            debugPrint(
                "Payload: $payload");

            await _firestore
                .collection(collection)
                .doc(id.toString())
                .set(payload);

            debugPrint(
                "Firebase upload successful");

            debugPrint(
                "========== SYNC END ==========");

          } catch (e) {

            debugPrint(
                "Firebase upload failed");
            debugPrint(e.toString());

            rethrow;
          }
        },
      );

    } catch (e) {

      debugPrint("Sync process error");
      debugPrint(e.toString());
    }
  }

  /// Dispose listener
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}