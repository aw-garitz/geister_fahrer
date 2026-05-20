import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/sensor_service.dart';
import 'screens/dashboard_screen.dart'; // WICHTIG: Den Import oben hinzufügen!
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/privacy_acceptance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SensorService().checkSensors();
  runApp(const GhostRideApp());
}

class GhostRideApp extends StatefulWidget {
  const GhostRideApp({super.key});

  @override
  State<GhostRideApp> createState() => _GhostRideAppState();
}

class _GhostRideAppState extends State<GhostRideApp> {
  bool? _isPrivacyAccepted;

  @override
  void initState() {
    super.initState();
    _checkPrivacyStatus();
  }

  Future<void> _checkPrivacyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('privacy_accepted') ?? false;
    if (accepted) {
      // Wenn bereits akzeptiert, AdMob sofort initialisieren
      await MobileAds.instance.initialize();
    }
    setState(() {
      _isPrivacyAccepted = accepted;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPrivacyAccepted == null) {
      return const Center(child: CircularProgressIndicator()); // Ladezustand
    }
    return MaterialApp(
      title: 'Ghost Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: _isPrivacyAccepted! ? const MainDashboard() : const PrivacyAcceptanceScreen(),
    );
  }
}