import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _countdown = 5.0;
  double _interval = 1.0;
  double _radius = 25.0;
  final Color ghostBlue = const Color(0xFF00B4FF);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Lädt die gespeicherten Werte vom Handy-Speicher
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _countdown = prefs.getDouble('countdown') ?? 5.0;
      _interval = prefs.getDouble('interval') ?? 1.0;
    });
  }

  // Speichert die Werte sofort bei Änderung
  Future<void> _saveSetting(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("EINSTELLUNGEN", 
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("RENN-START"),
            _buildSettingCard(
              title: "Countdown: ${_countdown.toInt()} Sek.",
              subtitle: "Zeit um die Füße in die Pedale zu klicken",
              child: Slider(
                value: _countdown,
                min: 0,
                max: 30,
                divisions: 6,
                activeColor: ghostBlue,
                inactiveColor: Colors.white10,
                onChanged: (val) {
                  setState(() => _countdown = val);
                  _saveSetting('countdown', val);
                },
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle("PRÄZISION"),
            _buildSettingCard(
              title: "Intervall: ${_interval.toStringAsFixed(1)} Sek.",
              subtitle: "Häufigkeit der GPS-Abfrage (Empfehlung: 1.0)",
              child: Slider(
                value: _interval,
                min: 0.5,
                max: 5.0,
                divisions: 9,
                activeColor: ghostBlue,
                inactiveColor: Colors.white10,
                onChanged: (val) {
                  setState(() => _interval = val);
                  _saveSetting('interval', val);
                },
              ),
            ),
            // Unter dem Intervall-Slider im SettingsScreen:
_buildSectionTitle("ZIEL-BEREICH"),
_buildSettingCard(
  title: "Ziel-Radius: ${_radius.toInt()} Meter",
  subtitle: "Umkreis, in dem das Ziel als 'erreicht' gilt",
  child: Slider(
    value: _radius, // In initState laden (default 25.0)
    min: 15,
    max: 80,
    divisions: 18,
    activeColor: ghostBlue,
    onChanged: (val) {
      setState(() => _radius = val);
      _saveSetting('target_radius', val);
    },
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, 
        style: TextStyle(color: ghostBlue, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildSettingCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}