import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart'; // Importiere das Dashboard

class PrivacyAcceptanceScreen extends StatelessWidget {
  const PrivacyAcceptanceScreen({super.key});

  Future<void> _acceptPrivacy(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);

    // AdMob SDK initialisieren, nachdem der Nutzer zugestimmt hat
    await MobileAds.instance.initialize();

    // Zum Dashboard navigieren und den aktuellen Screen entfernen
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color ghostBlue = Color(0xFF00B4FF);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("DATENSCHUTZ & NUTZUNGSBEDINGUNGEN", style: TextStyle(letterSpacing: 1, fontWeight: FontWeight.bold, fontSize: 16)),
        automaticallyImplyLeading: false, // Kein Zurück-Button
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection("Willkommen bei Geisterfahrer!",
                      "Um die App nutzen zu können, bitten wir dich, unsere Datenschutzerklärung und Nutzungsbedingungen zu akzeptieren."),
                  _buildSection("1. Datenerfassung",
                      "Geisterfahrer erfasst GPS-Standortdaten, um deine Touren aufzuzeichnen und den Vergleich mit 'Geistern' zu ermöglichen. Diese Daten werden lokal auf deinem Gerät in einer Datenbank gespeichert."),
                  _buildSection("2. Hintergrund-Standort",
                      "Um Touren auch bei ausgeschaltetem Bildschirm lückenlos aufzuzeichnen, fordert die App Zugriff auf den Standort im Hintergrund an."),
                  _buildSection("3. Google AdMob",
                      "Diese App nutzt Google AdMob zur Anzeige von Werbung. Google verwendet IDs für Werbezwecke (z. B. die Werbe-ID), um Anzeigen zu personalisieren und Statistiken zu erstellen."),
                  _buildSection("4. Speicherort",
                      "Alle aufgezeichneten Fahrten verbleiben auf deinem Gerät, sofern du keine externe Backup-Funktion deines Betriebssystems nutzt."),
                  const SizedBox(height: 30),
                  const Text("Stand: Oktober 2023", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.black,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ghostBlue,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _acceptPrivacy(context),
              child: const Text("ZUSTIMMEN & STARTEN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF00B4FF), fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}