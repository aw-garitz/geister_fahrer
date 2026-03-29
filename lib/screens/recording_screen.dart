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
  
  List<Map<String, dynamic>> _recordedPoints = [];
  List<LatLng> _polylinePoints = [];
  double _totalDistance = 0.0;
  
  List<Map<String, dynamic>> _ghostPoints = [];
  List<LatLng> _ghostPolyline = [];
  
  LatLng? _currentPosition;
  LatLng? _ghostPosition;
  LatLng? _targetPosition;
  double _currentHeading = 0.0; // NEU: Blickrichtung

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
  
  // Kontraststarke Neon-Farben
  final Color ghostNeonBlue = const Color(0xFF00E5FF);
  final Color userNeonGreen = const Color(0xFF00FF00);
  final Color ghostLineYellow = const Color(0xFFFFEA00);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); 
    _prepareRace();
  }

  void _fitAllPoints() {
    List<LatLng> pointsToShow = [];
    if (_currentPosition != null) pointsToShow.add(_currentPosition!);
    if (_ghostPosition != null) pointsToShow.add(_ghostPosition!);
    if (_targetPosition != null) pointsToShow.add(_targetPosition!);

    if (pointsToShow.length >= 2) {
      final bounds = LatLngBounds.fromPoints(pointsToShow);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(70.0),
        ),
      );
    }
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
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _currentHeading = pos.heading;
        });
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
        if (_autoZoomActive) _fitAllPoints();
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
          _currentHeading = position.heading;

          if (!_autoZoomActive) {
            _mapController.move(userPos, _mapController.camera.zoom);
          }

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
          double dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, _ghostPosition!.latitude, _ghostPosition!.longitude);
          
          double minDistance = double.infinity;
          Map<String, dynamic>? closestGhostPoint;
          for (var p in _ghostPoints) {
            double d = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, p['lat'], p['lng']);
            if (d < minDistance) { minDistance = d; closestGhostPoint = p; }
          }
          if (closestGhostPoint != null) {
            DateTime pTime = DateTime.parse(closestGhostPoint['timestamp']);
            _timeDiffSeconds = pTime.difference(ghostStart).inMilliseconds / 1000 - elapsed.inMilliseconds / 1000;
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

  void _finishSession(bool reachedGoal) {
    WakelockPlus.disable();
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
        title: Text(reachedGoal ? "ZIEL ERREICHT!" : "FAHRT BEENDET", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(controller: nameController, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("VERWERFEN", style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () async {
            if (_recordedPoints.isNotEmpty) await DatabaseHelper().saveTour(nameController.text, _recordedPoints);
            Navigator.pop(context); Navigator.pop(context);
          }, child: Text("SPEICHERN", style: TextStyle(color: ghostNeonBlue, fontWeight: FontWeight.bold))),
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

  // --- HILFSFUNKTIONEN ---

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Widget _buildStatColumn(String label, String value, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
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
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(50.11, 8.68), 
              initialZoom: 18,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _autoZoomActive) {
                  setState(() => _autoZoomActive = false); 
                }
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.ghostride.app'),
              
              if (hasGhost && _ghostPolyline.isNotEmpty) ...[
                PolylineLayer(polylines: [
                  Polyline(points: _ghostPolyline, strokeWidth: 10, color: Colors.black.withOpacity(0.5)),
                  Polyline(points: _ghostPolyline, strokeWidth: 6, color: ghostLineYellow),
                ]),
              ],
              
              if (_polylinePoints.length >= 2) 
                PolylineLayer(polylines: [
                  Polyline(points: _polylinePoints, strokeWidth: 7, color: userNeonGreen)
                ]),

              MarkerLayer(markers: [
                if (_currentPosition != null) 
                  Marker(
                    point: _currentPosition!, 
                    width: 45, height: 45,
                    child: Transform.rotate(
                      angle: (_currentHeading * (3.14159 / 180)),
                      child: Container(
                        decoration: BoxDecoration(color: userNeonGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                        child: const Icon(Icons.navigation, color: Colors.black87, size: 30),
                      ),
                    ),
                  ),
                if (hasGhost && _ghostPosition != null) 
                  Marker(
                    point: _ghostPosition!, 
                    width: 45, height: 45,
                    child: Container(
                      decoration: BoxDecoration(color: ghostNeonBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                      child: const Center(child: Text("G", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20))),
                    ),
                  ),
                if (hasGhost && _targetPosition != null) 
                  Marker(
                    point: _targetPosition!, 
                    width: 55, height: 55,
                    child: Icon(Icons.flag_circle, color: _goalLocked ? Colors.white24 : Colors.redAccent, size: 55),
                  ),
              ]),
            ],
          ),

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

          if (_isRecording)
            Positioned(
              right: 20,
              top: MediaQuery.of(context).size.height * 0.4,
              child: FloatingActionButton.small(
                backgroundColor: _autoZoomActive ? ghostNeonBlue : Colors.grey[800],
                onPressed: () {
                  setState(() => _autoZoomActive = !_autoZoomActive);
                  if (_autoZoomActive) _fitAllPoints();
                },
                child: Icon(_autoZoomActive ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
              ),
            ),

          if (_isCountingDown)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(child: Text("$_countdownSeconds", style: TextStyle(color: ghostNeonBlue, fontSize: 180, fontWeight: FontWeight.bold))),
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
}