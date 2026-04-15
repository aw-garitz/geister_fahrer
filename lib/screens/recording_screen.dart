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
  Duration _ghostTotalDuration = Duration.zero;

  LatLng? _currentPosition;
  LatLng? _ghostPosition;
  LatLng? _targetPosition;
  double _currentHeading = 0.0;
  double _zoomFactor = 20.0;

  bool _isRecording = false;
  bool _isCountingDown = true;
  bool _autoZoomActive = true;
  bool _isLoadingGhostData = false; // Loading State für Geist-Daten

  int _countdownSeconds = 10;
  final double _targetRadius = 20.0; // Lastenheft Punkt 11a

  DateTime? _startTime;
  Timer? _countdownTimer;
  Timer? _uiTicker;
  Timer? _recenterTimer;
  StreamSubscription<Position>? _positionStream;

  // Farben laut Lastenheft
  final Color userNeonGreen = const Color(0xFF00FF00);
  final Color ghostLineYellow = const Color(0xFFFFEA00);
  final Color ghostMarkerColor = Colors.blueAccent;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _prepareRecording();
  }

  Future<void> _prepareRecording() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final prefs = await SharedPreferences.getInstance();
    int loadedCountdown = (prefs.getDouble('countdown') ?? 5.0).toInt();
    if (mounted) {
      setState(() {
        _countdownSeconds = loadedCountdown;
      });
    } else {
      _countdownSeconds = loadedCountdown;
    }

    if (widget.ghostTourId != null) {
      final points = await DatabaseHelper().getTourPoints(widget.ghostTourId!);
      if (points.isNotEmpty) {
        _ghostPoints = points;
        _ghostPolyline = points.map((p) => LatLng(p['lat'], p['lng'])).toList();
        _targetPosition = _ghostPolyline.last;
        _ghostPosition = _ghostPolyline.first;

        DateTime gStart = DateTime.parse(_ghostPoints.first['timestamp']);
        DateTime gEnd = DateTime.parse(_ghostPoints.last['timestamp']);
        _ghostTotalDuration = gEnd.difference(gStart);
      }
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_currentPosition!, _zoomFactor);
        _updateCamera();
      }
    } catch (_) {}

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

  void _startTracking() {
    if (mounted) {
      setState(() {
        _isRecording = true;
        _isCountingDown = false;
        _autoZoomActive = true;
        _startTime = DateTime.now();
        _recordedPoints.clear();
        _polylinePoints.clear();
      });
    }
    _updateCamera();

    _uiTicker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording) {
        _updateGhostLogic();
      }
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: Duration(milliseconds: 500),
      ),
    ).listen((Position position) => _addPoint(position));
  }

  void _addPoint(Position pos) {
    if (!mounted) return;
    LatLng newLatLng = LatLng(pos.latitude, pos.longitude);

    setState(() {
      if (_polylinePoints.isNotEmpty) {
        _totalDistance += Geolocator.distanceBetween(
          _polylinePoints.last.latitude,
          _polylinePoints.last.longitude,
          newLatLng.latitude,
          newLatLng.longitude,
        );
      }
      _currentPosition = newLatLng;
      _currentHeading = pos.heading;
      _polylinePoints.add(newLatLng);
      _recordedPoints.add({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'alt': pos.altitude,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (widget.ghostTourId != null && _targetPosition != null) {
        double distToTarget = Geolocator.distanceBetween(
          newLatLng.latitude,
          newLatLng.longitude,
          _targetPosition!.latitude,
          _targetPosition!.longitude,
        );
        if (_polylinePoints.length > 5 && distToTarget < 20.0) {
          _finishSession(true);
        }
      }
    });
    _updateCamera();
  }

  void _updateGhostLogic() {
    if (widget.ghostTourId == null ||
        _startTime == null ||
        _ghostPoints.isEmpty) {
      // Wenn keine Geist-Daten da, nicht versuchen Logik auszuführen
      return;
    }

    final elapsed = DateTime.now().difference(_startTime!);
    DateTime ghostStart = DateTime.parse(_ghostPoints.first['timestamp']);

    for (int i = 0; i < _ghostPoints.length - 1; i++) {
      DateTime t1 = DateTime.parse(_ghostPoints[i]['timestamp']);
      DateTime t2 = DateTime.parse(_ghostPoints[i + 1]['timestamp']);

      if (t2.difference(ghostStart) >= elapsed) {
        double segmentTotal = t2.difference(t1).inMilliseconds.toDouble();
        double segmentElapsed =
            (elapsed.inMilliseconds - t1.difference(ghostStart).inMilliseconds)
                .toDouble();
        double fraction = (segmentElapsed / segmentTotal).clamp(0.0, 1.0);

        setState(() {
          _ghostPosition = LatLng(
            _ghostPoints[i]['lat'] +
                (_ghostPoints[i + 1]['lat'] - _ghostPoints[i]['lat']) *
                    fraction,
            _ghostPoints[i]['lng'] +
                (_ghostPoints[i + 1]['lng'] - _ghostPoints[i]['lng']) *
                    fraction,
          );
        });
        _updateCamera();
        return;
      }
    }
    setState(() => _ghostPosition = _targetPosition);
    _updateCamera();
  }

  void _updateCamera() {
    if (!_autoZoomActive || _currentPosition == null) return;
    if (widget.ghostTourId != null &&
        _ghostPosition != null &&
        _currentPosition != null) {
      final bounds = LatLngBounds(_currentPosition!, _ghostPosition!);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
          minZoom: 5.0,
          maxZoom: _zoomFactor,
        ),
      );
    } else if (_currentPosition != null) {
      _mapController.move(_currentPosition!, _zoomFactor);
    }
  }

  void _handleMapInteraction(MapEvent event) {
    if (event.source != MapEventSource.mapController) {
      if (mounted) setState(() => _autoZoomActive = false);
      _recenterTimer?.cancel();
      _recenterTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isRecording) setState(() => _autoZoomActive = true);
      });
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              "Fahrt abbrechen?",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "Soll die aktuelle Aufzeichnung wirklich verworfen werden?",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("NEIN"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "JA, BEENDEN",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _finishSession(bool reachedGoal) {
    WakelockPlus.disable();
    _uiTicker?.cancel();
    _positionStream?.cancel();
    _recenterTimer?.cancel();
    _showSaveDialog(reachedGoal);
  }

  double _calculateGhostDistance() {
    double distance = 0.0;
    for (int i = 1; i < _ghostPoints.length; i++) {
      distance += Geolocator.distanceBetween(
        _ghostPoints[i - 1]['lat'],
        _ghostPoints[i - 1]['lng'],
        _ghostPoints[i]['lat'],
        _ghostPoints[i]['lng'],
      );
    }
    return distance;
  }

  void _showSaveDialog(bool reachedGoal) {
    TextEditingController nameController = TextEditingController(
      text: "Tour ${DateTime.now().day}.${DateTime.now().month}.",
    );

    // Berechne Vergleiche, falls Geist-Daten vorhanden
    String timeComparison = "";
    String distanceComparison = "";
    if (widget.ghostTourId != null && _startTime != null) {
      final userElapsed = DateTime.now().difference(_startTime!);
      final timeDiff = userElapsed - _ghostTotalDuration;
      final timeDiffStr = timeDiff.isNegative
          ? "${timeDiff.inSeconds} sek"
          : "+${timeDiff.inSeconds} sek";
      timeComparison = "Zeit: $timeDiffStr";

      final ghostDistance = _calculateGhostDistance();
      final distanceDiff = _totalDistance - ghostDistance;
      final distanceDiffStr = distanceDiff < 0
          ? "${distanceDiff.toStringAsFixed(2)} m"
          : "+${distanceDiff.toStringAsFixed(2)} m";
      distanceComparison = "Distanz: $distanceDiffStr";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          reachedGoal ? "🏆 ZIEL ERREICHT" : "BEENDET",
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (timeComparison.isNotEmpty)
              Text(
                timeComparison,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            if (distanceComparison.isNotEmpty)
              Text(
                distanceComparison,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Name der Tour",
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("VERWERFEN"),
          ),
          TextButton(
            onPressed: () async {
              if (_recordedPoints.isNotEmpty)
                await DatabaseHelper().saveTour(
                  nameController.text,
                  _recordedPoints,
                );
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text("SPEICHERN"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _countdownTimer?.cancel();
    _uiTicker?.cancel();
    _recenterTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;
    String timeDisplay = widget.ghostTourId != null
        ? (_ghostTotalDuration - elapsed).isNegative
              ? "00:00"
              : _formatDuration(_ghostTotalDuration - elapsed)
        : _formatDuration(elapsed);

    return PopScope(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition ?? const LatLng(50.11, 8.68),
                initialZoom: 22.0,
                onMapEvent: _handleMapInteraction,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                ),
                if (_ghostPolyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _ghostPolyline,
                        strokeWidth: 6,
                        color: ghostLineYellow,
                      ),
                    ],
                  ),
                if (_polylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _polylinePoints,
                        strokeWidth: 7,
                        color: userNeonGreen,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_ghostPosition != null)
                      Marker(
                        point: _ghostPosition!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.psychology,
                          color: Colors.blueAccent,
                          size: 45,
                        ),
                      ),
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 45,
                        height: 45,
                        child: Transform.rotate(
                          angle: _currentHeading * (3.14159 / 180),
                          child: Icon(
                            Icons.navigation,
                            color: userNeonGreen,
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    "⏳ $timeDisplay  |  🏁 ${(_totalDistance / 1000).toStringAsFixed(2)} km",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            if (_isCountingDown)
              Container(
                color: Colors.black.withOpacity(0.9),
                child: Center(
                  child: Text(
                    "$_countdownSeconds",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 160,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (_isRecording)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.large(
                    backgroundColor: Colors.redAccent,
                    onPressed: () => _finishSession(false),
                    child: const Icon(Icons.stop, size: 40),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
