// lib/services/local_auth_db.dart
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

class LocalAuthDB {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'local_auth.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            name TEXT,
            user_id TEXT,
            last_sync TEXT
          )
        ''');
      },
    );
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> saveUser({
    required String email,
    required String password,
    String? name,
    String? userId,
  }) async {
    final db = await database;
    final hash = _hashPassword(password);

    await db.insert(
      'users',
      {
        'email': email.toLowerCase().trim(),
        'password_hash': hash,
        'name': name,
        'user_id': userId,
        'last_sync': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> loginOffline(String email, String password) async {
    final db = await database;
    final hash = _hashPassword(password);

    final result = await db.query(
      'users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email.toLowerCase().trim(), hash],
    );

    return result.isNotEmpty ? result.first : null;
  }
}