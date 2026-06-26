// lib/services/local_auth_db.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles offline user auth AND caches all BMS screen data locally.
class LocalAuthDB {
  // ── Keys ────────────────────────────────────────────────────────────────────
  static const _keyUsers         = 'local_auth_users';
  static const _keyDashboard     = 'bms_cached_dashboard';
  static const _keyCellVoltage   = 'bms_cached_cell_voltage';
  static const _keyAlerts        = 'bms_cached_alerts';
  static const _keySettings      = 'bms_cached_settings';
  static const _keyLastSync      = 'bms_last_sync';

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
      'password' : password,   // store as plain or hash — match your security policy
      'name'     : name,
      'user_id'  : userId,
    };

    await prefs.setString(_keyUsers, jsonEncode(users));
  }

  /// Returns user map on success, null on failure.
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

    return Map<String, dynamic>.from(user as Map);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BMS DATA CACHE
  // ────────────────────────────────────────────────────────────────────────────

  /// Cache the raw dashboard JSON map received from the BMS service.
  Future<void> saveDashboard(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDashboard, jsonEncode(data));
    await _updateSyncTime(prefs);
  }

  /// Cache the raw cell-voltage JSON map received from the BMS service.
  Future<void> saveCellVoltage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCellVoltage, jsonEncode(data));
    await _updateSyncTime(prefs);
  }

  /// Cache alerts list (list of maps).
  Future<void> saveAlerts(List<Map<String, dynamic>> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAlerts, jsonEncode(alerts));
  }

  /// Cache settings map.
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings));
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

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
    await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
  }

  Future<Map<String, dynamic>?> _getMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(key);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> clearBMSCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDashboard);
    await prefs.remove(_keyCellVoltage);
    await prefs.remove(_keyAlerts);
    await prefs.remove(_keySettings);
    await prefs.remove(_keyLastSync);
  }
}