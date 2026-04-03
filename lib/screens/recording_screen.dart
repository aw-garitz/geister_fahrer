import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../database_helper.dart';

class RecordingScreen extends StatefulWidget {
  final int? ghostTourId;
  const RecordingScreen({super.key, this.ghostTourId});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final MapController _mapController = MapController();
  String _finalResultText = "";
  
  List<Map<String, dynamic>> _recordedPoints = [];
  List<LatLng> _polylinePoints = [];
  double _totalDistance = 0.0;
  
  List<Map<String, dynamic>> _ghostPoints = [];
  List<LatLng> _ghostPolyline = [];
  
  LatLng? _currentPosition;
  LatLng? _ghostPosition;
  LatLng? _targetPosition;
  double _currentHeading = 0.0; 

  double _distanceDiff = 0.0; 
  double _timeDiffSeconds = 0.0;

  bool _isRecording = false;
  bool _isCountingDown = true;
  bool _autoZoomActive = true; 
  
  int _countdownSeconds = 5;
  double _targetRadius = 25.0;
  bool _goalLocked = true; 

  DateTime? _startTime;
  Timer? _countdownTimer;
  Timer? _ghostTicker;
  StreamSubscription<Position>? _positionStream;
  
  final Color ghostNeonBlue = const Color(0xFF00E5FF);
  final Color userNeonGreen = const Color(0xFF00FF00);
  final Color ghostLineYellow = const Color(0xFFFFEA00);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); 
    _prepareRace();
  }

  LatLng _interpolate(LatLng start, LatLng end, double fraction) {
    double lat = start.latitude + (end.latitude - start.latitude) * fraction;
    double lng = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lng);
  }

  void _fitDuelView() {
    if (!_autoZoomActive) return;
    List<LatLng> pointsToShow = [];
    
    // Fokus nur auf User und Geist für maximale Details
    if (_currentPosition != null) pointsToShow.add(_currentPosition!);
    if (_ghostPosition != null) pointsToShow.add(_ghostPosition!);

    if (pointsToShow.length >= 2) {
      final bounds = LatLngBounds.fromPoints(pointsToShow);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 140.0, left: 60.0, right: 60.0, bottom: 120.0),
        ),
      );
    } else if (pointsToShow.length == 1 && _currentPosition != null) {
      _mapController.move(_currentPosition!, 18);
    }
  }

  Future<void> _prepareRace() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    final prefs = await SharedPreferences.getInstance();
    final double savedCountdown = prefs.getDouble('countdown') ?? 5.0;
    
    await _updateLocation();

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
        _isCountingDown = true;
      });
      _startCountdown();
    }
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
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _currentHeading = pos.heading;
        });
        _mapController.move(_currentPosition!, 18);
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
    }
  }

  void _startTracking() {
    if (mounted) {
      setState(() {
        _isRecording = true;
        _isCountingDown = false;
        _startTime = DateTime.now();
        _goalLocked = true;
        _recordedPoints.clear();
        _polylinePoints.clear();
      });
    }

    _ghostTicker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isRecording && _startTime != null) {
        _updateStats();
        _fitDuelView();
      }
    });

    // Foreground Service Konfiguration für Jackentaschen-Modus
    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        intervalDuration: const Duration(milliseconds: 500),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Geister Fahrer trackt deine Fahrt...",
          notificationTitle: "Aufzeichnung läuft",
          enableWakeLock: true,
        ),
      )
    ).listen((Position position) {
      LatLng userPos = LatLng(position.latitude, position.longitude);
      final now = DateTime.now();
      
      if (mounted) {
        setState(() {
          if (_polylinePoints.isNotEmpty) {
            _totalDistance += Geolocator.distanceBetween(
              _polylinePoints.last.latitude, _polylinePoints.last.longitude,
              userPos.latitude, userPos.longitude
            );
          }
          _currentPosition = userPos;
          _polylinePoints.add(userPos);
          _currentHeading = position.heading;
          _recordedPoints.add({
            'lat': position.latitude, 'lng': position.longitude,
            'alt': position.altitude, 'timestamp': now.toIso8601String(),
          });
        });
      }
    });
  }

  void _updateStats() {
    if (_startTime == null || _ghostPoints.isEmpty) return;
    final elapsed = DateTime.now().difference(_startTime!);
    DateTime ghostStart = DateTime.parse(_ghostPoints.first['timestamp']);
    
    int currentIndex = 0;
    for (int i = 0; i < _ghostPoints.length - 1; i++) {
      if (DateTime.parse(_ghostPoints[i+1]['timestamp']).difference(ghostStart) >= elapsed) {
        currentIndex = i;
        break;
      }
    }

    if (mounted) {
      setState(() {
        var p1 = _ghostPoints[currentIndex];
        var p2 = currentIndex + 1 < _ghostPoints.length ? _ghostPoints[currentIndex + 1] : p1;
        
        DateTime t1 = DateTime.parse(p1['timestamp']);
        DateTime t2 = DateTime.parse(p2['timestamp']);
        int segmentDuration = t2.difference(t1).inMilliseconds;

        if (segmentDuration > 0) {
          double fraction = (elapsed.inMilliseconds - t1.difference(ghostStart).inMilliseconds) / segmentDuration;
          _ghostPosition = _interpolate(LatLng(p1['lat'], p1['lng']), LatLng(p2['lat'], p2['lng']), fraction.clamp(0.0, 1.0));
        } else {
          _ghostPosition = LatLng(p1['lat'], p1['lng']);
        }

        if (_currentPosition != null) {
          double dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, _ghostPosition!.latitude, _ghostPosition!.longitude);
          _timeDiffSeconds = (DateTime.parse(p1['timestamp']).difference(ghostStart).inMilliseconds - elapsed.inMilliseconds) / 1000;

          if (_targetPosition != null) {
            double userToTarget = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, _targetPosition!.latitude, _targetPosition!.longitude);
            double ghostToTarget = Geolocator.distanceBetween(_ghostPosition!.latitude, _ghostPosition!.longitude, _targetPosition!.latitude, _targetPosition!.longitude);
            _distanceDiff = (userToTarget > ghostToTarget) ? -dist : dist;
            
            // Ziel-Logik
            if (_recordedPoints.length > 10) _goalLocked = false; 
            if (!_goalLocked && userToTarget <= _targetRadius) _finishSession(true);
          }
        }
      });
    }
  }

  void _finishSession(bool reachedGoal) {
    WakelockPlus.disable();
    _ghostTicker?.cancel();
    _positionStream?.cancel();
    final duration = DateTime.now().difference(_startTime!);
    _finalResultText = "Dauer: ${_formatDuration(duration)}\nDistanz: ${(_totalDistance / 1000).toStringAsFixed(2)} km";
    _showSaveDialog(reachedGoal);
  }

  void _showSaveDialog(bool reachedGoal) {
    TextEditingController nameController = TextEditingController(text: "Tour ${DateTime.now().day}.${DateTime.now().month}.");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(reachedGoal ? "🏆 ZIEL ERREICHT!" : "BEENDET", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_finalResultText, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
            TextField(controller: nameController, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("ZURÜCK")),
          TextButton(onPressed: () async {
            if (_recordedPoints.isNotEmpty) await DatabaseHelper().saveTour(nameController.text, _recordedPoints);
            Navigator.pop(context); Navigator.pop(context);
          }, child: const Text("SPEICHERN")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _countdownTimer?.cancel();
    _ghostTicker?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(50.11, 8.68), 
              initialZoom: 18,
              onPositionChanged: (pos, hasGesture) { if (hasGesture) setState(() => _autoZoomActive = false); },
            ),
            children: [
              TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
              if (_ghostPolyline.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _ghostPolyline, strokeWidth: 6, color: ghostLineYellow)]),
              if (_polylinePoints.length >= 2) PolylineLayer(polylines: [Polyline(points: _polylinePoints, strokeWidth: 7, color: userNeonGreen)]),
              MarkerLayer(markers: [
                if (_currentPosition != null) 
                  Marker(point: _currentPosition!, width: 45, height: 45, child: Transform.rotate(angle: (_currentHeading * (3.14159 / 180)), child: Container(decoration: BoxDecoration(color: userNeonGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Icon(Icons.navigation, size: 30)))),
                if (_ghostPosition != null) 
                  Marker(point: _ghostPosition!, width: 45, height: 45, child: Container(decoration: BoxDecoration(color: ghostNeonBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Center(child: Text("G", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))))),
                if (_targetPosition != null) 
                  Marker(point: _targetPosition!, width: 55, height: 55, child: Icon(Icons.flag_circle, color: _goalLocked ? Colors.white24 : Colors.redAccent, size: 55)),
              ]),
            ],
          ),
          
          // Stats Overlay
          if (_isRecording)
            SafeArea(child: Align(alignment: Alignment.topCenter, child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildStat("ZEIT", _formatDuration(elapsed)),
              _buildStat("DIST +/-", "${_distanceDiff >= 0 ? '+' : ''}${_distanceDiff.toStringAsFixed(0)}m", color: _distanceDiff >= 0 ? Colors.greenAccent : Colors.redAccent),
              _buildStat("TIME +/-", "${_timeDiffSeconds >= 0 ? '+' : ''}${_timeDiffSeconds.toStringAsFixed(1)}s", color: _timeDiffSeconds >= 0 ? Colors.greenAccent : Colors.redAccent),
            ])))),

          // Auto-Zoom Toggle Button
          if (_isRecording)
            Positioned(right: 20, top: 110, child: FloatingActionButton.small(
              backgroundColor: _autoZoomActive ? ghostNeonBlue : Colors.grey[800],
              onPressed: () => setState(() => _autoZoomActive = !_autoZoomActive),
              child: Icon(_autoZoomActive ? Icons.gps_fixed : Icons.gps_not_fixed, color: Colors.black),
            )),

          if (_isCountingDown) Container(color: Colors.black.withOpacity(0.9), child: Center(child: Text("$_countdownSeconds", style: TextStyle(color: ghostNeonBlue, fontSize: 180, fontWeight: FontWeight.bold)))),
          if (_isRecording) Positioned(bottom: 40, left: 0, right: 0, child: Center(child: FloatingActionButton(backgroundColor: Colors.redAccent, onPressed: () => _finishSession(false), child: const Icon(Icons.stop)))),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, {Color color = Colors.white}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    ]);
  }
}