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
  double _totalDistance = 0.0;
  
  List<Map<String, dynamic>> _ghostPoints = [];
  List<LatLng> _ghostPolyline = [];
  
  LatLng? _currentPosition;
  LatLng? _ghostPosition;
  LatLng? _targetPosition;

  double _distanceDiff = 0.0; 
  double _timeDiffSeconds = 0.0; // Differenz in Sekunden

  bool _isRecording = false;
  bool _isCountingDown = true;
  int _countdownSeconds = 5;
  double _targetRadius = 25.0;
  bool _goalLocked = true; 

  DateTime? _startTime;
  Timer? _countdownTimer;
  Timer? _ghostTicker;
  StreamSubscription<Position>? _positionStream;
  
  final Color ghostBlue = const Color(0xFF00B4FF);

  @override
  void initState() {
    super.initState();
    _prepareRace();
  }

  Future<void> _prepareRace() async {
    final prefs = await SharedPreferences.getInstance();
    final double savedCountdown = prefs.getDouble('countdown') ?? 5.0;
    
    if (widget.ghostTourId != null) {
      final points = await DatabaseHelper().getTourPoints(widget.ghostTourId!);
      if (points.isNotEmpty) {
        _ghostPoints = points;
        _ghostPolyline = points.map((p) => LatLng(p['lat'], p['lng'])).toList();
        _targetPosition = _ghostPolyline.last;
        _ghostPosition = _ghostPolyline.first;
      }
    }

    if (mounted) {
      setState(() {
        _countdownSeconds = savedCountdown.toInt();
        _targetRadius = prefs.getDouble('target_radius') ?? 25.0;
      });
    }
    
    _updateLocation();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        if (mounted) setState(() => _countdownSeconds--);
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
      debugPrint("GPS...");
    }
  }

  void _startTracking() {
    if (mounted) {
      setState(() {
        _isRecording = true;
        _isCountingDown = false;
        _startTime = DateTime.now();
        _goalLocked = true;
        _totalDistance = 0.0;
        _recordedPoints.clear();
        _polylinePoints.clear();
      });
    }

    _ghostTicker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_isRecording && _startTime != null) {
        _updateStats();
      }
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 1)
    ).listen((Position position) {
      LatLng userPos = LatLng(position.latitude, position.longitude);
      final now = DateTime.now();
      
      if (_polylinePoints.isNotEmpty) {
        _totalDistance += Geolocator.distanceBetween(
          _polylinePoints.last.latitude, _polylinePoints.last.longitude,
          userPos.latitude, userPos.longitude
        );
      }

      _recordedPoints.add({
        'lat': position.latitude, 'lng': position.longitude,
        'alt': position.altitude, 'timestamp': now.toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _currentPosition = userPos;
          _polylinePoints.add(userPos);
          _mapController.move(userPos, 18);

          if (_goalLocked && _recordedPoints.isNotEmpty) {
            double distFromStart = Geolocator.distanceBetween(
              _recordedPoints.first['lat'], _recordedPoints.first['lng'],
              userPos.latitude, userPos.longitude
            );
            if (now.difference(_startTime!).inMinutes >= 2 || distFromStart > 100) {
              _goalLocked = false;
            }
          }

          if (_targetPosition != null && !_goalLocked) {
            double distToTarget = Geolocator.distanceBetween(
              userPos.latitude, userPos.longitude,
              _targetPosition!.latitude, _targetPosition!.longitude
            );
            if (distToTarget <= _targetRadius) _finishSession(true);
          }
        });
      }
    });
  }

  void _updateStats() {
    if (_startTime == null || _ghostPoints.isEmpty) return;
    final elapsed = DateTime.now().difference(_startTime!);
    
    DateTime ghostStart = DateTime.parse(_ghostPoints.first['timestamp']);
    Map<String, dynamic>? currentGhostPoint;
    
    // Aktuelle Position des Geistes finden
    for (var p in _ghostPoints) {
      if (DateTime.parse(p['timestamp']).difference(ghostStart) >= elapsed) {
        currentGhostPoint = p;
        break;
      }
    }
    currentGhostPoint ??= _ghostPoints.last;

    if (mounted) {
      setState(() {
        _ghostPosition = LatLng(currentGhostPoint!['lat'], currentGhostPoint['lng']);
        
        if (_currentPosition != null) {
          // 1. Meter Abstand
          double dist = Geolocator.distanceBetween(
            _currentPosition!.latitude, _currentPosition!.longitude,
            _ghostPosition!.latitude, _ghostPosition!.longitude
          );
          
          // 2. Zeit Abstand (+/- Sekunden)
          // Wir suchen den Punkt in der Ghost-Tour, der uns am nächsten ist
          double minDistance = double.infinity;
          Map<String, dynamic>? closestGhostPoint;

          for (var p in _ghostPoints) {
            double d = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, p['lat'], p['lng']);
            if (d < minDistance) {
              minDistance = d;
              closestGhostPoint = p;
            }
          }

          if (closestGhostPoint != null) {
            DateTime pTime = DateTime.parse(closestGhostPoint['timestamp']);
            Duration ghostElapsedAtThisPoint = pTime.difference(ghostStart);
            _timeDiffSeconds = ghostElapsedAtThisPoint.inMilliseconds / 1000 - elapsed.inMilliseconds / 1000;
          }

          if (_targetPosition != null) {
            double userToTarget = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, _targetPosition!.latitude, _targetPosition!.longitude);
            double ghostToTarget = Geolocator.distanceBetween(_ghostPosition!.latitude, _ghostPosition!.longitude, _targetPosition!.latitude, _targetPosition!.longitude);
            _distanceDiff = (userToTarget > ghostToTarget) ? -dist : dist;
          }
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  void _finishSession(bool reachedGoal) {
    _ghostTicker?.cancel();
    _positionStream?.cancel();
    if (mounted) setState(() => _isRecording = false);
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
        title: Text(reachedGoal ? "ZIEL ERREICHT!" : "FAHRT BEENDET", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(controller: nameController, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("VERWERFEN", style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () async {
            if (_recordedPoints.isNotEmpty) await DatabaseHelper().saveTour(nameController.text, _recordedPoints);
            if (mounted) {
              Navigator.pop(context); Navigator.pop(context);
            }
          }, child: Text("SPEICHERN", style: TextStyle(color: ghostBlue, fontWeight: FontWeight.bold))),
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
    final elapsed = _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
    final bool hasGhost = widget.ghostTourId != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentPosition ?? const LatLng(50.11, 8.68), initialZoom: 18),
            children: [
              TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.ghostride.app'),
              if (hasGhost && _ghostPolyline.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _ghostPolyline, strokeWidth: 3, color: Colors.yellow.withOpacity(0.3))]),
              if (_polylinePoints.length >= 2) PolylineLayer(polylines: [Polyline(points: _polylinePoints, strokeWidth: 5, color: Colors.greenAccent)]),
              MarkerLayer(markers: [
                if (_currentPosition != null) Marker(point: _currentPosition!, child: const Icon(Icons.navigation, color: Colors.white, size: 30)),
                if (hasGhost && _targetPosition != null) Marker(point: _targetPosition!, child: Icon(Icons.flag_circle, color: _goalLocked ? Colors.white10 : Colors.redAccent, size: 45)),
                if (hasGhost && _ghostPosition != null) Marker(point: _ghostPosition!, child: Icon(Icons.bolt, color: ghostBlue, size: 40)),
              ]),
            ],
          ),

          // DATEN PANEL (Oben fixiert, überdeckt NICHT die ganze Karte)
          if (_isRecording)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn("ZEIT", _formatDuration(elapsed)),
                        _buildStatColumn("STRECKE", "${(_totalDistance / 1000).toStringAsFixed(2)} km"),
                        if (hasGhost) ...[
                          _buildStatColumn("TIME +/-", "${_timeDiffSeconds >= 0 ? '+' : ''}${_timeDiffSeconds.toStringAsFixed(1)}s", 
                            color: _timeDiffSeconds >= 0 ? Colors.greenAccent : Colors.redAccent),
                          _buildStatColumn("DIST +/-", "${_distanceDiff >= 0 ? '+' : ''}${_distanceDiff.toStringAsFixed(0)}m", 
                            color: _distanceDiff >= 0 ? Colors.greenAccent : Colors.redAccent),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_isCountingDown)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(child: Text("$_countdownSeconds", style: TextStyle(color: ghostBlue, fontSize: 180, fontWeight: FontWeight.bold))),
            ),

          if (_isRecording)
            Positioned(bottom: 40, left: 0, right: 0, child: Center(
              child: SizedBox(
                width: 80, height: 80,
                child: FloatingActionButton(
                  heroTag: "btn_stop_final",
                  backgroundColor: Colors.redAccent, 
                  shape: const CircleBorder(), 
                  onPressed: () => _finishSession(false), 
                  child: const Icon(Icons.stop, color: Colors.white, size: 40),
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min, // WICHTIG: Begrenzt die Höhe
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }
}