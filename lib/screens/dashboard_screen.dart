import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ghost_ride/screens/settings_screen.dart';
import '../services/sensor_service.dart';
import 'recording_screen.dart';
import 'ghost_selection_screen.dart';
 // Den müssen wir noch erstellen

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-5541011909698877/8135661416'
          : 'ca-app-pub-5541011909698877/5126354695',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Dashboard Banner konnte nicht geladen werden: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    const Color ghostBlue = Color(0xFF00B4FF);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              // Header Bereich
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("GEISTER", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      Text("FAHRER", style: TextStyle(color: ghostBlue, fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 8)),
                    ],
                  ),
                  _buildStatusIcon(),
                ],
              ),
              const Spacer(flex: 2),

              // 1. DIE MASSIVEN ACTION-BUTTONS (Höhe 120 für leichte Bedienung)
              _buildBigActionButton(
                context,
                title: "NEUE FAHRT",
                icon: Icons.play_arrow_rounded,
                color: Colors.white,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordingScreen())),
              ),
              
              const SizedBox(height: 25),

              _buildBigActionButton(
                context,
                title: "GEGEN GEIST",
                icon: Icons.bolt_rounded,
                color: ghostBlue,
                isGhost: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GhostSelectionScreen(startInEditMode: false))),
              ),

              const Spacer(flex: 2),

              // 2. & 3. DIE VERWALTUNGS-BUTTONS (Kompakter am unteren Rand)
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      context,
                      title: "MEINE TOUREN",
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GhostSelectionScreen(startInEditMode: true))),
                    ),
                  ),
                  const SizedBox(width: 15),
                  _buildIconButton(
                    context,
                    icon: Icons.settings_outlined,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: AdSize.banner.height.toDouble(),
          child: _isAdLoaded && _bannerAd != null
              ? AdWidget(ad: _bannerAd!)
              : Container(color: Colors.black),
        ),
      ),
    );
  }

  // Massive Buttons für die Fahrt
  Widget _buildBigActionButton(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap, bool isGhost = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120, // Extra hoch für "Fat-Finger"-Bedienung
        decoration: BoxDecoration(
          color: isGhost ? color.withOpacity(0.15) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(width: 20),
            Text(title, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  // Button für die Touren-Liste
  Widget _buildSecondaryButton(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // Kleiner quadratischer Einstellungs-Button
  Widget _buildIconButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, color: Colors.white70),
      ),
    );
  }

  Widget _buildStatusIcon() {
    final bool isBaroAvailable = SensorService().isBarometerAvailable;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
      child: Tooltip(
        message: isBaroAvailable ? "Präzise Höhenmessung (Barometer)" : "Standard Höhenmessung (GPS)",
        child: Icon(
          Icons.terrain_rounded, // Symbolisiert Gelände/Höhenprofil
          color: isBaroAvailable ? Colors.cyanAccent : Colors.white24,
        ),
      ),
    );
  }
}