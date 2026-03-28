import 'package:flutter/material.dart';
import 'services/sensor_service.dart';
import 'screens/dashboard_screen.dart'; // WICHTIG: Den Import oben hinzufügen!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SensorService().checkSensors();
  runApp(const GhostRideApp());
}

class GhostRideApp extends StatelessWidget {
  const GhostRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghost Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainDashboard(), // Er nutzt jetzt die Klasse aus dashboard_screen.dart
    );
  }
}