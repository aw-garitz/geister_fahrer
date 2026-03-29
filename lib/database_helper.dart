import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 1,
      // Aktiviert Foreign Keys für ON DELETE CASCADE
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        // Haupttabelle für Touren
        await db.execute('''
          CREATE TABLE tours(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            date TEXT,
            is_favorite INTEGER DEFAULT 0
          )
        ''');
        
        // Tabelle für GPS-Punkte
        await db.execute('''
          CREATE TABLE track_points(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tour_id INTEGER,
            lat REAL,
            lng REAL,
            alt REAL,
            timestamp TEXT,
            FOREIGN KEY (tour_id) REFERENCES tours (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // --- SPEICHERN ---

  Future<void> saveTour(String name, List<Map<String, dynamic>> points) async {
    final db = await database;
    await db.transaction((txn) async {
      int tourId = await txn.insert('tours', {
        'name': name,
        'date': DateTime.now().toIso8601String(),
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

  // --- LESEN ---

  Future<List<Map<String, dynamic>>> getAllTours() async {
    final db = await database;
    // Wir holen alle Daten unsortiert, die Sortierung (Favs oben) 
    // erledigt der GhostSelectionScreen dynamisch.
    return await db.query('tours');
  }

  Future<List<Map<String, dynamic>>> getTourPoints(int tourId) async {
    final db = await database;
    return await db.query('track_points', 
      where: 'tour_id = ?', 
      whereArgs: [tourId], 
      orderBy: 'id ASC'
    );
  }

  // --- UPDATES (Wichtig für deine Fehler-Fixes) ---

  // Favoriten-Status umschalten (0 oder 1)
  Future<int> updateFavorite(int id, int status) async {
    final db = await database;
    return await db.update(
      'tours',
      {'is_favorite': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tour umbenennen
  Future<int> renameTour(int id, String newName) async {
    final db = await database;
    return await db.update(
      'tours',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- LÖSCHEN ---

  Future<void> deleteTour(int id) async {
    final db = await database;
    // Dank ON DELETE CASCADE in onCreate werden track_points automatisch mitgelöscht
    await db.delete('tours', where: 'id = ?', whereArgs: [id]);
  }
}