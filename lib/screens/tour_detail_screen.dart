import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../database_helper.dart';

class TourDetailScreen extends StatelessWidget {
  final int tourId;
  const TourDetailScreen({super.key, required this.tourId});

  Future<Map<String, dynamic>> _getTourData() async {
    final points = await DatabaseHelper().getTourPoints(tourId);
    final tours = await DatabaseHelper().getAllTours();
    final tourInfo = tours.firstWhere((t) => t['id'] == tourId);
    
    List<LatLng> polyline = points.map((p) => LatLng(p['lat'], p['lng'])).toList();
    return {'info': tourInfo, 'polyline': polyline};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("TOUR DETAILS"), backgroundColor: Colors.black),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getTourData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final info = snapshot.data!['info'];
          final List<LatLng> polyline = snapshot.data!['polyline'];

          return Column(
            children: [
              // Info-Panel oben
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey[900],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat(info['distance'] ?? "--", "DISTANZ"),
                    _buildStat(info['duration'] ?? "--", "ZEIT"),
                    _buildStat(info['date']?.toString().substring(0,10) ?? "--", "DATUM"),
                  ],
                ),
              ),
              // Karte
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: polyline.isNotEmpty ? polyline.first : const LatLng(50, 8),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
                    if (polyline.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(points: polyline, strokeWidth: 5, color: const Color(0xFF00FF00)),
                      ]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}