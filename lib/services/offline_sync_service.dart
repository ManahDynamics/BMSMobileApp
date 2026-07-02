import 'dart:async';

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

    print("Saving to SQLite...");
    print("Collection: $collection");
    print("Payload: $payload");

    await _localAuthDB.enqueueForSync(
      collection,
      payload,
    );

    print("Saved locally");

    await _trySyncPending();
  }

  /// Start internet listener
  Future<void> startListening() async {

    print("Starting sync listener");

    await _trySyncPending();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(
      (_) async {

        print("Connectivity changed");

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

      if (connectivity is List<ConnectivityResult>) {
        hasInternet = connectivity.any(
          (e) => e != ConnectivityResult.none,
        );
      } else {
        hasInternet =
            connectivity != ConnectivityResult.none;
      }

      print(
          "Internet available: $hasInternet");

      if (!hasInternet) {
        print(
            "No internet. Data remains in SQLite");
        return;
      }

      print(
          "Internet available. Starting sync...");

      await _localAuthDB.syncPendingEntries(
        syncFn:
            (collection, id, payload) async {

          try {

            print(
                "========== SYNC START ==========");
            print(
                "Collection: $collection");
            print(
                "Document ID: $id");
            print(
                "Payload: $payload");

            await _firestore
                .collection(collection)
                .doc(id.toString())
                .set(payload);

            print(
                "Firebase upload successful");

            print(
                "========== SYNC END ==========");

          } catch (e) {

            print(
                "Firebase upload failed");
            print(e);

            rethrow;
          }
        },
      );

    } catch (e) {

      print("Sync process error");
      print(e);
    }
  }

  /// Dispose listener
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}