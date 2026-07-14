// lib/services/local_auth_db.dart
import 'dart:convert';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

typedef SyncEntryHandler = Future<void> Function(
  String collection,
  String id,
  Map<String, dynamic> payload,
);

/// Handles offline user auth AND caches all BMS screen data locally.
class LocalAuthDB {
  LocalAuthDB({DatabaseFactory? databaseFactory}) : _databaseFactory = databaseFactory;

  final DatabaseFactory? _databaseFactory;
  Database? _database;

  // ── Keys ────────────────────────────────────────────────────────────────────
  static const _keyUsers         = 'local_auth_users';
  static const _keyDashboard     = 'bms_cached_dashboard';
  static const _keyCellVoltage   = 'bms_cached_cell_voltage';
  static const _keyAlerts        = 'bms_cached_alerts';
  static const _keySettings      = 'bms_cached_settings';
  static const _keyLastSync      = 'bms_last_sync';
  static const _keyDeviceName    = 'bms_cached_device_name';
  static const _keyCurrentUserId = 'bms_current_user_id'; // NEW
  static const _cacheTableName = 'cache_entries';
  static const _syncTableName = 'pending_sync_entries';

  // ────────────────────────────────────────────────────────────────────────────
  // AUTH
  // ────────────────────────────────────────────────────────────────────────────

  /// Save / update a user for offline login (stores hashed password).
  Future<void> saveUser({
    required String email,
    required String password,
    required String name,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_keyUsers);
    final users = raw != null
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : <String, dynamic>{};

    users[email.toLowerCase()] = {
      'password' : password,
      'name'     : name,
      'user_id'  : userId,
    };

    await prefs.setString(_keyUsers, jsonEncode(users));
  }

  /// Returns user map on success, null on failure.
  /// Also remembers this user as the "current user" so BMS cache saves
  /// (dashboard, cell voltage, alerts, settings, device name) can
  /// automatically stamp their synced payloads with the right user_id
  /// without you having to pass it in every single call.
  Future<Map<String, dynamic>?> loginOffline(
      String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_keyUsers);
    if (raw == null) return null;

    final users = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final user  = users[email.toLowerCase()];
    if (user == null) return null;

    final stored = user['password'] as String?;
    if (stored == null || stored != password) return null;

    final userMap = Map<String, dynamic>.from(user as Map);

    final userId = userMap['user_id'] as String?;
    if (userId != null) {
      await setCurrentUserId(userId);
    }

    return userMap;
  }

  /// Manually set which user_id should be stamped on synced BMS payloads.
  /// Call this after any successful login (offline or online).
  Future<void> setCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUserId, userId);
  }

  /// The currently "logged in" user_id, used as a fallback whenever a BMS
  /// cache save method isn't explicitly given a userId.
  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentUserId);
  }

  /// Clears the remembered current user (call this on logout).
  Future<void> clearCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUserId);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BMS DATA CACHE
  // ────────────────────────────────────────────────────────────────────────────

  /// Cache the device name locally AND queue it for sync to Firestore.
  /// [userId]: if omitted, falls back to the current logged-in user set by
  /// [loginOffline] / [setCurrentUserId].
  Future<void> saveDeviceName(String name, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceName, name);
    await _updateSyncTime(prefs);

    final resolvedUserId = userId ?? await getCurrentUserId();
    final now = DateTime.now().toUtc().toIso8601String();

    await enqueueForSync(
      'paired_device_summary',
      {
        'device_name': name,
        'user_id': resolvedUserId,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  /// Cache the raw dashboard JSON map received from the BMS service, AND
  /// queue it for sync to Firestore.
  /// [userId]: if omitted, falls back to the current logged-in user set by
  /// [loginOffline] / [setCurrentUserId].
  Future<void> saveDashboard(Map<String, dynamic> data, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDashboard, jsonEncode(data));
    await _updateSyncTime(prefs);

    final resolvedUserId = userId ?? await getCurrentUserId();
    final now = DateTime.now().toUtc().toIso8601String();

    await enqueueForSync(
      'dashboard_summary',
      {
        ...data,
        'user_id': resolvedUserId,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  /// Cache the raw cell-voltage JSON map received from the BMS service, AND
  /// queue it for sync to Firestore.
  /// [userId]: if omitted, falls back to the current logged-in user set by
  /// [loginOffline] / [setCurrentUserId].
  Future<void> saveCellVoltage(Map<String, dynamic> data, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCellVoltage, jsonEncode(data));
    await _updateSyncTime(prefs);

    final resolvedUserId = userId ?? await getCurrentUserId();
    final now = DateTime.now().toUtc().toIso8601String();

    await enqueueForSync(
      'cell_voltage_summary',
      {
        ...data,
        'user_id': resolvedUserId,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  /// Cache alerts list (list of maps) locally, AND queue it for sync to
  /// Firestore (Firestore doesn't store a bare array as a document, so it's
  /// wrapped under 'alerts').
  /// [userId]: if omitted, falls back to the current logged-in user set by
  /// [loginOffline] / [setCurrentUserId].
  Future<void> saveAlerts(List<Map<String, dynamic>> alerts, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAlerts, jsonEncode(alerts));

    final resolvedUserId = userId ?? await getCurrentUserId();
    final now = DateTime.now().toUtc().toIso8601String();

    await enqueueForSync(
      'alerts_summary',
      {
        'alerts': alerts,
        'user_id': resolvedUserId,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  /// Cache settings map locally, AND queue it for sync to Firestore.
  /// [userId]: if omitted, falls back to the current logged-in user set by
  /// [loginOffline] / [setCurrentUserId].
  Future<void> saveSettings(Map<String, dynamic> settings, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings));

    final resolvedUserId = userId ?? await getCurrentUserId();
    final now = DateTime.now().toUtc().toIso8601String();

    await enqueueForSync(
      'settings_summary',
      {
        ...settings,
        'user_id': resolvedUserId,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  /// Enqueue a payload for later sync to Firestore.
  ///
  /// [docId]: if provided, this exact document ID is used - repeated calls
  /// with the same [collection] + [docId] will overwrite the same Firestore
  /// document (good for "current state" data like a dashboard snapshot).
  /// If omitted (the current default for all BMS cache saves above), a
  /// unique timestamp-based ID is generated instead - each save creates a
  /// NEW Firestore document, giving you a full history/log of every synced
  /// snapshot rather than a single overwritten "latest" doc.
  ///
  /// Uses an atomic upsert (INSERT ... ON CONFLICT REPLACE) rather than a
  /// separate delete-then-insert, so rapid concurrent calls with the same
  /// docId never race against each other and throw a UNIQUE constraint /
  /// primary key error.
  ///
  /// NOTE: this is not wrapped in try/catch here on purpose - if the payload
  /// contains something jsonEncode can't serialize (DateTime, custom class,
  /// etc.) you want that exception to surface immediately at the call site
  /// rather than silently disappearing. Wrap the *call* to this method in
  /// try/catch in OfflineSyncService instead.
  Future<void> enqueueForSync(
    String collection,
    Map<String, dynamic> payload, {
    String? docId,
  }) async {
    final db = await _getDatabase();
    final id = docId ?? DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    // row_key is scoped per-collection so the same doc_id used across
    // different collections never collides on the primary key.
    final rowKey = '$collection::$id';

    final encodedPayload = jsonEncode(payload);

    await db.insert(
      _syncTableName,
      {
        'row_key': rowKey,
        'collection': collection,
        'doc_id': id,
        'payload': encodedPayload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // ignore: avoid_print
    print('[LocalAuthDB] Enqueued row_key=$rowKey collection=$collection doc_id=$id');
  }

  Future<int> getPendingSyncCount() async {
    final db = await _getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_syncTableName WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns all pending rows (for debugging / inspection).
  Future<List<Map<String, dynamic>>> getPendingSyncRows() async {
    final db = await _getDatabase();
    return db.query(
      _syncTableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  /// Syncs all pending entries. A row that fails is SKIPPED (not blocking),
  /// so one bad/poisoned row can no longer jam the entire queue forever.
  /// Failed rows stay `pending` and will be retried on the next sync pass.
  Future<int> syncPendingEntries({required SyncEntryHandler syncFn}) async {
    final db = await _getDatabase();
    final rows = await db.query(
      _syncTableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );

    var synced = 0;
    var failed = 0;

    for (final row in rows) {
      final rowKey = row['row_key'] as String;
      final docId = row['doc_id'] as String;
      final collection = row['collection'] as String;
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

      try {
        await syncFn(collection, docId, payload);
        await db.delete(_syncTableName, where: 'row_key = ?', whereArgs: [rowKey]);
        synced += 1;
      } catch (e, st) {
        // IMPORTANT: continue instead of break - a single failing row
        // (bad payload, transient network blip, etc.) must not prevent
        // every other queued row from syncing.
        failed += 1;
        // ignore: avoid_print
        print('[LocalAuthDB] Sync FAILED for row_key=$rowKey collection=$collection: $e');
        // ignore: avoid_print
        print(st);
        continue;
      }
    }

    // ignore: avoid_print
    print('[LocalAuthDB] Sync pass complete. synced=$synced failed=$failed');

    if (synced > 0) {
      final prefs = await SharedPreferences.getInstance();
      await _updateSyncTime(prefs);
    }

    return synced;
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  Future<String?> getCachedDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceName);
  }

  Future<Map<String, dynamic>?> getCachedDashboard() async {
    return _getMap(_keyDashboard);
  }

  Future<Map<String, dynamic>?> getCachedCellVoltage() async {
    return _getMap(_keyCellVoltage);
  }

  Future<List<Map<String, dynamic>>?> getCachedAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_keyAlerts);
    if (raw == null) return null;
    final list  = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> getCachedSettings() async {
    return _getMap(_keySettings);
  }

  /// True if at least dashboard data is cached.
  Future<bool> hasBMSCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyDashboard);
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final s     = prefs.getString(_keyLastSync);
    return s != null ? DateTime.tryParse(s) : null;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _updateSyncTime(SharedPreferences prefs) async {
    await prefs.setString(_keyLastSync, DateTime.now().toUtc().toIso8601String());
  }

  Future<Map<String, dynamic>?> _getMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(key);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final factory = _databaseFactory ?? databaseFactory;
    final databasesPath = await factory.getDatabasesPath();
    final path = join(databasesPath, 'local_auth_cache.db');

    Future<void> ensureSchema(Database db) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_cacheTableName (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          stored_at TEXT NOT NULL
        )
      ''');
      // row_key is the actual SQLite primary key and is derived from
      // "$collection::$docId" - this keeps rows unique PER COLLECTION.
      // doc_id is the plain ID used as the actual Firestore document ID.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_syncTableName (
          row_key TEXT PRIMARY KEY,
          collection TEXT NOT NULL,
          doc_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          status TEXT NOT NULL
        )
      ''');
    }

    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await ensureSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('DROP TABLE IF EXISTS $_syncTableName');
          }
          await ensureSchema(db);
        },
        onOpen: (db) async {
          await ensureSchema(db);
        },
      ),
    );

    return _database!;
  }

  Future<void> clearBMSCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDashboard);
    await prefs.remove(_keyCellVoltage);
    await prefs.remove(_keyAlerts);
    await prefs.remove(_keySettings);
    await prefs.remove(_keyLastSync);
    await prefs.remove(_keyDeviceName);

    final db = await _getDatabase();
    await db.delete(_cacheTableName);
    await db.delete(_syncTableName);
  }

  /// Clears only the pending sync queue (useful for debugging a jammed queue).
  Future<void> clearPendingSyncQueue() async {
    final db = await _getDatabase();
    await db.delete(_syncTableName);
  }
}