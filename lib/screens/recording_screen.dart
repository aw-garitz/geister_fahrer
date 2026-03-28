import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ghost_ride/database_helper.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/ui_helper.dart';
import '../services/sensor_service.dart';

class RecordingScreen extends StatefulWidget {
  // Neu: Die ID der Tour, gegen die man fährt (null = normales Training)
  final int? ghostTourId;

  const RecordingScreen({super.key, this.ghostTourId});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  int _counter = 5;
  Timer? _timer;
  bool _isRecording = false;
  bool _isSaving = false;
  bool _hasInitialPosition = false;

  StreamSubscription<Position>? _positionStream;
  final List<Map<String, dynamic>> _trackPoints = [];
  final List<LatLng> _polylinePoints = [];
  DateTime? _lastSavedTime;

  // Geist-Logik Variablen
  List<Map<String, dynamic>> _ghostPoints = [];
  LatLng? _currentGhostPosition;
  int _ghostIndex = 0;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.ghostTourId != null) {
      _loadGhostData();
    }
    _startCountdown();
  }

  // Geist-Daten aus der DB laden
  Future<void> _loadGhostData() async {
    final points = await DatabaseHelper().getTourPoints(widget.ghostTourId!);
    setState(() {
      _ghostPoints = points;
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_counter > 1) {
            _counter--;
          } else {
            _timer?.cancel();
            _isRecording = true;
            _initGPS();
          }
        });
      }
    });
  }

  Future<void> _initGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(_processPosition);
  }

  void _processPosition(Position pos) {
    final now = DateTime.now();
    LatLng currentLatLng = LatLng(pos.latitude, pos.longitude);

    if (!_hasInitialPosition) {
      setState(() {
        _hasInitialPosition = true;
      });
    }

    _mapController.move(currentLatLng, 17.0);

    // Eigene Position speichern (alle 2s)
    if (_lastSavedTime == null || now.difference(_lastSavedTime!).inSeconds >= 2) {
      _lastSavedTime = now;
      setState(() {
        _polylinePoints.add(currentLatLng);
        _trackPoints.add({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'alt': SensorService().isBarometerAvailable ? pos.altitude : null,
          'timestamp': now.toIso8601String(),
        });

        // Geist bewegen: Wir rücken den Geist einfach Punkt für Punkt vor
        if (_ghostPoints.isNotEmpty && _ghostIndex < _ghostPoints.length) {
          _currentGhostPosition = LatLng(
            _ghostPoints[_ghostIndex]['lat'],
            _ghostPoints[_ghostIndex]['lng'],
          );
          _ghostIndex++;
        }
      });
    }
  }

  Future<void> _stopAndSave() async {
    _positionStream?.cancel();
    if (_trackPoints.isEmpty) {
      Navigator.pop(context);
      return;
    }

    String tourName = "Tour ${DateTime.now().day}.${DateTime.now().month}. ${DateTime.now().hour}:${DateTime.now().minute}";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Fahrt speichern"),
        content: TextField(
          decoration: const InputDecoration(hintText: "Name der Strecke"),
          onChanged: (value) => tourName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Verwerfen", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isSaving = true);
              await DatabaseHelper().saveTour(tourName, _trackPoints);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    if (!_isRecording) return _buildCountdownUI();
    if (!_hasInitialPosition) return _buildWaitingForGPSUI();
    return _buildMapUI();
  }

  Widget _buildWaitingForGPSUI() {
    return Container(
      color: Colors.green.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            SizedBox(height: UIHelper.verticalSpace(context, 0.05)),
            const Text(
              "SUCHE SATELLITEN...",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownUI() {
    return Container(
      color: Colors.green.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "BEREIT MACHEN...",
              style: TextStyle(
                color: Colors.white,
                fontSize: UIHelper.dynamicFontSize(context, 0.07),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: UIHelper.verticalSpace(context, 0.05)),
            Text(
              "$_counter",
              style: TextStyle(
                color: Colors.white,
                fontSize: UIHelper.dynamicFontSize(context, 0.4),
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: UIHelper.verticalSpace(context, 0.08)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ABBRECHEN"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapUI() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(50.11, 8.68),
            initialZoom: 17.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.alexwerner.ghost_ride',
            ),
            if (_polylinePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _polylinePoints,
                    color: Colors.greenAccent,
                    strokeWidth: 6.0,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Eigener Marker (Blau)
                if (_polylinePoints.isNotEmpty)
                  Marker(
                    point: _polylinePoints.last,
                    width: 25,
                    height: 25,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                // GHOST Marker (Grau/Weiß)
                if (_currentGhostPosition != null)
                  Marker(
                    point: _currentGhostPosition!,
                    width: 25,
                    height: 25,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.directions_bike, size: 15, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 50,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
            child: Text("Punkte: ${_trackPoints.length}", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        Positioned(
          bottom: UIHelper.verticalSpace(context, 0.05),
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: UIHelper.deviceWidth(context) * 0.7,
              height: UIHelper.deviceHeight(context) * 0.08,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _stopAndSave,
                child: const Text("STOPP", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}