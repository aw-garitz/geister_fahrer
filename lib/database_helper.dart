import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      onCreate: (db, version) async {
        // Tabelle für die Touren (Kopfdaten)
        await db.execute('''
          CREATE TABLE tours(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            date TEXT
          )
        ''');
        // Tabelle für die einzelnen GPS-Punkte
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

  // Methode zum Speichern einer kompletten Fahrt
  Future<void> saveTour(String name, List<Map<String, dynamic>> points) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // 1. Tour erstellen
      int tourId = await txn.insert('tours', {
        'name': name,
        'date': DateTime.now().toIso8601String(),
      });

      // 2. Alle Punkte dieser Tour zuordnen und speichern
      for (var point in points) {
        await txn.insert('track_points', {
          'tour_id': tourId,
          'lat': point['lat'],
          'lng': point['lng'],
          'alt': point['alt'],
          'timestamp': point['timestamp'],
        });
      }
    });
  }
  // Alle Touren auslesen (für die Liste)
  Future<List<Map<String, dynamic>>> getAllTours() async {
    final db = await database;
    // Wir sortieren nach ID absteigend, damit die neueste Tour oben steht
    return await db.query('tours', orderBy: 'id DESC');
  }

  // Eine Tour löschen (inkl. aller zugehörigen Punkte dank ON DELETE CASCADE)
  Future<void> deleteTour(int id) async {
    final db = await database;
    await db.delete('tours', where: 'id = ?', whereArgs: [id]);
  }

  // Alle Punkte einer spezifischen Tour laden (für das Rennen gegen den Geist)
  Future<List<Map<String, dynamic>>> getTourPoints(int tourId) async {
    final db = await database;
    return await db.query('track_points', where: 'tour_id = ?', whereArgs: [tourId]);
  }
}