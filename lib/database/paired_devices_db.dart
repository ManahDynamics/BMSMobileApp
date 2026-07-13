import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class PairedDevice {
  final String deviceId;
  final String name;
  final String? macAddress;
  final DateTime pairedAt;

  PairedDevice({
    required this.deviceId,
    required this.name,
    this.macAddress,
    required this.pairedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'name': name,
      'mac_address': macAddress,
      'paired_at': pairedAt.toIso8601String(),
    };
  }

  factory PairedDevice.fromMap(Map<String, dynamic> map) {
    return PairedDevice(
      deviceId: map['device_id'] as String,
      name: map['name'] as String,
      macAddress: map['mac_address'] as String?,
      pairedAt: DateTime.parse(map['paired_at'] as String),
    );
  }
}

class PairedDevicesDB {
  static const String _tableName = 'paired_devices';
  static const int _dbVersion = 1;
  static const String _dbName = 'paired_devices.db';

  Database? _database;

  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            device_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            mac_address TEXT,
            paired_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<void> insertDevice(PairedDevice device) async {
    final db = await _getDatabase();
    await db.insert(
      _tableName,
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDevice(String deviceId) async {
    final db = await _getDatabase();
    await db.delete(
      _tableName,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<List<PairedDevice>> getAllDevices() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'paired_at DESC',
    );

    return maps.map((map) => PairedDevice.fromMap(map)).toList();
  }

  Future<PairedDevice?> getDevice(String deviceId) async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    if (maps.isEmpty) return null;
    return PairedDevice.fromMap(maps.first);
  }

  Future<bool> isDevicePaired(String deviceId) async {
    final device = await getDevice(deviceId);
    return device != null;
  }

  Future<void> clearAllDevices() async {
    final db = await _getDatabase();
    await db.delete(_tableName);
  }

  Future<void> close() async {
    final db = await _getDatabase();
    await db.close();
    _database = null;
  }
}
