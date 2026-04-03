import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart'; // Für Distanzberechnung nötig

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ghost_ride.db');
    return await openDatabase(
      path,
      version: 2, // Version auf 2 erhöht
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tours(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            date TEXT,
            distance TEXT,   -- NEU: Gesamtdistanz als String (z.B. "5.2 km")
            duration TEXT,   -- NEU: Gesamtdauer als String (z.B. "12:34")
            is_favorite INTEGER DEFAULT 0
          )
        ''');
        
        await db.execute('''
          CREATE TABLE track_points(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tour_id INTEGER,
            lat REAL, lng REAL, alt REAL,
            timestamp TEXT,
            FOREIGN KEY (tour_id) REFERENCES tours (id) ON DELETE CASCADE
          )
        ''');
      },
      // Falls du nicht deinstallieren willst, hilft dieser Block beim Upgrade:
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tours ADD COLUMN distance TEXT');
          await db.execute('ALTER TABLE tours ADD COLUMN duration TEXT');
        }
      },
    );
  }

  // --- SPEICHERN MIT BERECHNUNG ---

  Future<void> saveTour(String name, List<Map<String, dynamic>> points) async {
    if (points.isEmpty) return;

    // 1. Distanz berechnen
    double totalMeters = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalMeters += Geolocator.distanceBetween(
        points[i]['lat'], points[i]['lng'],
        points[i+1]['lat'], points[i+1]['lng']
      );
    }

    // 2. Dauer berechnen
    DateTime start = DateTime.parse(points.first['timestamp']);
    DateTime end = DateTime.parse(points.last['timestamp']);
    Duration diff = end.difference(start);
    
    String durationStr = "${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
    String distanceStr = "${(totalMeters / 1000).toStringAsFixed(2)} km";

    final db = await database;
    await db.transaction((txn) async {
      int tourId = await txn.insert('tours', {
        'name': name,
        'date': DateTime.now().toIso8601String(),
        'distance': distanceStr,
        'duration': durationStr,
        'is_favorite': 0,
      });

      for (var point in points) {
        await txn.insert('track_points', {
          'tour_id': tourId,
          'lat': point['lat'],
          'lng': point['lng'],
          'alt': point['alt'] ?? 0.0,
          'timestamp': point['timestamp'],
        });
      }
    });
  }

  // --- REST BLEIBT GLEICH ---

  Future<List<Map<String, dynamic>>> getAllTours() async {
    final db = await database;
    return await db.query('tours', orderBy: 'is_favorite DESC, id DESC');
  }

  Future<List<Map<String, dynamic>>> getTourPoints(int tourId) async {
    final db = await database;
    return await db.query('track_points', where: 'tour_id = ?', whereArgs: [tourId], orderBy: 'id ASC');
  }

  Future<int> updateFavorite(int id, int status) async {
    final db = await database;
    return await db.update('tours', {'is_favorite': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> renameTour(int id, String newName) async {
    final db = await database;
    return await db.update('tours', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTour(int id) async {
    final db = await database;
    await db.delete('tours', where: 'id = ?', whereArgs: [id]);
  }
}