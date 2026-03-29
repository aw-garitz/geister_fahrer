import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';

class RecordingScreen extends StatefulWidget {
  final int? ghostTourId;
  const RecordingScreen({super.key, this.ghostTourId});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final MapController _mapController = MapController();
  
  List<Map<String, dynamic>> _recordedPoints = [];
  List<LatLng> _polylinePoints = [];
  List<Map<String, dynamic>> _ghostPoints = [];
  List<LatLng> _ghostPolyline = [];
  
  LatLng? _currentPosition;
  LatLng? _ghostPosition;
  LatLng? _targetPosition;

  bool _isRecording = false;
  bool _isCountingDown = true;
  int _countdownSeconds = 5;
  double _targetRadius = 25.0;
  
  bool _goalLocked = true; 
  DateTime? _startTime;
  Timer? _countdownTimer;
  Timer? _ghostTicker; // Separater Timer für flüssige Geist-Bewegung
  StreamSubscription<Position>? _positionStream;
  final Color ghostBlue = const Color(0xFF00B4FF);

  @override
  void initState() {
    super.initState();
    _prepareRace();
  }

  Future<void> _prepareRace() async {
    final prefs = await SharedPreferences.getInstance();
    _countdownSeconds = (prefs.getDouble('countdown') ?? 5.0).toInt();
    _targetRadius = prefs.getDouble('target_radius') ?? 25.0;

    if (widget.ghostTourId != null) {
      final points = await DatabaseHelper().getTourPoints(widget.ghostTourId!);
      if (points.isNotEmpty) {
        _ghostPoints = points;
        _ghostPolyline = points.map((p) => LatLng(p['lat'], p['lng'])).toList();
        _targetPosition = _ghostPolyline.last;
        _ghostPosition = _ghostPolyline.first;
      }
    }
    
    _updateLocation();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        _countdownTimer?.cancel();
        _startTracking();
      }
    });
  }

  Future<void> _updateLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
        _mapController.move(_currentPosition!, 18);
      }
    } catch (e) {
      debugPrint("Warte auf GPS...");
    }
  }

  void _startTracking() {
    setState(() {
      _isCountingDown = false;
      _isRecording = true;
      _startTime = DateTime.now();
      _goalLocked = true;
      _polylinePoints.clear();
      _recordedPoints.clear();
    });

    // GEIST-TICKER: Aktualisiert die Geist-Position 10x pro Sekunde, 
    // völlig unabhängig von deinem GPS-Signal!
    _ghostTicker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording && _startTime != null) {
        _updateGhostMovement(DateTime.now().difference(_startTime!));
      }
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 1)
    ).listen((Position position) {
      LatLng userPos = LatLng(position.latitude, position.longitude);
      final now = DateTime.now();
      final elapsed = now.difference(_startTime!);
      
      _recordedPoints.add({
        'lat': position.latitude,
        'lng': position.longitude,
        'alt': position.altitude,
        'timestamp': now.toIso8601String(),
      });

      // Sperre aufheben (2 Min oder 100m weg)
      if (_goalLocked) {
        double distFromStart = Geolocator.distanceBetween(
          _recordedPoints.first['lat'], _recordedPoints.first['lng'],
          userPos.latitude, userPos.longitude
        );
        if (elapsed.inMinutes >= 2 || distFromStart > 100) {
          setState(() => _goalLocked = false);
        }
      }

      setState(() {
        _currentPosition = userPos;
        _polylinePoints.add(userPos);
        _mapController.move(userPos, 18);

        // Ziel-Check
        if (_targetPosition != null && !_goalLocked) {
          double distToTarget = Geolocator.distanceBetween(
            userPos.latitude, userPos.longitude,
            _targetPosition!.latitude, _targetPosition!.longitude
          );
          if (distToTarget <= _targetRadius) _finishSession(true);
        }
      });
    });
  }

  void _updateGhostMovement(Duration elapsed) {
    if (_ghostPoints.isEmpty) return;
    
    DateTime ghostStart = DateTime.parse(_ghostPoints.first['timestamp']);
    
    // Wir suchen den Punkt in der Liste, der zeitlich am nächsten an 'elapsed' ist
    for (var i = 0; i < _ghostPoints.length; i++) {
      DateTime pTime = DateTime.parse(_ghostPoints[i]['timestamp']);
      if (pTime.difference(ghostStart) >= elapsed) {
        setState(() {
          _ghostPosition = LatLng(_ghostPoints[i]['lat'], _ghostPoints[i]['lng']);
        });
        return; 
      }
    }
    
    // Wenn der Geist am Ende der Liste angekommen ist
    setState(() {
      _ghostPosition = LatLng(_ghostPoints.last['lat'], _ghostPoints.last['lng']);
    });
  }

  void _finishSession(bool reachedGoal) {
    _ghostTicker?.cancel();
    _positionStream?.cancel();
    setState(() => _isRecording = false);
    _showSaveDialog(reachedGoal);
  }

  void _showSaveDialog(bool reachedGoal) {
    TextEditingController nameController = TextEditingController(
      text: "Tour ${DateTime.now().day}.${DateTime.now().month}. ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}"
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(reachedGoal ? "ZIEL ERREICHT!" : "FAHRT BEENDET", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Name zum Speichern",
            labelStyle: TextStyle(color: ghostBlue),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ghostBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context); 
            }, 
            child: const Text("VERWERFEN", style: TextStyle(color: Colors.redAccent))
          ),
          TextButton(
            onPressed: () async {
              if (_recordedPoints.isNotEmpty) {
                await DatabaseHelper().saveTour(nameController.text, _recordedPoints);
              }
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("SPEICHERN", style: TextStyle(color: ghostBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ghostTicker?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(50.11, 8.68),
              initialZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.ghostride.app',
              ),
              if (_ghostPolyline.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _ghostPolyline, strokeWidth: 4, color: Colors.yellow.withOpacity(0.4)),
                ]),
              if (_polylinePoints.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(points: _polylinePoints, strokeWidth: 6, color: Colors.greenAccent),
                ]),
              MarkerLayer(markers: [
                if (_currentPosition != null)
                  Marker(point: _currentPosition!, child: const Icon(Icons.navigation, color: Colors.white, size: 30)),
                if (_targetPosition != null)
                  Marker(point: _targetPosition!, 
                    child: Icon(Icons.flag_circle, 
                      color: _goalLocked ? Colors.white12 : Colors.redAccent, 
                      size: 45
                    )
                  ),
                if (_ghostPosition != null)
                  Marker(point: _ghostPosition!, child: Icon(Icons.bolt, color: ghostBlue, size: 40)),
              ]),
            ],
          ),

          if (_isRecording && _goalLocked)
            Positioned(
              top: 60,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(30)),
                  child: const Text("ZIEL GESPERRT (RUNDKURS)", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),

          if (_isCountingDown)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Text("$_countdownSeconds", style: TextStyle(color: ghostBlue, fontSize: 160, fontWeight: FontWeight.bold)),
              ),
            ),

          if (_isRecording)
            Positioned(
              bottom: 40,
              left: 0, right: 0,
              child: Center(
                child: SizedBox(
                  width: 100, height: 100,
                  child: FloatingActionButton(
                    heroTag: "btn_stop",
                    backgroundColor: Colors.redAccent,
                    shape: const CircleBorder(),
                    onPressed: () => _finishSession(false),
                    child: const Text("STOPP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}